from __future__ import annotations

import itertools
import inspect
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

import numpy as np

REPO_ROOT = Path(__file__).resolve().parent.parent
MODEL_DIR = REPO_ROOT / "model"
if str(MODEL_DIR) not in sys.path:
    sys.path.insert(0, str(MODEL_DIR))

from loader import Loader

HW_DIR = REPO_ROOT / "HW"
GENERATED_DIR = HW_DIR / "generated"
CONFIG_PATH = REPO_ROOT / "config" / "mlp_runtime_config.json"
OSS_ROOT = REPO_ROOT / "tools" / "oss-cad-suite" / "oss-cad-suite"
IVERILOG = OSS_ROOT / "bin" / "iverilog.exe"
VVP = OSS_ROOT / "bin" / "vvp.exe"
IVERILOG_WRAPPER = Path("tools") / "run-iverilog.ps1"
VVP_WRAPPER = Path("tools") / "run-vvp.ps1"

LAYER_ORDER = ["fc1", "fc2", "fc3"]
_LOADER: Loader | None = None


def env_with_oss() -> dict[str, str]:
    env = os.environ.copy()
    filtered_path = os.pathsep.join(
        part
        for part in env.get("PATH", "").split(os.pathsep)
        if part and "\\msys64\\" not in part.lower() and "\\mingw64\\" not in part.lower()
    )
    env["PATH"] = str(OSS_ROOT / "bin") + os.pathsep + str(OSS_ROOT / "lib") + os.pathsep + filtered_path
    return env


def script_path_from_cwd(script: Path, cwd: Path) -> str:
    return os.path.relpath(REPO_ROOT / script, cwd)


def powershell_wrapper_command(script: Path, cwd: Path, args: list[str]) -> list[str]:
    return [
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        script_path_from_cwd(script, cwd),
        *args,
    ]


def load_config(path: Path | None = None) -> dict[str, Any]:
    config_path = path or CONFIG_PATH
    config = json.loads(config_path.read_text(encoding="utf-8"))
    if "ui" not in config:
        config["ui"] = {}
    config["ui"].setdefault("num_features", 1)
    return config


def get_loader() -> Loader:
    global _LOADER
    if _LOADER is None:
        _LOADER = Loader(GENERATED_DIR / "quantized_mlp_params.npz")
    return _LOADER


def _to_hex_twos(value: int, bits: int) -> str:
    width = (bits + 3) // 4
    mask = (1 << bits) - 1
    return f"{value & mask:0{width}x}"


def _read_weight_rows(layer_name: str) -> list[list[int]]:
    path = GENERATED_DIR / f"{layer_name}_weights_raw.txt"
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        rows.append([int(part) for part in line.split()])
    return rows


def _read_bias_rows(layer_name: str) -> list[int]:
    path = GENERATED_DIR / f"{layer_name}_bias.txt"
    return [int(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def _split_row(row: list[int], split: int) -> list[list[int]]:
    base, extra = divmod(len(row), split)
    chunks = []
    start = 0
    for chunk_idx in range(split):
        size = base + (1 if chunk_idx < extra else 0)
        end = start + size
        chunks.append(row[start:end])
        start = end
    return chunks


def build_split_mem(layer_name: str, split: int, output_path: Path, weight_bits: int = 8, bias_bits: int = 32) -> Path:
    if split < 1:
        raise ValueError(f"split must be >= 1, got {split}")

    weights = _read_weight_rows(layer_name)
    biases = _read_bias_rows(layer_name)
    if len(weights) != len(biases):
        raise ValueError(f"{layer_name}: weights/bias length mismatch")

    rows: list[str] = []
    chunked_rows = [_split_row(row, split) for row in weights]

    for chunk_idx in range(split):
        for row_idx, bias in enumerate(biases):
            chunk = chunked_rows[row_idx][chunk_idx]
            bias_value = bias if chunk_idx == 0 else 0
            row_hex = _to_hex_twos(bias_value, bias_bits) + "".join(_to_hex_twos(int(value), weight_bits) for value in chunk)
            rows.append(row_hex)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(rows) + "\n", encoding="utf-8")
    return output_path


def prepare_runtime_weights(config: dict[str, Any], runtime_dir: Path | None = None) -> dict[str, Path]:
    runtime_root = runtime_dir or (REPO_ROOT / config["runtime_dir"])
    runtime_root.mkdir(parents=True, exist_ok=True)
    result: dict[str, Path] = {}
    for layer_name in LAYER_ORDER:
        temp = int(config["layers"][layer_name]["temp"])
        split = abs(temp) if temp < 0 else 1
        output_path = runtime_root / f"{layer_name}_weights.mem"
        build_split_mem(layer_name, split, output_path)
        result[layer_name] = output_path
    return result


def relative_to_hw(path: Path) -> str:
    return path.relative_to(HW_DIR).as_posix()


def write_runtime_override_file(path: Path, macros: dict[str, str]) -> Path:
    lines = [f"`define {name} {value}" for name, value in macros.items()]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path


def _macro_args_for_config(config: dict[str, Any], weights: dict[str, Path], extra_macros: dict[str, str] | None = None) -> list[str]:
    macros = {
        "MLP_NUM_FEATURES": "2",
        "MLP_FC1_TEMP": str(int(config["layers"]["fc1"]["temp"])),
        "MLP_FC2_TEMP": str(int(config["layers"]["fc2"]["temp"])),
        "MLP_FC3_TEMP": str(int(config["layers"]["fc3"]["temp"])),
        "MLP_FC1_MPF": str(int(config["layers"]["fc1"]["mul_per_feature"])),
        "MLP_FC2_MPF": str(int(config["layers"]["fc2"]["mul_per_feature"])),
        "MLP_FC3_MPF": str(int(config["layers"]["fc3"]["mul_per_feature"])),
    }
    if extra_macros:
        macros.update(extra_macros)
    return [f"-D{key}={value}" for key, value in macros.items()]


def _parse_metric(stdout: str, prefix: str) -> dict[str, int]:
    match = re.search(rf"{prefix}\s+cycles=(\d+)", stdout)
    metrics: dict[str, int] = {}
    if match:
        metrics["cycles"] = int(match.group(1))
    return metrics


def run_mlp_testbench(config: dict[str, Any], runtime_dir: Path | None = None) -> dict[str, Any]:
    runtime_root = runtime_dir or (REPO_ROOT / config["runtime_dir"])
    weights = prepare_runtime_weights(config, runtime_root)
    write_runtime_override_file(
        runtime_root / "mlp_runtime_overrides.svh",
        {
            "MLP_FC1_WEIGHTS_FILE": f"\"{relative_to_hw(weights['fc1'])}\"",
            "MLP_FC2_WEIGHTS_FILE": f"\"{relative_to_hw(weights['fc2'])}\"",
            "MLP_FC3_WEIGHTS_FILE": f"\"{relative_to_hw(weights['fc3'])}\"",
        },
    )
    tmp_dir = REPO_ROOT / "tmp" / "mlp_runtime"
    tmp_dir.mkdir(parents=True, exist_ok=True)
    out_vvp = tmp_dir / "mlp_config_testbench.vvp"

    compile_cmd = powershell_wrapper_command(IVERILOG_WRAPPER, REPO_ROOT, [
        "-g2012",
        "-I",
        str(HW_DIR),
        "-o",
        str(out_vvp),
        *_macro_args_for_config(config, weights),
        str(HW_DIR / "quant_relu.sv"),
        str(HW_DIR / "top_module.sv"),
        str(HW_DIR / "memory_fetcher.sv"),
        str(HW_DIR / "serial_memory_fetcher.sv"),
        str(HW_DIR / "memory_weights.sv"),
        str(HW_DIR / "multiplier_top.sv"),
        str(HW_DIR / "vector_multiplier_generator.sv"),
        str(HW_DIR / "vector_multiplier.sv"),
        str(HW_DIR / "accumulator.sv"),
        str(HW_DIR / "output_stage.sv"),
        str(HW_DIR / "burst_buffer.sv"),
        str(HW_DIR / "delay_buffer_0d.sv"),
        str(HW_DIR / "delay_buffer_2d.sv"),
        str(HW_DIR / "serial_accumulator.sv"),
        str(HW_DIR / "serial_data_scheduler.sv"),
        str(HW_DIR / "mlp_top.sv"),
        str(HW_DIR / "mlp_testbench.sv"),
    ])
    subprocess.run(compile_cmd, check=True, cwd=REPO_ROOT, env=env_with_oss(), capture_output=True, text=True)
    run = subprocess.run(
        powershell_wrapper_command(VVP_WRAPPER, HW_DIR, [str(out_vvp)]),
        check=True,
        cwd=HW_DIR,
        env=env_with_oss(),
        capture_output=True,
        text=True,
    )
    metrics = _parse_metric(run.stdout, "METRIC")
    metrics["multiplier_cost"] = sum(int(config["layers"][layer]["mul_per_feature"]) for layer in LAYER_ORDER)
    result = {
        "stdout": run.stdout,
        "metrics": metrics,
        "weights": {name: str(path) for name, path in weights.items()},
    }
    (runtime_root / "last_self_test.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    return result


def quantize_pixels(pixels: list[int] | list[list[int]]) -> list[int]:
    input_quant = json.loads((GENERATED_DIR / "input_quant.json").read_text(encoding="utf-8"))
    if pixels and isinstance(pixels[0], list):
        flat = [int(value) for row in pixels for value in row]  # type: ignore[index]
    else:
        flat = [int(value) for value in pixels]  # type: ignore[arg-type]
    if len(flat) != 784:
        raise ValueError(f"Expected 784 pixels, got {len(flat)}")

    bits = int(input_quant["bits"])
    zero_point = int(input_quant["zero_point"])
    multiplier = int(input_quant["M_int"])
    shift = int(input_quant["shift"])
    correction = int(input_quant["C_int"])
    qmin = 0
    qmax = (1 << bits) - 1

    result = []
    for value in flat:
        acc = value * multiplier - correction
        quantized = (acc >> shift) + zero_point
        result.append(max(qmin, min(qmax, int(quantized))))
    return result


def write_ui_input_mem(quantized_pixels: list[int], input_mem_path: Path) -> Path:
    input_mem_path.parent.mkdir(parents=True, exist_ok=True)
    input_mem_path.write_text("\n".join(_to_hex_twos(value, 8) for value in quantized_pixels) + "\n", encoding="utf-8")
    (input_mem_path.with_suffix(".txt")).write_text("\n".join(str(v) for v in quantized_pixels) + "\n", encoding="utf-8")
    return input_mem_path


def run_ui_simulation(config: dict[str, Any], pixels: list[int] | list[list[int]]) -> dict[str, Any]:
    runtime_root = REPO_ROOT / config["runtime_dir"]
    runtime_root.mkdir(parents=True, exist_ok=True)
    weights = prepare_runtime_weights(config, runtime_root)
    quantized = quantize_pixels(pixels)
    input_mem_path = runtime_root / str(config["ui"]["input_file"])
    output_file_path = runtime_root / str(config["ui"]["output_file"])
    write_ui_input_mem(quantized, input_mem_path)

    tmp_dir = REPO_ROOT / "tmp" / "mlp_runtime"
    tmp_dir.mkdir(parents=True, exist_ok=True)
    out_vvp = tmp_dir / "mlp_ui_testbench.vvp"

    write_runtime_override_file(
        runtime_root / "mlp_ui_runtime_overrides.svh",
        {
            "UI_INPUT_FILE": f"\"{relative_to_hw(input_mem_path)}\"",
            "UI_OUTPUT_FILE": f"\"{relative_to_hw(output_file_path)}\"",
            "UI_FC1_WEIGHTS_FILE": f"\"{relative_to_hw(weights['fc1'])}\"",
            "UI_FC2_WEIGHTS_FILE": f"\"{relative_to_hw(weights['fc2'])}\"",
            "UI_FC3_WEIGHTS_FILE": f"\"{relative_to_hw(weights['fc3'])}\"",
        },
    )

    ui_macros = {
        "UI_FC1_TEMP": str(int(config["layers"]["fc1"]["temp"])),
        "UI_FC2_TEMP": str(int(config["layers"]["fc2"]["temp"])),
        "UI_FC3_TEMP": str(int(config["layers"]["fc3"]["temp"])),
        "UI_FC1_MPF": str(int(config["layers"]["fc1"]["mul_per_feature"])),
        "UI_FC2_MPF": str(int(config["layers"]["fc2"]["mul_per_feature"])),
        "UI_FC3_MPF": str(int(config["layers"]["fc3"]["mul_per_feature"])),
    }
    compile_cmd = powershell_wrapper_command(IVERILOG_WRAPPER, REPO_ROOT, [
        "-g2012",
        "-I",
        str(HW_DIR),
        "-o",
        str(out_vvp),
        *[f"-D{key}={value}" for key, value in ui_macros.items()],
        str(HW_DIR / "quant_relu.sv"),
        str(HW_DIR / "top_module.sv"),
        str(HW_DIR / "memory_fetcher.sv"),
        str(HW_DIR / "serial_memory_fetcher.sv"),
        str(HW_DIR / "memory_weights.sv"),
        str(HW_DIR / "multiplier_top.sv"),
        str(HW_DIR / "vector_multiplier_generator.sv"),
        str(HW_DIR / "vector_multiplier.sv"),
        str(HW_DIR / "accumulator.sv"),
        str(HW_DIR / "output_stage.sv"),
        str(HW_DIR / "burst_buffer.sv"),
        str(HW_DIR / "delay_buffer_0d.sv"),
        str(HW_DIR / "delay_buffer_2d.sv"),
        str(HW_DIR / "serial_accumulator.sv"),
        str(HW_DIR / "serial_data_scheduler.sv"),
        str(HW_DIR / "mlp_top.sv"),
        str(HW_DIR / "mlp_ui_testbench.sv"),
    ])
    subprocess.run(compile_cmd, check=True, cwd=REPO_ROOT, env=env_with_oss(), capture_output=True, text=True)
    run = subprocess.run(
        powershell_wrapper_command(VVP_WRAPPER, HW_DIR, [str(out_vvp)]),
        check=True,
        cwd=HW_DIR,
        env=env_with_oss(),
        capture_output=True,
        text=True,
    )
    logits = [int(line) for line in output_file_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    metrics = _parse_metric(run.stdout, "UI_METRIC")
    prediction = max(range(len(logits)), key=lambda idx: logits[idx]) if logits else -1
    request_path = runtime_root / "ui_request.json"
    request_path.write_text(
        json.dumps(
            {
                "config": config,
                "quantized_pixels": quantized,
                "logits": logits,
                "prediction": prediction,
                "metrics": metrics,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    return {
        "logits": logits,
        "prediction": prediction,
        "metrics": metrics,
        "backend": "verilog",
        "files": {
            "input_mem": str(input_mem_path),
            "input_txt": str(input_mem_path.with_suffix(".txt")),
            "output_txt": str(output_file_path),
            "request_json": str(request_path),
        },
        "stdout": run.stdout,
    }


def run_python_simulation(config: dict[str, Any], pixels: list[int] | list[list[int]]) -> dict[str, Any]:
    runtime_root = REPO_ROOT / config["runtime_dir"]
    runtime_root.mkdir(parents=True, exist_ok=True)

    if pixels and isinstance(pixels[0], list):
        flat_pixels = [int(value) for row in pixels for value in row]  # type: ignore[index]
    else:
        flat_pixels = [int(value) for value in pixels]  # type: ignore[arg-type]
    if len(flat_pixels) != 784:
        raise ValueError(f"Expected 784 pixels, got {len(flat_pixels)}")

    loader = get_loader()
    trace = loader.run_integer_trace(np.asarray(flat_pixels, dtype=np.int32))
    logits = [int(value) for value in trace["fc3_out"][0].tolist()]
    prediction = int(trace["prediction"])
    request_path = runtime_root / "ui_request_python.json"
    request_path.write_text(
        json.dumps(
            {
                "config": config,
                "pixels": flat_pixels,
                "logits": logits,
                "prediction": prediction,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    return {
        "logits": logits,
        "prediction": prediction,
        "metrics": {},
        "backend": "python",
        "files": {
            "request_json": str(request_path),
            "params_npz": str(loader.params_path),
        },
        "stdout": "",
    }


def runtime_audit() -> dict[str, Any]:
    all_runtime_files = [
        REPO_ROOT / "tools" / "mlp_runtime_lib.py",
        REPO_ROOT / "tools" / "ui_server.py",
        REPO_ROOT / "tools" / "run_mlp_config.py",
        REPO_ROOT / "tools" / "run_mlp_sweep.py",
        HW_DIR / "mlp_ui_testbench.sv",
    ]
    ui_runtime_files = [
        REPO_ROOT / "tools" / "ui_server.py",
        HW_DIR / "mlp_ui_testbench.sv",
    ]
    audit = {
        "files": [str(path) for path in all_runtime_files],
        "ui_files": [str(path) for path in ui_runtime_files],
        "contains_torch": {},
        "contains_truth_refs": {},
        "ui_runtime_contains_torch": {},
        "ui_runtime_contains_truth_refs": {},
    }
    for path in all_runtime_files:
        text = path.read_text(encoding="utf-8")
        audit["contains_torch"][str(path)] = "torch" in text or "torchvision" in text
        audit["contains_truth_refs"][str(path)] = "truth" in text.lower()
    for path in ui_runtime_files:
        text = path.read_text(encoding="utf-8")
        audit["ui_runtime_contains_torch"][str(path)] = "torch" in text or "torchvision" in text
        audit["ui_runtime_contains_truth_refs"][str(path)] = "truth" in text.lower()
    ui_functions = {
        "quantize_pixels": inspect.getsource(quantize_pixels),
        "write_ui_input_mem": inspect.getsource(write_ui_input_mem),
        "run_ui_simulation": inspect.getsource(run_ui_simulation),
    }
    audit["ui_runtime_functions"] = {
        name: {
            "contains_torch": ("torch" in source or "torchvision" in source),
            "contains_truth_refs": ("truth" in source.lower()),
        }
        for name, source in ui_functions.items()
    }
    audit["torch_free"] = not any(audit["contains_torch"].values())
    audit["ui_torch_free"] = not any(audit["ui_runtime_contains_torch"].values()) and not any(
        entry["contains_torch"] for entry in audit["ui_runtime_functions"].values()
    )
    audit["ui_truth_free"] = not any(audit["ui_runtime_contains_truth_refs"].values()) and not any(
        entry["contains_truth_refs"] for entry in audit["ui_runtime_functions"].values()
    )
    audit["runtime_dir"] = str(REPO_ROOT / load_config()["runtime_dir"])
    return audit


def sweep_configs(config: dict[str, Any]) -> list[dict[str, Any]]:
    sweep = config["sweep"]
    fc1_temps = sweep["fc1"]["temp"]
    fc1_mpfs = sweep["fc1"]["mul_per_feature"]
    fc2_temps = sweep["fc2"]["temp"]
    fc2_mpfs = sweep["fc2"]["mul_per_feature"]
    fc3_temps = sweep["fc3"]["temp"]
    fc3_mpfs = sweep["fc3"]["mul_per_feature"]

    results = []
    runtime_root = REPO_ROOT / config["runtime_dir"]
    runtime_root.mkdir(parents=True, exist_ok=True)
    output_path = runtime_root / "mlp_sweep_results.json"
    for fc1_temp, fc1_mpf, fc2_temp, fc2_mpf, fc3_temp, fc3_mpf in itertools.product(
        fc1_temps, fc1_mpfs, fc2_temps, fc2_mpfs, fc3_temps, fc3_mpfs
    ):
        sweep_config = json.loads(json.dumps(config))
        sweep_config["layers"]["fc1"]["temp"] = int(fc1_temp)
        sweep_config["layers"]["fc1"]["mul_per_feature"] = int(fc1_mpf)
        sweep_config["layers"]["fc2"]["temp"] = int(fc2_temp)
        sweep_config["layers"]["fc2"]["mul_per_feature"] = int(fc2_mpf)
        sweep_config["layers"]["fc3"]["temp"] = int(fc3_temp)
        sweep_config["layers"]["fc3"]["mul_per_feature"] = int(fc3_mpf)
        try:
            bench = run_mlp_testbench(sweep_config)
            results.append(
                {
                    "layers": sweep_config["layers"],
                    "cycles": bench["metrics"].get("cycles"),
                    "multiplier_cost": bench["metrics"].get("multiplier_cost"),
                    "pass": True,
                }
            )
        except subprocess.CalledProcessError as exc:
            results.append(
                {
                    "layers": sweep_config["layers"],
                    "pass": False,
                    "error": exc.stdout or exc.stderr or str(exc),
                }
            )
        output_path.write_text(json.dumps(results, indent=2), encoding="utf-8")
    results.sort(key=lambda item: (not item["pass"], item.get("cycles", 1 << 30), item.get("multiplier_cost", 1 << 30)))
    output_path.write_text(json.dumps(results, indent=2), encoding="utf-8")
    return results


def sweep_layers_independently(config: dict[str, Any]) -> dict[str, list[dict[str, Any]]]:
    runtime_root = REPO_ROOT / config["runtime_dir"]
    runtime_root.mkdir(parents=True, exist_ok=True)
    results_by_layer: dict[str, list[dict[str, Any]]] = {}

    for layer_name in LAYER_ORDER:
        layer_results: list[dict[str, Any]] = []
        temps = config["sweep"][layer_name]["temp"]
        mpfs = config["sweep"][layer_name]["mul_per_feature"]
        for temp, mpf in itertools.product(temps, mpfs):
            sweep_config = json.loads(json.dumps(config))
            sweep_config["layers"][layer_name]["temp"] = int(temp)
            sweep_config["layers"][layer_name]["mul_per_feature"] = int(mpf)
            try:
                bench = run_mlp_testbench(sweep_config)
                layer_results.append(
                    {
                        "layer": layer_name,
                        "temp": int(temp),
                        "mul_per_feature": int(mpf),
                        "cycles": bench["metrics"].get("cycles"),
                        "multiplier_cost": bench["metrics"].get("multiplier_cost"),
                        "pass": True,
                    }
                )
            except subprocess.CalledProcessError as exc:
                layer_results.append(
                    {
                        "layer": layer_name,
                        "temp": int(temp),
                        "mul_per_feature": int(mpf),
                        "pass": False,
                        "error": exc.stdout or exc.stderr or str(exc),
                    }
                )
            (runtime_root / f"mlp_sweep_{layer_name}.json").write_text(json.dumps(layer_results, indent=2), encoding="utf-8")
        layer_results.sort(key=lambda item: (not item["pass"], item.get("cycles", 1 << 30), item.get("mul_per_feature", 1 << 30)))
        results_by_layer[layer_name] = layer_results

    (runtime_root / "mlp_layer_sweeps.json").write_text(json.dumps(results_by_layer, indent=2), encoding="utf-8")
    return results_by_layer
