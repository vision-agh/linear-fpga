from __future__ import annotations

import json
import sys
from pathlib import Path

from mlp_runtime_lib import CONFIG_PATH, load_config, sweep_configs, sweep_layers_independently


def main() -> int:
    config = load_config()
    layer_results = sweep_layers_independently(config)
    output_path = Path(config["runtime_dir"]) / "mlp_layer_sweeps.json"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(layer_results, indent=2), encoding="utf-8")
    print(json.dumps(layer_results, indent=2))
    print(f"[sweep] saved {output_path}")
    print(f"[config] {CONFIG_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
