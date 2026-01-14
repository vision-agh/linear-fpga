import matplotlib.pyplot as plt
from pathlib import Path


def load_numbers(path):
    with open(path, "r") as f:
        return [float(line.strip()) for line in f if line.strip()]


# Directory containing the files (use "." if current directory)
DATA_DIR = Path("../HW/")

# Discover available indices automatically
truth_files = sorted(DATA_DIR.glob("out_truth_*.mem"))

indices = sorted(
    int(f.stem.split("_")[-1]) for f in truth_files
)

for i in indices:
    truth_path = DATA_DIR / f"out_truth_{i}.mem"
    output_path = DATA_DIR / f"output_example_{i}.bin"

    if not truth_path.exists() or not output_path.exists():
        print(f"Skipping {i}: missing file")
        continue

    truth_vals = load_numbers(truth_path)
    output_vals = load_numbers(output_path)

    if len(truth_vals) != len(output_vals):
        raise ValueError(f"Length mismatch in file pair {i}")

    x = range(len(truth_vals))

    plt.figure()
    plt.plot(x, truth_vals, label="out_truth", linewidth=2)
    plt.plot(x, output_vals, label="output_example", linestyle="--")

    plt.title(f"Comparison for file index {i}")
    plt.xlabel("Line index")
    plt.ylabel("Value")
    plt.legend()
    plt.grid(True)

    plt.tight_layout()
    plt.show()
