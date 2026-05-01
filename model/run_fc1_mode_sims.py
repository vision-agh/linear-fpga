from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import convert
import loader
from fc1_hw_test import compare_fc1_output, generate_fc1_case
from plot_fc1_mode_results import plot_mode_results


REPO_ROOT = Path(__file__).resolve().parent.parent
HW_DIR = REPO_ROOT / "HW"
TMP_DIR = REPO_ROOT / "tmp" / "fc1_mode_sims"
OSS_ROOT = REPO_ROOT / "tools" / "oss-cad-suite" / "oss-cad-suite"
IVERILOG = OSS_ROOT / "bin" / "iverilog.exe"
VVP = OSS_ROOT / "bin" / "vvp.exe"

MODE_CONFIGS = [
    {"label": "temp_p1", "temp": 1, "mul_per_feature": 8, "split": 1},
    {"label": "temp_p2", "temp": 2, "mul_per_feature": 8, "split": 1},
    {"label": "temp_n2", "temp": -2, "mul_per_feature": 8, "split": 2},
]

RTL_SOURCES = [
    "top_module.sv",
    "memory_fetcher.sv",
    "serial_memory_fetcher.sv",
    "memory_weights.sv",
    "multiplier_top.sv",
    "vector_multiplier_generator.sv",
    "vector_multiplier.sv",
    "accumulator.sv",
    "output_stage.sv",
    "burst_buffer.sv",
    "delay_buffer_0d.sv",
    "delay_buffer_2d.sv",
    "serial_accumulator.sv",
    "serial_data_scheduler.sv",
    "fc1_mode_testbench.sv",
]


def env_with_oss() -> dict[str, str]:
    env = os.environ.copy()
    filtered_path = os.pathsep.join(
        part
        for part in env.get("PATH", "").split(os.pathsep)
        if part and "\\msys64\\" not in part.lower() and "\\mingw64\\" not in part.lower()
    )
    env["PATH"] = str(OSS_ROOT / "bin") + os.pathsep + str(OSS_ROOT / "lib") + os.pathsep + filtered_path
    return env


def relative_to_hw(path: Path) -> str:
    return path.relative_to(HW_DIR).as_posix()


def run_mode(mode_dir: Path, temp: int, mul_per_feature: int) -> int:
    out_vvp = TMP_DIR / f"{mode_dir.name}.vvp"
    compile_cmd = [
        str(IVERILOG),
        "-g2012",
        "-I",
        str(HW_DIR),
        "-I",
        str(mode_dir),
        f"-DFC1_TEMP={temp}",
        f"-DFC1_MUL_PER_FEATURE={mul_per_feature}",
        f'-DFC1_FEATURES_FILE="{relative_to_hw(mode_dir / "fc1_test_input.mem")}"',
        f'-DFC1_TRUTH_FILE="{relative_to_hw(mode_dir / "fc1_test_truth.mem")}"',
        f'-DFC1_WEIGHTS_FILE="{relative_to_hw(mode_dir / "fc1_weights.mem")}"',
        f'-DFC1_OUTPUT_FILE="{relative_to_hw(mode_dir / "fc1_sim_output.txt")}"',
        "-o",
        str(out_vvp),
    ]
    compile_cmd.extend(str(HW_DIR / source) for source in RTL_SOURCES)
    subprocess.run(compile_cmd, check=True, cwd=REPO_ROOT, env=env_with_oss())
    subprocess.run([str(VVP), str(out_vvp)], check=True, cwd=HW_DIR, env=env_with_oss())
    return compare_fc1_output(mode_dir)


def main() -> int:
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    params_path = REPO_ROOT / "model" / "quantized_mlp_params.npz"
    modes_root = HW_DIR / "generated" / "modes"
    modes_root.mkdir(parents=True, exist_ok=True)

    mode_dirs: list[Path] = []
    summary: list[dict[str, int | str | bool]] = []

    for config in MODE_CONFIGS:
        mode_dir = modes_root / str(config["label"])
        mode_dir.mkdir(parents=True, exist_ok=True)

        model = loader.Loader(params_path)
        convert.export_model(model, mode_dir, split=int(config["split"]), copy_params=False)
        generate_fc1_case(
            params_path=params_path,
            output_dir=mode_dir,
            sample_idx=1,
            num_features=2,
            temp=int(config["temp"]),
            mul_per_feature=int(config["mul_per_feature"]),
        )

        mismatch_count = run_mode(
            mode_dir,
            temp=int(config["temp"]),
            mul_per_feature=int(config["mul_per_feature"]),
        )
        mode_dirs.append(mode_dir)
        summary.append(
            {
                "label": str(config["label"]),
                "temp": int(config["temp"]),
                "mul_per_feature": int(config["mul_per_feature"]),
                "split": int(config["split"]),
                "mismatch_count": int(mismatch_count),
                "matches": mismatch_count == 0,
                "mode_dir": str(mode_dir),
            }
        )

    summary_path = modes_root / "fc1_mode_summary.json"
    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    plot_path = plot_mode_results(mode_dirs, modes_root / "fc1_mode_comparison.png")
    print(json.dumps(summary, indent=2))
    print(f"[summary] saved {summary_path}")
    print(f"[plot] saved {plot_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
