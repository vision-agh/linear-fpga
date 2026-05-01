from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
HW_DIR = REPO_ROOT / "HW"
TEST_DIR = HW_DIR / "quick_tests"
TMP_DIR = REPO_ROOT / "tmp" / "quick_tests"
OSS_ROOT = REPO_ROOT / "tools" / "oss-cad-suite" / "oss-cad-suite"
IVERILOG = OSS_ROOT / "bin" / "iverilog.exe"
VVP = OSS_ROOT / "bin" / "vvp.exe"


def env_with_oss() -> dict[str, str]:
    env = os.environ.copy()
    filtered_path = os.pathsep.join(
        part
        for part in env.get("PATH", "").split(os.pathsep)
        if part and "\\msys64\\" not in part.lower() and "\\mingw64\\" not in part.lower()
    )
    env["PATH"] = str(OSS_ROOT / "bin") + os.pathsep + str(OSS_ROOT / "lib") + os.pathsep + filtered_path
    return env


TESTS: list[tuple[str, list[str]]] = [
    ("tb_vector_multiplier", ["vector_multiplier.sv", "quick_tests/tb_vector_multiplier.sv"]),
    (
        "tb_vector_multiplier_generator",
        [
            "vector_multiplier.sv",
            "vector_multiplier_generator.sv",
            "quick_tests/tb_vector_multiplier_generator.sv",
        ],
    ),
    ("tb_accumulator", ["accumulator.sv", "quick_tests/tb_accumulator.sv"]),
    ("tb_output_stage", ["output_stage.sv", "quick_tests/tb_output_stage.sv"]),
    ("tb_delay_buffer_0d", ["delay_buffer_0d.sv", "quick_tests/tb_delay_buffer_0d.sv"]),
    ("tb_delay_buffer_2d", ["delay_buffer_2d.sv", "quick_tests/tb_delay_buffer_2d.sv"]),
    ("tb_memory_fetcher", ["memory_weights.sv", "memory_fetcher.sv", "quick_tests/tb_memory_fetcher.sv"]),
    ("tb_burst_buffer", ["burst_buffer.sv", "quick_tests/tb_burst_buffer.sv"]),
    (
        "tb_multiplier_top",
        [
            "delay_buffer_0d.sv",
            "delay_buffer_2d.sv",
            "vector_multiplier.sv",
            "vector_multiplier_generator.sv",
            "accumulator.sv",
            "output_stage.sv",
            "multiplier_top.sv",
            "quick_tests/tb_multiplier_top.sv",
        ],
    ),
    (
        "tb_multiplier_top_stream",
        [
            "delay_buffer_0d.sv",
            "delay_buffer_2d.sv",
            "vector_multiplier.sv",
            "vector_multiplier_generator.sv",
            "accumulator.sv",
            "output_stage.sv",
            "multiplier_top.sv",
            "quick_tests/tb_multiplier_top_stream.sv",
        ],
    ),
    (
        "tb_top_module",
        [
            "delay_buffer_0d.sv",
            "delay_buffer_2d.sv",
            "vector_multiplier.sv",
            "vector_multiplier_generator.sv",
            "accumulator.sv",
            "output_stage.sv",
            "memory_weights.sv",
            "memory_fetcher.sv",
            "burst_buffer.sv",
            "serial_memory_fetcher.sv",
            "serial_accumulator.sv",
            "serial_data_scheduler.sv",
            "multiplier_top.sv",
            "top_module.sv",
            "quick_tests/tb_top_module.sv",
        ],
    ),
]

SLICE_TEST_FILES = [
    "delay_buffer_0d.sv",
    "delay_buffer_2d.sv",
    "vector_multiplier.sv",
    "vector_multiplier_generator.sv",
    "accumulator.sv",
    "output_stage.sv",
    "memory_weights.sv",
    "memory_fetcher.sv",
    "burst_buffer.sv",
    "serial_memory_fetcher.sv",
    "serial_accumulator.sv",
    "serial_data_scheduler.sv",
    "multiplier_top.sv",
    "top_module.sv",
    "quick_tests/tb_top_module_fc1_slice_generic.sv",
]


def run_test(name: str, files: list[str]) -> None:
    out = TMP_DIR / f"{name}.vvp"
    compile_cmd = [str(IVERILOG), "-g2012", "-I", str(HW_DIR), "-o", str(out)]
    compile_cmd.extend(str(HW_DIR / file) for file in files)
    subprocess.run(compile_cmd, check=True, cwd=REPO_ROOT, env=env_with_oss())
    subprocess.run([str(VVP), str(out)], check=True, cwd=HW_DIR, env=env_with_oss())


def run_slice_test(slice_m: int) -> None:
    name = f"tb_top_module_fc1_slice_m{slice_m}"
    out = TMP_DIR / f"{name}.vvp"
    compile_cmd = [
        str(IVERILOG),
        "-g2012",
        "-I",
        str(HW_DIR),
        f'-DSLICE_M={slice_m}',
        f'-DSLICE_WEIGHTS_FILE="quick_tests/fc1_slice_{slice_m}_weights.mem"',
        f'-DSLICE_INPUT_FILE="quick_tests/fc1_slice_{slice_m}_input.mem"',
        f'-DSLICE_TRUTH_FILE="quick_tests/fc1_slice_{slice_m}_truth.mem"',
        "-o",
        str(out),
    ]
    compile_cmd.extend(str(HW_DIR / file) for file in SLICE_TEST_FILES)
    subprocess.run(compile_cmd, check=True, cwd=REPO_ROOT, env=env_with_oss())
    subprocess.run([str(VVP), str(out)], check=True, cwd=HW_DIR, env=env_with_oss())


def main() -> int:
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [sys.executable, str(TEST_DIR / "generate_fc1_slice.py")],
        check=True,
        cwd=REPO_ROOT,
    )
    for name, files in TESTS:
        print(f"== {name} ==")
        run_test(name, files)
    for slice_m in (4, 8, 16, 32, 64, 96, 128):
        print(f"== tb_top_module_fc1_slice_m{slice_m} ==")
        run_slice_test(slice_m)
    print("All quick tests passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
