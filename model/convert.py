from __future__ import annotations

import json
import shutil
from pathlib import Path
from typing import Any

import numpy as np


def _to_int(value: Any) -> int:
    if isinstance(value, np.ndarray):
        if value.shape != ():
            raise TypeError("Expected scalar ndarray")
        return int(value.item())
    if isinstance(value, np.generic):
        return int(value.item())
    return int(value)


def toBin(num: Any, prec: int) -> str:
    num = _to_int(num)
    binary = list(bin(num & (2**prec - 1))[2:])
    if len(binary) > prec:
        raise ValueError(f"Value {num} does not fit in {prec} bits")
    return "".join((["0" for _ in range(prec)] + binary)[-prec:])


def toHex(num: Any, prec: int) -> str:
    num = _to_int(num)
    width = prec // 4 if prec % 4 == 0 else prec // 4 + 1
    hex_digits = list(hex(num & (2**prec - 1))[2:])
    if len(hex_digits) > width:
        raise ValueError(f"Value {num} does not fit in {prec} bits")
    return "".join((["0" for _ in range(width)] + hex_digits)[-width:])


def _json_default(value: Any) -> Any:
    if isinstance(value, np.ndarray):
        return value.tolist()
    if isinstance(value, np.generic):
        return value.item()
    return value


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, indent=2, default=_json_default), encoding="utf-8")


def _write_text_array(path: Path, array: np.ndarray) -> None:
    arr = np.asarray(array)
    if arr.ndim == 1:
        path.write_text("\n".join(str(int(v)) for v in arr) + "\n", encoding="utf-8")
        return

    lines = []
    for row in arr:
        lines.append(" ".join(str(int(v)) for v in row))
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _write_mem_rows(path: Path, rows: list[str]) -> None:
    path.write_text("".join(f"{row}\n" for row in rows), encoding="utf-8")


def _signed_limits(bits: int) -> tuple[int, int]:
    return -(2 ** (bits - 1)), 2 ** (bits - 1) - 1


def _unsigned_limits(bits: int) -> tuple[int, int]:
    return 0, 2**bits - 1


def _require_values_fit(array: np.ndarray, bits: int, signed: bool, label: str) -> None:
    arr = np.asarray(array, dtype=np.int64)
    lo, hi = _signed_limits(bits) if signed else _unsigned_limits(bits)
    if arr.size == 0:
        return
    if int(arr.min()) < lo or int(arr.max()) > hi:
        raise OverflowError(
            f"{label} contains values outside the {'signed' if signed else 'unsigned'} {bits}-bit range: "
            f"min={int(arr.min())}, max={int(arr.max())}, allowed=[{lo}, {hi}]"
        )


def _decode_hex_twos(value: str, bits: int) -> int:
    raw = int(value, 16)
    sign_bit = 1 << (bits - 1)
    full_scale = 1 << bits
    if raw & sign_bit:
        return raw - full_scale
    return raw


def _decode_hex_unsigned(value: str) -> int:
    return int(value, 16)


def _validate_weight_mem_rows(
    rows: list[str],
    weights: np.ndarray,
    bias: np.ndarray,
    weight_bits: int,
    bias_bits: int,
    split: int,
    label: str,
    weight_signed: bool,
) -> None:
    weights_arr = np.asarray(weights, dtype=np.int32)
    bias_arr = np.asarray(bias, dtype=np.int32)
    expected_rows = int(weights_arr.shape[0]) * int(split)
    if len(rows) != expected_rows:
        raise ValueError(f"{label}: expected {expected_rows} mem rows, got {len(rows)}")

    feature_width = (weight_bits + 3) // 4
    bias_width = (bias_bits + 3) // 4
    row_idx = 0
    chunked_rows = [np.array_split(weight_row, split) for weight_row in weights_arr]
    rebuilt_rows: list[list[np.ndarray]] = [[] for _ in range(len(weights_arr))]

    for chunk_idx in range(split):
        for neuron_idx, bias_value in enumerate(bias_arr):
            chunk = chunked_rows[neuron_idx][chunk_idx]
            row = rows[row_idx]
            row_idx += 1

            expected_width = bias_width + len(chunk) * feature_width
            if len(row) != expected_width:
                raise ValueError(
                    f"{label}: row {row_idx - 1} has width {len(row)}, expected {expected_width}"
                )

            decoded_bias = _decode_hex_twos(row[:bias_width], bias_bits)
            expected_bias = int(bias_value) if chunk_idx == 0 else 0
            if decoded_bias != expected_bias:
                raise ValueError(
                    f"{label}: row {row_idx - 1} bias mismatch, decoded {decoded_bias}, expected {expected_bias}"
                )

            decoded_chunk = []
            for value_idx in range(len(chunk)):
                start = bias_width + value_idx * feature_width
                end = start + feature_width
                if weight_signed:
                    decoded_value = _decode_hex_twos(row[start:end], weight_bits)
                else:
                    decoded_value = _decode_hex_unsigned(row[start:end])
                decoded_chunk.append(decoded_value)

            decoded_chunk_arr = np.asarray(decoded_chunk, dtype=np.int32)
            if not np.array_equal(decoded_chunk_arr, chunk.astype(np.int32)):
                mismatch = int(np.flatnonzero(decoded_chunk_arr != chunk.astype(np.int32))[0])
                raise ValueError(
                    f"{label}: row {row_idx - 1} weight mismatch at local index {mismatch}, "
                    f"decoded {int(decoded_chunk_arr[mismatch])}, expected {int(chunk[mismatch])}"
                )
            rebuilt_rows[neuron_idx].append(decoded_chunk_arr)

    for neuron_idx, weight_row in enumerate(weights_arr):
        rebuilt_chunks = rebuilt_rows[neuron_idx]
        rebuilt_row = np.concatenate(rebuilt_chunks) if rebuilt_chunks else np.empty((0,), dtype=np.int32)
        if not np.array_equal(rebuilt_row, weight_row.astype(np.int32)):
            raise ValueError(f"{label}: reconstructed row {neuron_idx} does not match original weights")


class ToMem:
    def __init__(self, feature_prec: int, bias_prec: int, name: str, output_dir: str | Path):
        self.features: list[np.ndarray] = []
        self.out: list[np.ndarray] = []
        self.feature_prec = feature_prec
        self.bias_prec = bias_prec
        self.name = name
        self.output_dir = Path(output_dir)

    def addFeature(self, feature: np.ndarray) -> None:
        self.features.append(np.asarray(feature))

    def addOut(self, out: np.ndarray) -> None:
        self.out.append(np.asarray(out))

    def setWeights(self, weights: np.ndarray) -> None:
        self.weights = np.asarray(weights)

    def setSuperbias(self, superbias: np.ndarray) -> None:
        self.superbias = np.asarray(superbias)

    def saveFeatures(self) -> None:
        rows = []
        for feature in self.features:
            feature_2d = np.atleast_2d(feature)
            for row in feature_2d:
                rows.append(" ".join(toHex(v, self.feature_prec) for v in row))
        _write_mem_rows(self.output_dir / f"{self.name}_features.mem", rows)

    def saveOut(self) -> None:
        for idx, out in enumerate(self.out, start=1):
            _write_text_array(self.output_dir / f"{self.name}_out_truth_{idx}.mem", np.ravel(out))

    def saveWeights(self, split: int = 1) -> None:
        if len(self.weights) != len(self.superbias):
            raise ValueError("weights rows and bias rows must match")

        rows = []
        chunked_rows = [np.array_split(weight_row, split) for weight_row in self.weights]
        for chunk_idx in range(split):
            for row_idx, bias in enumerate(self.superbias):
                chunk = chunked_rows[row_idx][chunk_idx]
                bias_value = bias if chunk_idx == 0 else np.int32(0)
                row = toHex(bias_value, self.bias_prec) + "".join(
                    toHex(value, self.feature_prec) for value in chunk
                )
                rows.append(row)

        _write_mem_rows(self.output_dir / f"{self.name}_weights.mem", rows)

    def saveHyper(self, mul_per_feature: int, multiplier: int) -> None:
        params_path = self.output_dir / f"{self.name}_params.txt"
        params_path.write_text(
            f"localparam int MUL_PER_FEATURE = {mul_per_feature};\n"
            f"localparam int M = {multiplier};\n",
            encoding="utf-8",
        )

    def saveAll(self, split: int = 1) -> None:
        self.saveFeatures()
        self.saveWeights(split)
        self.saveOut()


def save_layer(layer_data: dict[str, Any], name: str, output_dir: str | Path, split: int = 1) -> None:
    out_dir = Path(output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    if split < 1:
        raise ValueError(f"split must be >= 1, got {split}")

    centered_weights_arr = np.asarray(layer_data["w_q"], dtype=np.int32)
    raw_weights_arr = np.asarray(layer_data.get("w_q_raw", layer_data["w_q"]), dtype=np.int32)
    bias_arr = np.asarray(layer_data["bias"], dtype=np.int32)
    weight_bits = _to_int(layer_data["precision"])
    bias_bits = _to_int(layer_data["bias_precision"])

    _require_values_fit(raw_weights_arr, weight_bits, signed=False, label=f"{name} raw weights")
    _require_values_fit(bias_arr, bias_bits, signed=True, label=f"{name} bias")

    saver = ToMem(layer_data["precision"], layer_data["bias_precision"], name, out_dir)
    saver.setSuperbias(bias_arr)
    saver.setWeights(raw_weights_arr)
    saver.saveWeights(split)

    mem_rows = (out_dir / f"{name}_weights.mem").read_text(encoding="utf-8").splitlines()
    _validate_weight_mem_rows(
        mem_rows,
        raw_weights_arr,
        bias_arr,
        weight_bits=weight_bits,
        bias_bits=bias_bits,
        split=split,
        label=f"{name}_weights.mem",
        weight_signed=False,
    )

    np.save(out_dir / f"{name}_weights_centered.npy", centered_weights_arr)
    if "w_q_raw" in layer_data:
        np.save(out_dir / f"{name}_weights_raw.npy", raw_weights_arr)
    np.save(out_dir / f"{name}_bias.npy", bias_arr)

    _write_text_array(out_dir / f"{name}_weights_centered.txt", centered_weights_arr)
    _write_text_array(out_dir / f"{name}_weights_raw.txt", raw_weights_arr)
    _write_text_array(out_dir / f"{name}_bias.txt", bias_arr)

    svh_lines = [
        f"localparam int MUL_PER_FEATURE = {_to_int(layer_data['mul_per_feature'])};",
        f"localparam int M = {_to_int(layer_data['M'])};",
        f"localparam int N = {_to_int(layer_data['N'])};",
        f"localparam int INPUT_PRECISION = {_to_int(layer_data['input_precision'])};",
        f"localparam int WEIGHT_PRECISION = {_to_int(layer_data['precision'])};",
        f"localparam int OUTPUT_PRECISION = {_to_int(layer_data['output_precision'])};",
        f"localparam int BIAS_PRECISION = {_to_int(layer_data['bias_precision'])};",
        f"localparam int IN_ZP = {_to_int(layer_data['in_zp'])};",
        f"localparam int W_ZP = {_to_int(layer_data['w_zp'])};",
        f"localparam int OUT_ZP = {_to_int(layer_data['out_zp'])};",
        f"localparam int M_MUL = {_to_int(layer_data['M_int'])};",
        f"localparam int M_SHIFT = {_to_int(layer_data['shift'])};",
    ]
    (out_dir / f"{name}_params.svh").write_text("\n".join(svh_lines) + "\n", encoding="utf-8")

    layer_json = {
        "name": name,
        "input_size": _to_int(layer_data["N"]),
        "output_size": _to_int(layer_data["M"]),
        "input_zero_point": _to_int(layer_data["in_zp"]),
        "weight_zero_point": _to_int(layer_data["w_zp"]),
        "output_zero_point": _to_int(layer_data["out_zp"]),
        "weight_bits": _to_int(layer_data["precision"]),
        "input_bits": _to_int(layer_data["input_precision"]),
        "output_bits": _to_int(layer_data["output_precision"]),
        "bias_bits": _to_int(layer_data["bias_precision"]),
        "multiplier_float": float(layer_data["M_float"]),
        "multiplier_int": _to_int(layer_data["M_int"]),
        "shift": _to_int(layer_data["shift"]),
        "split": int(split),
        "weights_mem_format": "raw_unsigned_with_bias_prefix",
        "weights_mem": f"{name}_weights.mem",
    }
    _write_json(out_dir / f"{name}_params.json", layer_json)


def save_input_quant(input_quant: dict[str, Any], output_dir: str | Path) -> None:
    out_dir = Path(output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    _write_json(out_dir / "input_quant.json", input_quant)

    svh_lines = [
        f"localparam int INPUT_BITS = {_to_int(input_quant['bits'])};",
        f"localparam int INPUT_ZP = {_to_int(input_quant['zero_point'])};",
        f"localparam int INPUT_M_INT = {_to_int(input_quant['M_int'])};",
        f"localparam int INPUT_SHIFT = {_to_int(input_quant['shift'])};",
        f"localparam int INPUT_C_INT = {_to_int(input_quant['C_int'])};",
    ]
    (out_dir / "input_quant.svh").write_text("\n".join(svh_lines) + "\n", encoding="utf-8")


def save_mlp_params(model: Any, output_dir: str | Path) -> None:
    out_dir = Path(output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    l1 = model.layers[0]
    l2 = model.layers[1]
    l3 = model.layers[2]
    input_quant = model.input_quant

    svh_lines = [
        f"localparam int INPUT_BITS = {_to_int(input_quant['bits'])};",
        f"localparam int INPUT_ZP = {_to_int(input_quant['zero_point'])};",
        f"localparam int INPUT_M_INT = {_to_int(input_quant['M_int'])};",
        f"localparam int INPUT_SHIFT = {_to_int(input_quant['shift'])};",
        f"localparam int INPUT_C_INT = {_to_int(input_quant['C_int'])};",
        "",
        f"localparam int FC1_M = {_to_int(l1.output_size)};",
        f"localparam int FC1_N = {_to_int(l1.input_size)};",
        f"localparam int FC1_INPUT_PRECISION = {_to_int(l1.input_bits)};",
        f"localparam int FC1_WEIGHT_PRECISION = {_to_int(l1.weight_bits)};",
        f"localparam int FC1_OUTPUT_PRECISION = {_to_int(l1.output_bits)};",
        f"localparam int FC1_BIAS_PRECISION = {_to_int(l1.bias_bits)};",
        f"localparam int FC1_MUL_PER_FEATURE = {_to_int(l1.mul_per_feature)};",
        f"localparam int FC1_IN_ZP = {_to_int(l1.input_zero_point)};",
        f"localparam int FC1_W_ZP = {_to_int(l1.weight_zero_point)};",
        f"localparam int FC1_OUT_ZP = {_to_int(l1.output_zero_point)};",
        f"localparam int FC1_M_MUL = {_to_int(l1.multiplier_int)};",
        f"localparam int FC1_M_SHIFT = {_to_int(l1.shift)};",
        "",
        f"localparam int FC2_M = {_to_int(l2.output_size)};",
        f"localparam int FC2_N = {_to_int(l2.input_size)};",
        f"localparam int FC2_INPUT_PRECISION = {_to_int(l2.input_bits)};",
        f"localparam int FC2_WEIGHT_PRECISION = {_to_int(l2.weight_bits)};",
        f"localparam int FC2_OUTPUT_PRECISION = {_to_int(l2.output_bits)};",
        f"localparam int FC2_BIAS_PRECISION = {_to_int(l2.bias_bits)};",
        f"localparam int FC2_MUL_PER_FEATURE = {_to_int(l2.mul_per_feature)};",
        f"localparam int FC2_IN_ZP = {_to_int(l2.input_zero_point)};",
        f"localparam int FC2_W_ZP = {_to_int(l2.weight_zero_point)};",
        f"localparam int FC2_OUT_ZP = {_to_int(l2.output_zero_point)};",
        f"localparam int FC2_M_MUL = {_to_int(l2.multiplier_int)};",
        f"localparam int FC2_M_SHIFT = {_to_int(l2.shift)};",
        "",
        f"localparam int FC3_M = {_to_int(l3.output_size)};",
        f"localparam int FC3_N = {_to_int(l3.input_size)};",
        f"localparam int FC3_INPUT_PRECISION = {_to_int(l3.input_bits)};",
        f"localparam int FC3_WEIGHT_PRECISION = {_to_int(l3.weight_bits)};",
        f"localparam int FC3_OUTPUT_PRECISION = {_to_int(l3.output_bits)};",
        f"localparam int FC3_BIAS_PRECISION = {_to_int(l3.bias_bits)};",
        f"localparam int FC3_MUL_PER_FEATURE = {_to_int(l3.mul_per_feature)};",
        f"localparam int FC3_IN_ZP = {_to_int(l3.input_zero_point)};",
        f"localparam int FC3_W_ZP = {_to_int(l3.weight_zero_point)};",
        f"localparam int FC3_OUT_ZP = {_to_int(l3.output_zero_point)};",
        f"localparam int FC3_M_MUL = {_to_int(l3.multiplier_int)};",
        f"localparam int FC3_M_SHIFT = {_to_int(l3.shift)};",
    ]
    (out_dir / "mlp_params.svh").write_text("\n".join(svh_lines) + "\n", encoding="utf-8")


def save_trace(trace: dict[str, Any], output_dir: str | Path, stem: str = "sample") -> None:
    out_dir = Path(output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    for key, value in trace.items():
        if isinstance(value, np.ndarray):
            np.save(out_dir / f"{stem}_{key}.npy", value)
            _write_text_array(out_dir / f"{stem}_{key}.txt", value)

    trace_summary = {
        key: (int(value) if not isinstance(value, np.ndarray) else f"{stem}_{key}.npy")
        for key, value in trace.items()
    }
    _write_json(out_dir / f"{stem}_trace.json", trace_summary)


def export_model(model: Any, output_dir: str | Path, split: int = 1, copy_params: bool = True) -> Path:
    out_dir = Path(output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    if copy_params and getattr(model, "params_path", None):
        shutil.copy2(model.params_path, out_dir / Path(model.params_path).name)

    save_input_quant(model.input_quant, out_dir)
    save_mlp_params(model, out_dir)

    save_layer(model.l1, "fc1", out_dir, split=split)
    save_layer(model.l2, "fc2", out_dir, split=split)
    save_layer(model.l3, "fc3", out_dir, split=split)

    manifest = model.describe()
    manifest["files"] = {
        "input_quant": "input_quant.json",
        "mlp_params_svh": "mlp_params.svh",
        "layers": {
            "fc1": {
                "params": "fc1_params.json",
                "params_svh": "fc1_params.svh",
                "weights_mem": "fc1_weights.mem",
            },
            "fc2": {
                "params": "fc2_params.json",
                "params_svh": "fc2_params.svh",
                "weights_mem": "fc2_weights.mem",
            },
            "fc3": {
                "params": "fc3_params.json",
                "params_svh": "fc3_params.svh",
                "weights_mem": "fc3_weights.mem",
            },
        },
    }
    _write_json(out_dir / "manifest.json", manifest)

    return out_dir
