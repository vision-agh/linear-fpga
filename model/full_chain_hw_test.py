from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import torch
import torchvision
from torchvision import transforms

from loader import Loader

try:
    from fc1_hw_test import write_mem, write_txt
except ModuleNotFoundError:
    from model.fc1_hw_test import write_mem, write_txt


def _raw_uint8_transform() -> transforms.Compose:
    return transforms.Compose(
        [
            transforms.ToTensor(),
            transforms.Lambda(lambda x: torch.clamp((x * 255.0).round(), 0, 255).to(torch.int32)),
            transforms.Lambda(lambda x: x.view(784).t()),
        ]
    )


def generate_full_chain_case(
    params_path: Path,
    output_dir: Path,
    sample_idx: int = 1,
    num_features: int = 2,
) -> dict[str, int | str | list[int]]:
    model = Loader(params_path)
    qtest = torchvision.datasets.MNIST("./data", train=False, download=True, transform=_raw_uint8_transform())

    raw_images: list[np.ndarray] = []
    img_quantized: list[np.ndarray] = []
    fc1_out: list[np.ndarray] = []
    relu1_out: list[np.ndarray] = []
    fc2_out: list[np.ndarray] = []
    relu2_out: list[np.ndarray] = []
    fc3_out: list[np.ndarray] = []
    labels: list[int] = []

    for feature_idx in range(num_features):
        raw_img, gt = qtest[sample_idx + feature_idx]
        trace = model.run_integer_trace(raw_img.numpy())
        raw_images.append(raw_img.numpy().reshape(-1))
        img_quantized.append(np.asarray(trace["img_quantized"]).reshape(-1))
        fc1_out.append(np.asarray(trace["fc1_out"]).reshape(-1))
        relu1_out.append(np.asarray(trace["relu1_out"]).reshape(-1))
        fc2_out.append(np.asarray(trace["fc2_out"]).reshape(-1))
        relu2_out.append(np.asarray(trace["relu2_out"]).reshape(-1))
        fc3_out.append(np.asarray(trace["fc3_out"]).reshape(-1))
        labels.append(int(gt))

    raw_images_arr = np.stack(raw_images, axis=0)
    img_quantized_arr = np.stack(img_quantized, axis=0)
    fc1_out_arr = np.stack(fc1_out, axis=0)
    relu1_out_arr = np.stack(relu1_out, axis=0)
    fc2_out_arr = np.stack(fc2_out, axis=0)
    relu2_out_arr = np.stack(relu2_out, axis=0)
    fc3_out_arr = np.stack(fc3_out, axis=0)

    output_dir.mkdir(parents=True, exist_ok=True)
    write_mem(output_dir / "mlp_test_input.mem", img_quantized_arr, bits=model.layers[0].input_bits)
    write_txt(output_dir / "mlp_test_input.txt", img_quantized_arr)
    write_txt(output_dir / "mlp_test_raw_pixels.txt", raw_images_arr)

    write_mem(output_dir / "mlp_test_fc1_truth.mem", fc1_out_arr, bits=model.layers[0].output_bits)
    write_mem(output_dir / "mlp_test_relu1_truth.mem", relu1_out_arr, bits=model.layers[0].output_bits)
    write_mem(output_dir / "mlp_test_fc2_truth.mem", fc2_out_arr, bits=model.layers[1].output_bits)
    write_mem(output_dir / "mlp_test_relu2_truth.mem", relu2_out_arr, bits=model.layers[1].output_bits)
    write_mem(output_dir / "mlp_test_fc3_truth.mem", fc3_out_arr, bits=model.layers[2].output_bits)

    write_txt(output_dir / "mlp_test_fc1_truth.txt", fc1_out_arr)
    write_txt(output_dir / "mlp_test_relu1_truth.txt", relu1_out_arr)
    write_txt(output_dir / "mlp_test_fc2_truth.txt", fc2_out_arr)
    write_txt(output_dir / "mlp_test_relu2_truth.txt", relu2_out_arr)
    write_txt(output_dir / "mlp_test_fc3_truth.txt", fc3_out_arr)

    metadata = {
        "sample_idx": int(sample_idx),
        "num_features": int(num_features),
        "mnist_labels": labels,
        "params_path": str(params_path.resolve()),
        "fc1_input_bits": int(model.layers[0].input_bits),
        "fc1_output_bits": int(model.layers[0].output_bits),
        "fc2_output_bits": int(model.layers[1].output_bits),
        "fc3_output_bits": int(model.layers[2].output_bits),
    }
    (output_dir / "mlp_test_metadata.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    return metadata


if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parent.parent
    output_dir = repo_root / "HW" / "generated"
    params_path = Path(__file__).resolve().parent / "quantized_mlp_params.npz"
    print(json.dumps(generate_full_chain_case(params_path, output_dir), indent=2))
