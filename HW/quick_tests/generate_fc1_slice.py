from __future__ import annotations

import json
from pathlib import Path
import sys

import numpy as np

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from model.fc1_hw_test import generate_fc1_case, write_mem, write_txt


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    generated_dir = repo_root / "HW" / "generated"
    quick_dir = repo_root / "HW" / "quick_tests"
    params_path = repo_root / "model" / "quantized_mlp_params.npz"

    metadata = generate_fc1_case(
        params_path=params_path,
        output_dir=generated_dir,
        sample_idx=1,
        num_features=2,
        temp=2,
        mul_per_feature=8,
    )

    slice_sizes = [4, 8, 16, 32, 64, 96, 128]
    full_weights_rows = (generated_dir / "fc1_weights.mem").read_text(encoding="utf-8").splitlines()
    inputs = np.loadtxt(generated_dir / "fc1_test_input.txt", dtype=np.int32).reshape(2, 784)
    full_truth = np.loadtxt(generated_dir / "fc1_test_truth.txt", dtype=np.int32).reshape(2, 128)

    for slice_m in slice_sizes:
        slice_rows = full_weights_rows[:slice_m]
        (quick_dir / f"fc1_slice_{slice_m}_weights.mem").write_text(
            "\n".join(slice_rows) + "\n",
            encoding="utf-8",
        )

        truth = full_truth[:, :slice_m]
        write_mem(quick_dir / f"fc1_slice_{slice_m}_input.mem", inputs, bits=int(metadata["input_bits"]))
        write_mem(quick_dir / f"fc1_slice_{slice_m}_truth.mem", truth, bits=int(metadata["output_bits"]))
        write_txt(quick_dir / f"fc1_slice_{slice_m}_input.txt", inputs)
        write_txt(quick_dir / f"fc1_slice_{slice_m}_truth.txt", truth)

    summary = {
        "slice_sizes": slice_sizes,
        "num_features": 2,
        "n": 784,
        "input_bits": metadata["input_bits"],
        "output_bits": metadata["output_bits"],
        "in_zp": metadata["input_zero_point"],
        "out_zp": metadata["output_zero_point"],
        "m_mul": metadata["fc1_multiplier"],
        "m_shift": metadata["fc1_shift"],
    }
    (quick_dir / "fc1_slice_metadata.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
