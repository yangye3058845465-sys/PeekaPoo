import argparse
import sys
from pathlib import Path

import torch

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from peekapoo.classifiers import TASKS, build_efficientnet  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--task", choices=list(TASKS), required=True)
    ap.add_argument("--model-dir", default=str(Path(__file__).resolve().parent.parent / "models"))
    args = ap.parse_args()

    model_dir = Path(args.model_dir)
    model = build_efficientnet(len(TASKS[args.task]))
    model.load_state_dict(torch.load(model_dir / f"{args.task}.pt", map_location="cpu", weights_only=True))
    model.eval()

    dummy = torch.randn(1, 3, 224, 224)
    out = model_dir / f"{args.task}.onnx"
    torch.onnx.export(model, dummy, str(out), input_names=["image"], output_names=["logits"],
                      opset_version=11, do_constant_folding=True)
    print(f"exported {out}")


if __name__ == "__main__":
    main()
