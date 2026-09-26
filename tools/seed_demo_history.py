# seed_demo_history.py
"""
Writes synthetic past sessions into the local SQLite store so the personal
baseline, triage rules and LLM advice can be demonstrated without waiting
two weeks. DEMO DATA ONLY - clearly tagged with "synthetic": true.

    python tools/seed_demo_history.py --user user1 --days 14
    python tools/seed_demo_history.py --user user2 --days 14 --scenario constipation_gas
"""

import argparse
import random
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from peekapoo.classifiers import BRISTOL_CLASSES, CONDITION_CLASSES  # noqa: E402
from peekapoo.config import CONFIG  # noqa: E402
from peekapoo.scoring import digestive_score  # noqa: E402
from peekapoo.store import SessionStore  # noqa: E402
from peekapoo.urine import hydration_score  # noqa: E402


def peaked(n, idx, sharp=0.7):
    p = [(1 - sharp) / (n - 1)] * n
    p[idx] = sharp
    return p


def fake_session(user, ts, bs_type, urine_lvl, gas_scale):
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
        "gas_features": {ch: (60.0 * gas_scale if i < 3 else 10.0) + random.gauss(0, 3)
                         for i, ch in enumerate(CONFIG.gas_channels)},
    }
    rec["digestive_score"] = digestive_score(rec["bristol_probs"])
    return rec


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--user", default=CONFIG.default_user)
    ap.add_argument("--days", type=int, default=14)
    ap.add_argument("--scenario", choices=["healthy", "constipation_gas"], default="healthy")
    args = ap.parse_args()

    random.seed(0)
    store = SessionStore(CONFIG.db_path)
    now = time.time()
    for d in range(args.days, 0, -1):
        ts = now - d * 86400
        late = args.scenario == "constipation_gas" and d <= 3
        bs = random.choice([1, 2]) if late else random.choice([3, 4, 4, 5])
        lvl = random.choice([5, 6]) if late else random.choice([2, 3, 3, 4])
        gas = 3.0 if late else random.uniform(0.9, 1.1)
        store.add(fake_session(args.user, ts, bs, lvl, gas))
    print(f"seeded {args.days} synthetic days for {args.user} ({args.scenario}) into {CONFIG.db_path}")


if __name__ == "__main__":
    main()
