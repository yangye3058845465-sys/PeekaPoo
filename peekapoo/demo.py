import random
import time

from .classifiers import BRISTOL_CLASSES, CONDITION_CLASSES
from .config import CONFIG
from .scoring import digestive_score
from .urine import hydration_score

# healthy: all normal · ammonia_high: only NH3 rises for the last 3 days · constipation_gas: hard stools, dark urine, gases up
SCENARIOS = ("healthy", "ammonia_high", "constipation_gas")

STOOL_COLOURS = ("Brown", "Light brown", "Dark brown", "Green-ish")
STOOL_QUANTITIES = ("Small", "Medium", "Large")


def fake_stool_look(rng, bs_type):
    """Colour and amount for a synthetic visit (the vision models do not estimate these yet)."""
    if bs_type <= 2:
        return rng.choice(["Dark brown", "Dark brown", "Brown"]), rng.choice(["Small", "Small", "Medium"])
    colour = rng.choices(STOOL_COLOURS, weights=(70, 15, 10, 5))[0]
    return colour, rng.choices(STOOL_QUANTITIES, weights=(20, 60, 20))[0]


def peaked(n, idx, sharp=0.7):
    p = [(1 - sharp) / (n - 1)] * n
    p[idx] = sharp
    return p


def fake_session(user, ts, bs_type, urine_lvl, gas_scale, rng=random, nh3_scale=1.0):
    bp = peaked(7, bs_type - 1)
    cond = 0 if bs_type <= 2 else (2 if bs_type >= 6 else 1)
    cp = peaked(3, cond, 0.8)
    rec = {
        "user": user, "start_ts": ts, "end_ts": ts + 300, "total_time_s": 300.0,
        "n_frames": 300, "synthetic": True, "has_stool": True, "has_urine": True,
        "defecation_time_s": 120.0,
        "bristol_probs": dict(zip(BRISTOL_CLASSES, bp)), "bristol_type": bs_type,
        "bristol_mean": float(sum((i + 1) * v for i, v in enumerate(bp))),
        "condition_probs": dict(zip(CONDITION_CLASSES, cp)), "condition": CONDITION_CLASSES[cond],
        "urine_level": urine_lvl, "hydration_score": hydration_score(urine_lvl),
        "gas_features": {ch: (60.0 * gas_scale * (nh3_scale if ch == "NH3" else 1.0) if i < 3 else 10.0) + rng.gauss(0, 3)
                         for i, ch in enumerate(CONFIG.gas_channels)},
    }
    rec["digestive_score"] = digestive_score(rec["bristol_probs"])
    rec["stool_colour"], rec["stool_quantity"] = fake_stool_look(rng, bs_type)
    return rec


def seed_history(store, user, days=14, scenario="healthy", seed=0):
    """Write `days` synthetic daily visits for `user`; the last 3 days follow `scenario`."""
    rng = random.Random(seed)
    now = time.time()
    for d in range(days, 0, -1):
        late = d <= 3
        bad_gut = late and scenario == "constipation_gas"
        bs = rng.choice([1, 2]) if bad_gut else rng.choice([3, 4, 4, 5])
        lvl = rng.choice([5, 6]) if bad_gut else rng.choice([2, 3, 3, 4])
        gas = 3.0 if bad_gut else rng.uniform(0.9, 1.1)
        nh3 = rng.uniform(2.6, 3.1) if late and scenario == "ammonia_high" else 1.0
        store.add(fake_session(user, now - d * 86400, bs, lvl, gas, rng, nh3))
