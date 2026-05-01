from __future__ import annotations

import json
import sys
from pathlib import Path

import matplotlib.pyplot as plt

from mlp_runtime_lib import load_config


def main() -> int:
    config = load_config()
    runtime_dir = Path(config["runtime_dir"])
    input_path = runtime_dir / "mlp_layer_sweeps.json"
    output_path = runtime_dir / "mlp_layer_sweeps_plot.png"
    summary_path = runtime_dir / "mlp_layer_sweeps_best.json"

    results_by_layer = json.loads(input_path.read_text(encoding="utf-8"))
    best_by_layer = {}

    fig, axes = plt.subplots(1, 3, figsize=(15, 5), sharey=True)
    colors = {"fc1": "#005f73", "fc2": "#0a9396", "fc3": "#ca6702"}

    for ax, layer_name in zip(axes, ("fc1", "fc2", "fc3")):
        results = results_by_layer[layer_name]
        passing = [entry for entry in results if entry.get("pass")]
        if not passing:
            ax.set_title(f"{layer_name} (no passing configs)")
            ax.grid(alpha=0.25)
            continue

        best = min(passing, key=lambda item: (item["cycles"], item["mul_per_feature"]))
        best_by_layer[layer_name] = best
        xs = [entry["mul_per_feature"] for entry in passing]
        ys = [entry["cycles"] for entry in passing]
        ax.scatter(xs, ys, s=85, c=colors[layer_name], alpha=0.85)
        ax.scatter([best["mul_per_feature"]], [best["cycles"]], s=180, c="#ee9b00", edgecolors="#1f2833", linewidths=1.1, zorder=3)

        for entry in passing:
            ax.annotate(f"T={entry['temp']}", (entry["mul_per_feature"], entry["cycles"]), textcoords="offset points", xytext=(5, 4), fontsize=8, alpha=0.8)

        ax.set_title(layer_name)
        ax.set_xlabel("mul_per_feature")
        ax.grid(alpha=0.25)

    axes[0].set_ylabel("Cycles")
    fig.suptitle("Per-layer sweep: cycles vs mul_per_feature")
    fig.tight_layout()
    fig.savefig(output_path, dpi=160)
    summary_path.write_text(json.dumps(best_by_layer, indent=2), encoding="utf-8")
    print(f"[plot] saved {output_path}")
    print(f"[best] saved {summary_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
