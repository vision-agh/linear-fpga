from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np

import convert
import loader


def _load_input_array(path: str | Path) -> np.ndarray:
    input_path = Path(path)
    suffix = input_path.suffix.lower()

    if suffix == ".npy":
        return np.load(input_path)
    if suffix == ".npz":
        archive = np.load(input_path)
        if not archive.files:
            raise ValueError(f"No arrays found in {input_path}")
        return archive[archive.files[0]]
    if suffix in {".txt", ".csv"}:
        return np.loadtxt(input_path, delimiter="," if suffix == ".csv" else None, dtype=np.int32)

    raise ValueError(f"Unsupported input format: {input_path.suffix}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Export notebook-aligned FPGA parameters and optional integer traces."
    )
    parser.add_argument(
        "--params",
        default="quantized_mlp_params.npz",
        help="Path to the notebook-exported NPZ file.",
    )
    parser.add_argument(
        "--output-dir",
        default="../HW/generated",
        help="Directory where .mem/.svh/.json outputs will be written.",
    )
    parser.add_argument(
        "--split",
        type=int,
        default=1,
        help="How many chunks to split each neuron row into inside *_weights.mem.",
    )
    parser.add_argument(
        "--input",
        help="Optional .npy/.npz/.txt/.csv input image to trace through the integer pipeline.",
    )
    parser.add_argument(
        "--trace-stem",
        default="sample",
        help="Filename stem to use for optional trace outputs.",
    )
    args = parser.parse_args()

    model = loader.Loader(args.params)
    export_dir = convert.export_model(model, args.output_dir, split=args.split)

    if args.input:
        input_array = _load_input_array(args.input)
        trace = model.run_integer_trace(input_array)
        convert.save_trace(trace, export_dir, stem=args.trace_stem)
        print(f"[trace] saved integer pipeline trace for {args.input} -> {export_dir}")

    print(f"[export] saved notebook-aligned bundle -> {export_dir}")


if __name__ == "__main__":
    main()
