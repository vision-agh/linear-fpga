from __future__ import annotations

import json
import sys

from mlp_runtime_lib import load_config, run_mlp_testbench


def main() -> int:
    config = load_config()
    result = run_mlp_testbench(config)
    payload = {
        "layers": config["layers"],
        "metrics": result["metrics"],
        "weights": result["weights"],
    }
    print(json.dumps(payload, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
