from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np

MUL_PER_FEATURE_1 = 1
MUL_PER_FEATURE_2 = 1
MUL_PER_FEATURE_3 = 1


def _scalar(value: np.ndarray | np.generic | int | float | bool) -> Any:
    if isinstance(value, np.ndarray):
        if value.shape != ():
            return value
        return value.item()
    if isinstance(value, np.generic):
        return value.item()
    return value


def compute_int_scale(scale: float, bits: int = 31) -> tuple[int, int]:
    """Notebook-compatible helper that approximates 1/scale with M >> shift."""
    scale = float(scale)
    if scale <= 0.0:
        raise ValueError(f"scale must be positive, got {scale!r}")

    inv = 1.0 / scale
    shift = bits - int(np.floor(np.log2(inv))) - 1
    shift = max(0, shift)
    multiplier = int(round(inv * (2**shift)))
    return multiplier, shift


def quantize_fpga(
    x: np.ndarray,
    multiplier: int,
    correction: int,
    shift: int,
    zero_point: int,
    num_bits: int,
    signed: bool,
) -> np.ndarray:
    qmin = -(2 ** (num_bits - 1)) if signed else 0
    qmax = (2 ** (num_bits - 1) - 1) if signed else (2**num_bits - 1)
    acc = x.astype(np.int64) * int(multiplier) - int(correction)
    y = acc >> int(shift)
    return np.clip(y + int(zero_point), qmin, qmax).astype(np.int32)


def quant_linear_fpga(
    x: np.ndarray,
    x_zp: int,
    w_q: np.ndarray,
    b_q: np.ndarray,
    multiplier: int,
    shift: int,
    out_zp: int,
    num_bits: int,
    signed: bool,
) -> np.ndarray:
    qmin = -(2 ** (num_bits - 1)) if signed else 0
    qmax = (2 ** (num_bits - 1) - 1) if signed else (2**num_bits - 1)

    x_c = x.astype(np.int64) - int(x_zp)
    acc = x_c @ w_q.astype(np.int64).T
    acc = acc + b_q.astype(np.int64)
    y = (acc * int(multiplier)) >> int(shift)
    y = y + int(out_zp)
    return np.clip(y, qmin, qmax).astype(np.int32)


@dataclass
class LayerData:
    name: str
    weights: np.ndarray
    weights_centered: np.ndarray
    bias: np.ndarray
    weight_zero_point: int
    input_zero_point: int
    output_zero_point: int
    multiplier_float: float
    multiplier_int: int
    shift: int
    input_bits: int
    weight_bits: int
    output_bits: int
    bias_bits: int
    mul_per_feature: int

    @property
    def input_size(self) -> int:
        return int(self.weights.shape[1])

    @property
    def output_size(self) -> int:
        return int(self.weights.shape[0])

    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "w_q": self.weights_centered,
            "w_q_raw": self.weights,
            "bias": self.bias,
            "w_zp": np.int64(self.weight_zero_point),
            "in_zp": np.int64(self.input_zero_point),
            "out_zp": np.int64(self.output_zero_point),
            "M_float": np.float64(self.multiplier_float),
            "M_int": np.int64(self.multiplier_int),
            "shift": np.int64(self.shift),
            "precision": np.int64(self.weight_bits),
            "input_precision": np.int64(self.input_bits),
            "output_precision": np.int64(self.output_bits),
            "bias_precision": np.int64(self.bias_bits),
            "N": np.int64(self.input_size),
            "M": np.int64(self.output_size),
            "mul_per_feature": np.int64(self.mul_per_feature),
        }


class Loader:
    def __init__(self, params_path: str | Path = "quantized_mlp_params.npz"):
        self.params_path = self._resolve_params_path(params_path)
        self.fpga_r = np.load(self.params_path)

        self.signed = bool(_scalar(self.fpga_r["signed"]))
        self.symmetric = bool(_scalar(self.fpga_r["symmetric"]))

        self.input_quant = self._build_input_quant()
        self.layers = [
            self._build_layer("fc1", "in_bits", "fc1_w_bits", "fc1_out_bits", "in_zp", "fc1_zp", MUL_PER_FEATURE_1),
            self._build_layer("fc2", "fc1_out_bits", "fc2_w_bits", "fc2_out_bits", "fc1_zp", "fc2_zp", MUL_PER_FEATURE_2),
            self._build_layer("fc3", "fc2_out_bits", "fc3_w_bits", "out_bits", "fc2_zp", "out_zp", MUL_PER_FEATURE_3),
        ]

        self.l1, self.l2, self.l3 = (layer.to_dict() for layer in self.layers)

    def _resolve_params_path(self, params_path: str | Path) -> Path:
        candidate = Path(params_path)
        if candidate.is_file():
            return candidate.resolve()

        local_candidate = Path(__file__).resolve().parent / candidate
        if local_candidate.is_file():
            return local_candidate.resolve()

        raise FileNotFoundError(f"Could not find parameter file: {params_path}")

    def _build_input_quant(self) -> dict[str, Any]:
        in_scale = float(_scalar(self.fpga_r["in_s"]))
        in_zero_point = int(round(float(_scalar(self.fpga_r["in_zp"]))))
        in_bits = int(_scalar(self.fpga_r["in_bits"]))
        offset = 127.5 if not self.symmetric else -0.5

        scale_255 = in_scale * 127.5
        multiplier, shift = compute_int_scale(scale_255, bits=31)
        correction = int(round(offset * (2**shift) / scale_255))

        return {
            "scale": in_scale,
            "zero_point": in_zero_point,
            "bits": in_bits,
            "offset": offset,
            "scale_255": scale_255,
            "M_int": multiplier,
            "shift": shift,
            "C_int": correction,
        }

    def _build_layer(
        self,
        prefix: str,
        input_bits_key: str,
        weight_bits_key: str,
        output_bits_key: str,
        input_zp_key: str,
        output_zp_key: str,
        mul_per_feature: int,
    ) -> LayerData:
        weights = self.fpga_r[f"{prefix}_w"].astype(np.int32)
        weight_zero_point = int(round(float(_scalar(self.fpga_r[f"{prefix}_w_zp"]))))
        weights_centered = weights - weight_zero_point
        multiplier_float = float(_scalar(self.fpga_r[f"{prefix}_M"]))
        multiplier_int, shift = compute_int_scale(1.0 / multiplier_float, bits=31)

        return LayerData(
            name=prefix,
            weights=weights,
            weights_centered=weights_centered.astype(np.int32),
            bias=self.fpga_r[f"{prefix}_b_q"].astype(np.int32),
            weight_zero_point=weight_zero_point,
            input_zero_point=int(round(float(_scalar(self.fpga_r[input_zp_key])))),
            output_zero_point=int(round(float(_scalar(self.fpga_r[output_zp_key])))),
            multiplier_float=multiplier_float,
            multiplier_int=multiplier_int,
            shift=shift,
            input_bits=int(_scalar(self.fpga_r[input_bits_key])),
            weight_bits=int(_scalar(self.fpga_r[weight_bits_key])),
            output_bits=int(_scalar(self.fpga_r[output_bits_key])),
            bias_bits=32,
            mul_per_feature=mul_per_feature,
        )

    def describe(self) -> dict[str, Any]:
        return {
            "params_path": str(self.params_path),
            "signed": self.signed,
            "symmetric": self.symmetric,
            "input_quant": self.input_quant,
            "layers": [
                {
                    "name": layer.name,
                    "input_size": layer.input_size,
                    "output_size": layer.output_size,
                    "input_bits": layer.input_bits,
                    "weight_bits": layer.weight_bits,
                    "output_bits": layer.output_bits,
                    "input_zero_point": layer.input_zero_point,
                    "weight_zero_point": layer.weight_zero_point,
                    "output_zero_point": layer.output_zero_point,
                    "M_float": layer.multiplier_float,
                    "M_int": layer.multiplier_int,
                    "shift": layer.shift,
                }
                for layer in self.layers
            ],
        }

    def run_integer_trace(self, input_image: np.ndarray) -> dict[str, np.ndarray | int]:
        x = np.asarray(input_image, dtype=np.int32)
        if x.ndim == 1:
            x = x.reshape(1, -1)
        elif x.ndim != 2:
            raise ValueError(f"Expected 1D or 2D input, got shape {x.shape}")

        img_quantized = quantize_fpga(
            x,
            self.input_quant["M_int"],
            self.input_quant["C_int"],
            self.input_quant["shift"],
            self.input_quant["zero_point"],
            self.input_quant["bits"],
            self.signed,
        )

        fc1 = quant_linear_fpga(
            img_quantized,
            self.layers[0].input_zero_point,
            self.layers[0].weights_centered,
            self.layers[0].bias,
            self.layers[0].multiplier_int,
            self.layers[0].shift,
            self.layers[0].output_zero_point,
            self.layers[0].output_bits,
            self.signed,
        )
        relu1 = np.maximum(fc1, self.layers[0].output_zero_point)

        fc2 = quant_linear_fpga(
            relu1,
            self.layers[1].input_zero_point,
            self.layers[1].weights_centered,
            self.layers[1].bias,
            self.layers[1].multiplier_int,
            self.layers[1].shift,
            self.layers[1].output_zero_point,
            self.layers[1].output_bits,
            self.signed,
        )
        relu2 = np.maximum(fc2, self.layers[1].output_zero_point)

        fc3 = quant_linear_fpga(
            relu2,
            self.layers[2].input_zero_point,
            self.layers[2].weights_centered,
            self.layers[2].bias,
            self.layers[2].multiplier_int,
            self.layers[2].shift,
            self.layers[2].output_zero_point,
            self.layers[2].output_bits,
            self.signed,
        )

        return {
            "input_image": x.astype(np.int32),
            "img_quantized": img_quantized,
            "fc1_out": fc1,
            "relu1_out": relu1,
            "fc2_out": fc2,
            "relu2_out": relu2,
            "fc3_out": fc3,
            "prediction": int(fc3.argmax(axis=-1)[0]),
        }
