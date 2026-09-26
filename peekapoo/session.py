# session.py
"""
Turns the per-frame results of one toilet visit into a single session record.

This is the on-device version of what PHIND computed in the Django view
(calculate_class_percentages, calculate_seven_class_percentages,
calculate_times, the weighted-average Bristol curve). Doing it on the edge
means the cloud only ever receives this small record.
"""

import time
from collections import Counter

import numpy as np

from .classifiers import BRISTOL_CLASSES, CONDITION_CLASSES
from .gas_baseline import session_gas_features
from .urine import hydration_score

BS_WEIGHTS = np.arange(1, 8, dtype=np.float32)


class SessionAccumulator:
    def __init__(self, user, gas_channels, ambient_gas):
        self.user = user
        self.gas_channels = gas_channels
        self.ambient_gas = list(ambient_gas)
        self.start_ts = time.time()
        self.frames = []          # small dicts only, never pixels
        self.gas = []

    def add_frame(self, ts, result):
        self.frames.append({"ts": ts, **result})

    def add_gas(self, sample):
        self.gas.append(sample)

    def finish(self):
        end_ts = time.time()
        states = Counter(f["state"] for f in self.frames)
        sto = [f for f in self.frames if f["state"] == "STO"]
        uri = [f for f in self.frames if f.get("urine_level")]

        rec = {
            "user": self.user,
            "start_ts": self.start_ts,
            "end_ts": end_ts,
            "total_time_s": round(end_ts - self.start_ts, 1),
            "n_frames": len(self.frames),
            "state_counts": dict(states),
            "color_correction": dict(Counter(f.get("cc", "none") for f in self.frames)),
            "has_stool": bool(sto),
            "has_urine": bool(uri),
        }

        if sto:
            # PHIND: defecation time = span between first and last STO frame
            rec["defecation_time_s"] = round(sto[-1]["ts"] - sto[0]["ts"], 1)
            bp = np.mean([[f["bristol_probs"][c] for c in BRISTOL_CLASSES] for f in sto], axis=0)
            cp = np.mean([[f["condition_probs"][c] for c in CONDITION_CLASSES] for f in sto], axis=0)
            rec["bristol_probs"] = {c: round(float(v), 4) for c, v in zip(BRISTOL_CLASSES, bp)}
            rec["bristol_type"] = int(np.argmax(bp)) + 1
            rec["bristol_mean"] = round(float(bp @ BS_WEIGHTS / bp.sum()), 2)
            rec["condition_probs"] = {c: round(float(v), 4) for c, v in zip(CONDITION_CLASSES, cp)}
            rec["condition"] = CONDITION_CLASSES[int(np.argmax(cp))]

        if uri:
            level = int(round(float(np.median([f["urine_level"] for f in uri]))))
            rec["urine_level"] = level
            rec["hydration_score"] = hydration_score(level)

        rec["gas_features"] = session_gas_features(self.ambient_gas, self.gas, self.gas_channels)
        return rec
