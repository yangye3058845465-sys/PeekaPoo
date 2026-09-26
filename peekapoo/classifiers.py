import json
from pathlib import Path

import numpy as np
from PIL import Image

STATE_CLASSES = ["CLE", "STO", "TPI", "URI"]  # clean / stool / toilet paper / urine
BRISTOL_CLASSES = ["BS1", "BS2", "BS3", "BS4", "BS5", "BS6", "BS7"]
CONDITION_CLASSES = ["Constipation", "Normal", "Diarrhea"]

TASKS = {
    "state": STATE_CLASSES,
    "bristol": BRISTOL_CLASSES,
    "condition": CONDITION_CLASSES,
}

IMAGENET_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
IMAGENET_STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)


def preprocess(frame, size=224):
    img = Image.fromarray(frame).resize((size, size), Image.BILINEAR)
    x = np.asarray(img, dtype=np.float32) / 255.0
    x = (x - IMAGENET_MEAN) / IMAGENET_STD
    return np.ascontiguousarray(x.transpose(2, 0, 1)[None])


def softmax(z):
    z = z - z.max()
    e = np.exp(z)
    return e / e.sum()


def build_efficientnet(num_classes, pretrained=False, dropout=0.5):
    import torch.nn as nn
    from torchvision import models
    weights = models.EfficientNet_B0_Weights.IMAGENET1K_V1 if pretrained else None
    model = models.efficientnet_b0(weights=weights)
    in_features = model.classifier[1].in_features
    model.classifier = nn.Sequential(nn.Dropout(p=dropout), nn.Linear(in_features, num_classes))
    return model


class TorchClassifier:
    def __init__(self, weights_path, classes):
        import torch
        self.torch = torch
        self.classes = classes
        self.model = build_efficientnet(len(classes))
        state = torch.load(weights_path, map_location="cpu", weights_only=True)
        self.model.load_state_dict(state)
        self.model.eval()

    def logits(self, x):
        with self.torch.no_grad():
            return self.model(self.torch.from_numpy(x))[0].numpy()


class OMClassifier:
    def __init__(self, om_path, classes, device_id=0):
        from ais_bench.infer.interface import InferSession
        self.session = InferSession(device_id, str(om_path))
        self.classes = classes

    def logits(self, x):
        return np.asarray(self.session.infer([x])[0]).reshape(-1)


class RandomClassifier:
    def __init__(self, classes, seed=0):
        self.classes = classes
        self.rng = np.random.default_rng(seed)

    def logits(self, x):
        return self.rng.normal(size=len(self.classes)).astype(np.float32)


def load_classifier(task, backend, model_dir, device_id=0, allow_placeholder=True):
    classes = TASKS[task]
    model_dir = Path(model_dir)
    path = model_dir / (f"{task}.om" if backend == "om" else f"{task}.pt")
    meta = model_dir / f"{task}.json"
    if meta.exists():
        saved = json.loads(meta.read_text())["classes"]
        if saved != classes:
            raise ValueError(f"{meta} lists classes {saved}, code expects {classes}")
    if not path.exists():
        if not allow_placeholder:
            raise FileNotFoundError(path)
        print(f"[classifiers] WARNING: {path} not found - using a RANDOM placeholder for '{task}'")
        return RandomClassifier(classes)
    if backend == "om":
        return OMClassifier(path, classes, device_id)
    return TorchClassifier(path, classes)


class GutAnalyzer:
    def __init__(self, backend="torch", model_dir="models", device_id=0):
        self.state = load_classifier("state", backend, model_dir, device_id)
        self.bristol = load_classifier("bristol", backend, model_dir, device_id)
        self.condition = load_classifier("condition", backend, model_dir, device_id)

    @staticmethod
    def _probs(clf, x):
        p = softmax(clf.logits(x))
        return {c: float(v) for c, v in zip(clf.classes, p)}

    def analyze(self, frame):
        x = preprocess(frame)
        state_probs = self._probs(self.state, x)
        state = max(state_probs, key=state_probs.get)
        out = {"state": state, "state_probs": state_probs}
        if state == "STO":
            out["bristol_probs"] = self._probs(self.bristol, x)
            out["condition_probs"] = self._probs(self.condition, x)
        return out
