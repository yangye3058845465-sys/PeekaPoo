import argparse
import json
import os
import random
import sys
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from PIL import Image
from torch.utils.data import DataLoader, Dataset
from torchvision import transforms

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from peekapoo.classifiers import TASKS, build_efficientnet  # noqa: E402

MEAN, STD = [0.485, 0.456, 0.406], [0.229, 0.224, 0.225]
IMG_EXT = {".jpg", ".jpeg", ".png", ".bmp"}

BRISTOL_TO_CONDITION = {"BS1": "Constipation", "BS2": "Constipation", "BS3": "Normal", "BS4": "Normal",
                        "BS5": "Normal", "BS6": "Diarrhea", "BS7": "Diarrhea"}
CLASSN_TO_CONDITION = {"Class1": "Constipation", "Class2": "Normal", "Class3": "Diarrhea"}


def train_tf(strong=False):
    j = 0.3 if strong else 0.15
    return transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.RandomHorizontalFlip(),
        transforms.RandomVerticalFlip(),
        transforms.RandomRotation(45 if strong else 20),
        transforms.RandomAffine(degrees=0, translate=(0.1, 0.1)),
        transforms.ColorJitter(brightness=j, contrast=j, saturation=j / 2, hue=0.02),
        transforms.ToTensor(),
        transforms.Normalize(MEAN, STD),
        transforms.RandomErasing(p=0.25),
    ])


EVAL_TF = transforms.Compose([transforms.Resize((224, 224)), transforms.ToTensor(), transforms.Normalize(MEAN, STD)])


def collect_samples(data_dir, task, from_bristol):
    classes = TASKS[task]
    samples = []
    for folder in sorted(os.listdir(data_dir)):
        path = Path(data_dir) / folder
        if not path.is_dir():
            continue
        if task == "condition":
            name = (BRISTOL_TO_CONDITION if from_bristol else CLASSN_TO_CONDITION).get(folder, folder)
        else:
            name = folder
        if name not in classes:
            print(f"skip folder {folder!r} (not a {task} class)")
            continue
        for f in sorted(path.iterdir()):
            if f.suffix.lower() in IMG_EXT:
                samples.append((str(f), classes.index(name)))
    return samples, classes


def stratified_split(samples, val_frac, seed):
    rng = random.Random(seed)
    by_cls = {}
    for s in samples:
        by_cls.setdefault(s[1], []).append(s)
    train, val = [], []
    for items in by_cls.values():
        rng.shuffle(items)
        k = max(1, int(round(len(items) * val_frac)))
        val += items[:k]
        train += items[k:]
    return train, val


class ImageList(Dataset):
    def __init__(self, samples, tf, strong_tf=None, strong_classes=()):
        self.samples, self.tf, self.strong_tf, self.strong_classes = samples, tf, strong_tf, set(strong_classes)

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, i):
        path, y = self.samples[i]
        img = Image.open(path).convert("RGB")
        tf = self.strong_tf if (self.strong_tf and y in self.strong_classes) else self.tf
        return tf(img), y


class FocalLoss(nn.Module):
    def __init__(self, gamma=2.0, weight=None):
        super().__init__()
        self.gamma, self.weight = gamma, weight

    def forward(self, logits, y):
        ce = F.cross_entropy(logits, y, weight=self.weight, reduction="none")
        pt = torch.exp(-F.cross_entropy(logits, y, reduction="none"))
        return ((1 - pt) ** self.gamma * ce).mean()


def confusion(y_true, y_pred, n):
    cm = np.zeros((n, n), dtype=int)
    for t, p in zip(y_true, y_pred):
        cm[t, p] += 1
    return cm


def report(cm, classes):
    lines = [f"{'class':>14} {'prec':>6} {'recall':>6} {'f1':>6} {'n':>5}"]
    for i, c in enumerate(classes):
        tp = cm[i, i]
        prec = tp / max(cm[:, i].sum(), 1)
        rec = tp / max(cm[i].sum(), 1)
        f1 = 2 * prec * rec / max(prec + rec, 1e-9)
        lines.append(f"{c:>14} {prec:6.3f} {rec:6.3f} {f1:6.3f} {cm[i].sum():5d}")
    lines.append(f"accuracy {np.trace(cm) / max(cm.sum(), 1):.4f}")
    return "\n".join(lines)


def evaluate(model, loader, device):
    model.eval()
    ys, ps = [], []
    with torch.no_grad():
        for x, y in loader:
            ps += model(x.to(device)).argmax(1).cpu().tolist()
            ys += y.tolist()
    return ys, ps


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--task", choices=list(TASKS), required=True)
    ap.add_argument("--data-dir", required=True)
    ap.add_argument("--from-bristol", action="store_true", help="derive condition labels from BS1..BS7 folders")
    ap.add_argument("--out-dir", default=str(Path(__file__).resolve().parent.parent / "models"))
    ap.add_argument("--epochs", type=int, default=50)
    ap.add_argument("--batch-size", type=int, default=32)
    ap.add_argument("--lr", type=float, default=3e-4)
    ap.add_argument("--patience", type=int, default=10)
    ap.add_argument("--val-frac", type=float, default=0.2)
    ap.add_argument("--loss", choices=["ce", "focal"], default="focal")
    ap.add_argument("--no-pretrained", action="store_true")
    ap.add_argument("--workers", type=int, default=2)
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()

    torch.manual_seed(args.seed)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    samples, classes = collect_samples(args.data_dir, args.task, args.from_bristol)
    if not samples:
        sys.exit(f"no images found under {args.data_dir}")
    train_s, val_s = stratified_split(samples, args.val_frac, args.seed)
    counts = np.bincount([y for _, y in train_s], minlength=len(classes))
    print(f"task={args.task} classes={classes} train={len(train_s)} val={len(val_s)} per-class={counts.tolist()}")

    strong = {"state": ["URI"], "condition": ["Constipation"]}.get(args.task, [])
    train_ds = ImageList(train_s, train_tf(False), train_tf(True), [classes.index(c) for c in strong])
    val_ds = ImageList(val_s, EVAL_TF)
    train_dl = DataLoader(train_ds, args.batch_size, shuffle=True, num_workers=args.workers)
    val_dl = DataLoader(val_ds, args.batch_size, shuffle=False, num_workers=args.workers)

    model = build_efficientnet(len(classes), pretrained=not args.no_pretrained).to(device)
    weight = torch.tensor(counts.sum() / np.maximum(counts, 1) / len(classes), dtype=torch.float32, device=device)
    criterion = FocalLoss(weight=weight) if args.loss == "focal" else nn.CrossEntropyLoss(weight=weight)
    optimizer = torch.optim.AdamW(model.parameters(), lr=args.lr, weight_decay=1e-4)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=args.epochs, eta_min=1e-6)

    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    best_acc, bad_epochs = -1.0, 0
    for epoch in range(1, args.epochs + 1):
        model.train()
        total, correct, loss_sum = 0, 0, 0.0
        for x, y in train_dl:
            x, y = x.to(device), y.to(device)
            optimizer.zero_grad()
            logits = model(x)
            loss = criterion(logits, y)
            loss.backward()
            optimizer.step()
            loss_sum += loss.item() * len(y)
            correct += (logits.argmax(1) == y).sum().item()
            total += len(y)
        scheduler.step()
        ys, ps = evaluate(model, val_dl, device)
        val_acc = float(np.mean(np.array(ys) == np.array(ps)))
        print(f"epoch {epoch:3d}  loss {loss_sum / total:.4f}  train_acc {correct / total:.4f}  val_acc {val_acc:.4f}")
        if val_acc > best_acc:
            best_acc, bad_epochs = val_acc, 0
            torch.save(model.state_dict(), out / f"{args.task}.pt")
            (out / f"{args.task}.json").write_text(json.dumps({"classes": classes, "val_acc": val_acc, "epoch": epoch}))
        else:
            bad_epochs += 1
            if bad_epochs >= args.patience:
                print(f"early stop at epoch {epoch}")
                break

    model.load_state_dict(torch.load(out / f"{args.task}.pt", map_location=device, weights_only=True))
    ys, ps = evaluate(model, val_dl, device)
    cm = confusion(ys, ps, len(classes))
    print("\nbest model on validation split\n" + report(cm, classes))
    print("confusion matrix (rows = true, cols = predicted)\n", cm)
    print(f"\nsaved {out / (args.task + '.pt')}")


if __name__ == "__main__":
    main()
