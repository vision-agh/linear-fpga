from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import torch
import torchvision
from torchvision import transforms

try:
    from convert import toHex
except ModuleNotFoundError:
    from model.convert import toHex


def compute_int_scale(scale: float, bits: int = 31) -> tuple[int, int]:
    inv = 1.0 / float(scale)
    shift = bits - int(np.floor(np.log2(inv))) - 1
    return int(round(inv * (2**shift))), shift


def quantize_fpga(
    x: np.ndarray,
    M: int,
    C: int,
    shift: int,
    zero_point: int,
    num_bits: int,
    signed: bool,
) -> np.ndarray:
    qmin = -(2 ** (num_bits - 1)) if signed else 0
    qmax = (2 ** (num_bits - 1) - 1) if signed else (2**num_bits - 1)
    acc = x.astype(np.int64) * int(M) - int(C)
    y = acc >> int(shift)
    return np.clip(y + int(zero_point), qmin, qmax).astype(np.int32)


def quant_linear_fpga(
    x: np.ndarray,
    x_zp: int,
    w_q: np.ndarray,
    b_q: np.ndarray,
    M_int: int,
    shift: int,
    out_zp: int,
    num_bits: int,
    signed: bool,
) -> np.ndarray:
    qmin = -(2 ** (num_bits - 1)) if signed else 0
    qmax = (2 ** (num_bits - 1) - 1) if signed else (2**num_bits - 1)

    x_c = x.astype(np.int64) - int(x_zp)
    acc = x_c @ w_q.astype(np.int64).T
    acc = acc + b_q.astype(np.int64)
    y = (acc * int(M_int)) >> int(shift)
    y = y + int(out_zp)
    return np.clip(y, qmin, qmax).astype(np.int32)


def write_mem(path: Path, values: np.ndarray, bits: int) -> None:
    flat = np.asarray(values).reshape(-1)
    path.write_text("\n".join(toHex(int(v), bits) for v in flat) + "\n", encoding="utf-8")


def write_txt(path: Path, values: np.ndarray) -> None:
    flat = np.asarray(values).reshape(-1)
    path.write_text("\n".join(str(int(v)) for v in flat) + "\n", encoding="utf-8")


def generate_fc1_case(
    params_path: Path,
    output_dir: Path,
    sample_idx: int = 1,
    num_features: int = 2,
    temp: int = 2,
    mul_per_feature: int = 8,
) -> dict[str, int | str]:
    quantized_params = np.load(params_path)
    signed = bool(np.asarray(quantized_params["signed"]).item())
    symmetric = bool(np.asarray(quantized_params["symmetric"]).item())

    if symmetric:
        qtf = transforms.Compose(
            [
                transforms.ToTensor(),
                transforms.Lambda(
                    lambda x: torch.clamp((x * 255.0 - 128.0).round(), -128, 127).to(torch.int32)
                ),
                transforms.Lambda(lambda x: x.view(784).t()),
            ]
        )
    else:
        qtf = transforms.Compose(
            [
                transforms.ToTensor(),
                transforms.Lambda(lambda x: torch.clamp((x * 255.0).round(), 0, 255).to(torch.int32)),
                transforms.Lambda(lambda x: x.view(784).t()),
            ]
        )

    qtest = torchvision.datasets.MNIST("./data", train=False, download=True, transform=qtf)

    quantized_images = []
    fc1_outputs = []
    labels = []

    in_s = float(quantized_params["in_s"])
    in_zp = int(round(float(quantized_params["in_zp"])))
    in_bits = int(quantized_params["in_bits"])
    offset = 127.5 if not symmetric else -0.5
    u_s_255 = in_s * 127.5
    input_M, input_shift = compute_int_scale(u_s_255, bits=31)
    input_C = int(round(offset * (2**input_shift) / u_s_255))

    fc1_w = quantized_params["fc1_w"] - quantized_params["fc1_w_zp"]
    fc1_b_q = quantized_params["fc1_b_q"]
    fc1_M = float(quantized_params["fc1_M"])
    fc1_zp = int(round(float(quantized_params["fc1_zp"])))
    fc1_bits = int(quantized_params["fc1_out_bits"])
    fc1_mul, fc1_shift = compute_int_scale(1 / fc1_M, bits=31)

    for feature_idx in range(num_features):
        img, gt = qtest[sample_idx + feature_idx]
        img = img.numpy()
        img_quantize = quantize_fpga(img, input_M, input_C, input_shift, in_zp, in_bits, signed)
        fc1_out = quant_linear_fpga(
            img_quantize,
            in_zp,
            fc1_w,
            fc1_b_q,
            fc1_mul,
            fc1_shift,
            fc1_zp,
            fc1_bits,
            signed,
        )
        quantized_images.append(img_quantize.reshape(-1))
        fc1_outputs.append(fc1_out.reshape(-1))
        labels.append(int(gt))

    quantized_images_arr = np.stack(quantized_images, axis=0)
    fc1_outputs_arr = np.stack(fc1_outputs, axis=0)

    output_dir.mkdir(parents=True, exist_ok=True)
    write_mem(output_dir / "fc1_test_input.mem", quantized_images_arr, in_bits)
    write_mem(output_dir / "fc1_test_truth.mem", fc1_outputs_arr, fc1_bits)
    write_txt(output_dir / "fc1_test_input.txt", quantized_images_arr)
    write_txt(output_dir / "fc1_test_truth.txt", fc1_outputs_arr)

    metadata = {
        "sample_idx": sample_idx,
        "num_features": int(num_features),
        "mnist_labels": labels,
        "temp": int(temp),
        "mul_per_feature": int(mul_per_feature),
        "input_bits": in_bits,
        "output_bits": fc1_bits,
        "input_zero_point": in_zp,
        "output_zero_point": fc1_zp,
        "input_multiplier": int(input_M),
        "input_shift": int(input_shift),
        "input_correction": int(input_C),
        "fc1_multiplier": int(fc1_mul),
        "fc1_shift": int(fc1_shift),
        "params_path": str(params_path.resolve()),
    }
    (output_dir / "fc1_test_metadata.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    return metadata


def compare_fc1_output(output_dir: Path) -> int:
    truth = np.loadtxt(output_dir / "fc1_test_truth.txt", dtype=np.int32)
    sim = np.loadtxt(output_dir / "fc1_sim_output.txt", dtype=np.int32)

    if truth.shape != sim.shape:
        raise ValueError(f"Shape mismatch: truth={truth.shape}, sim={sim.shape}")

    mismatch_idx = np.flatnonzero(truth != sim)
    report = {
        "total_values": int(truth.size),
        "mismatch_count": int(mismatch_idx.size),
        "matches": bool(mismatch_idx.size == 0),
    }
    if mismatch_idx.size:
        report["mismatches"] = [
            {"index": int(i), "truth": int(truth[i]), "sim": int(sim[i])}
            for i in mismatch_idx[:16]
        ]

    (output_dir / "fc1_compare_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    return int(mismatch_idx.size)


if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parent.parent
    generated_dir = repo_root / "HW" / "generated"
    params_path = Path(__file__).resolve().parent / "quantized_mlp_params.npz"

    metadata = generate_fc1_case(
        params_path,
        generated_dir,
        sample_idx=1,
        num_features=2,
        temp=2,
        mul_per_feature=8,
    )
    print(json.dumps(metadata, indent=2))
