from __future__ import annotations

import json
import sys
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from mlp_runtime_lib import CONFIG_PATH, load_config, run_mlp_testbench, run_python_simulation, run_ui_simulation, runtime_audit


REPO_ROOT = Path(__file__).resolve().parent.parent
UI_DIR = REPO_ROOT / "ui"


def save_config(config: dict) -> None:
    CONFIG_PATH.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")


class UiHandler(BaseHTTPRequestHandler):
    def _send_json(self, payload: dict, status: int = HTTPStatus.OK) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_file(self, path: Path, content_type: str) -> None:
        body = path.read_bytes()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path in {"/", "/index.html"}:
            return self._send_file(UI_DIR / "index.html", "text/html; charset=utf-8")
        if self.path == "/app.js":
            return self._send_file(UI_DIR / "app.js", "application/javascript; charset=utf-8")
        if self.path == "/style.css":
            return self._send_file(UI_DIR / "style.css", "text/css; charset=utf-8")
        if self.path == "/api/config":
            config = load_config()
            return self._send_json(
                {
                    "config_path": str(CONFIG_PATH),
                    "ui": {
                        "num_features": int(config["ui"]["num_features"]),
                        "port": int(config["ui"]["port"]),
                        "input_file": str(config["ui"]["input_file"]),
                        "output_file": str(config["ui"]["output_file"]),
                        "backends": ["verilog", "python"],
                    },
                    "layers": config["layers"],
                }
            )
        if self.path == "/api/audit":
            return self._send_json(runtime_audit())
        self.send_error(HTTPStatus.NOT_FOUND)

    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length", "0"))
        payload = json.loads(self.rfile.read(length) or b"{}")

        if self.path == "/api/self-test":
            config = load_config()
            result = run_mlp_testbench(config)
            return self._send_json({"metrics": result["metrics"], "weights": result["weights"], "stdout": result["stdout"]})

        if self.path == "/api/simulate":
            config = load_config()
            pixels = payload.get("pixels")
            backend = payload.get("backend", "verilog")
            if pixels is None:
                return self._send_json({"error": "Missing pixels"}, status=HTTPStatus.BAD_REQUEST)
            if backend == "python":
                result = run_python_simulation(config, pixels)
            else:
                result = run_ui_simulation(config, pixels)
            return self._send_json(result)

        if self.path == "/api/config":
            config = load_config()
            layers = payload.get("layers")
            if not isinstance(layers, dict):
                return self._send_json({"error": "Missing layers"}, status=HTTPStatus.BAD_REQUEST)

            for layer_name in ("fc1", "fc2", "fc3"):
                if layer_name not in layers:
                    continue
                layer_payload = layers[layer_name]
                if not isinstance(layer_payload, dict):
                    return self._send_json({"error": f"Invalid layer payload for {layer_name}"}, status=HTTPStatus.BAD_REQUEST)
                if "temp" in layer_payload:
                    config["layers"][layer_name]["temp"] = int(layer_payload["temp"])
                if "mul_per_feature" in layer_payload:
                    config["layers"][layer_name]["mul_per_feature"] = int(layer_payload["mul_per_feature"])

            save_config(config)
            return self._send_json(
                {
                    "ok": True,
                    "config_path": str(CONFIG_PATH),
                    "layers": config["layers"],
                }
            )

        self.send_error(HTTPStatus.NOT_FOUND)


def main() -> int:
    config = load_config()
    port = int(config["ui"]["port"])
    server = ThreadingHTTPServer(("127.0.0.1", port), UiHandler)
    print(f"[ui] serving {UI_DIR} on http://127.0.0.1:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
