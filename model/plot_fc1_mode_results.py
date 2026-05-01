from __future__ import annotations

import argparse
import json
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np


def _load_mode_arrays(mode_dir: Path) -> tuple[np.ndarray, np.ndarray, dict]:
    metadata = json.loads((mode_dir / "fc1_test_metadata.json").read_text(encoding="utf-8"))
    num_features = int(metadata["num_features"])
    truth = np.loadtxt(mode_dir / "fc1_test_truth.txt", dtype=np.int32).reshape(num_features, -1)
    sim = np.loadtxt(mode_dir / "fc1_sim_output.txt", dtype=np.int32).reshape(num_features, -1)
    return truth, sim, metadata


def plot_mode_results(mode_dirs: list[Path], output_path: Path) -> Path:
    if not mode_dirs:
        raise ValueError("No mode directories provided")

    loaded = []
    for mode_dir in mode_dirs:
        truth, sim, metadata = _load_mode_arrays(mode_dir)
        loaded.append((mode_dir, truth, sim, metadata))

    num_modes = len(loaded)
    num_features = loaded[0][1].shape[0]
    fig, axes = plt.subplots(
        num_modes,
        num_features,
        figsize=(7 * num_features, 3.5 * num_modes),
        squeeze=False,
        sharex=True,
        sharey=False,
    )

    for row_idx, (mode_dir, truth, sim, metadata) in enumerate(loaded):
        temp = int(metadata["temp"])
        mul_per_feature = int(metadata["mul_per_feature"])
        mismatches = int(np.count_nonzero(truth != sim))
        outputs = np.arange(truth.shape[1], dtype=np.int32)

        for feature_idx in range(num_features):
            ax = axes[row_idx][feature_idx]
            ax.plot(outputs, truth[feature_idx], label="Notebook truth", linewidth=2.0, color="#1f77b4")
            ax.plot(
                outputs,
                sim[feature_idx],
                label="Verilog sim",
                linewidth=1.5,
                linestyle="--",
                color="#d62728",
                marker="o",
                markersize=2.5,
                markevery=max(1, truth.shape[1] // 16),
            )
            ax.set_title(
                f"{mode_dir.name} | TEMP={temp}, MPF={mul_per_feature}, feature={feature_idx}, mismatches={mismatches}"
            )
            ax.set_xlabel("Output neuron")
            ax.set_ylabel("Quantized value")
            ax.grid(True, alpha=0.25)
            if row_idx == 0 and feature_idx == 0:
                ax.legend(loc="best")

    fig.tight_layout()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, dpi=160, bbox_inches="tight")
    plt.close(fig)
    return output_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Plot notebook-vs-Verilog FC1 outputs for multiple TEMP modes.")
    parser.add_argument(
        "--mode-dirs",
        nargs="+",
        required=True,
        help="Directories containing fc1_test_truth.txt and fc1_sim_output.txt",
    )
    parser.add_argument(
        "--output",
        required=True,
        help="PNG path for the generated comparison plot.",
    )
    args = parser.parse_args()

    plot_path = plot_mode_results([Path(path) for path in args.mode_dirs], Path(args.output))
    print(f"[plot] saved {plot_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
