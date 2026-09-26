import datetime as dt
from collections import defaultdict

import numpy as np

BS_SCORE = {1: 40, 2: 60, 3: 85, 4: 100, 5: 85, 6: 60, 7: 40}

LEVELS = ["normal", "watch", "consult"]


def digestive_score(bristol_probs):
    if not bristol_probs:
        return None
    p = np.array([bristol_probs[f"BS{i}"] for i in range(1, 8)], dtype=np.float32)
    s = np.array([BS_SCORE[i] for i in range(1, 8)], dtype=np.float32)
    return int(round(float(p @ s / p.sum())))


def day_of(ts):
    return dt.datetime.fromtimestamp(ts).strftime("%Y-%m-%d")


def daily_summary(sessions):
    days = defaultdict(list)
    for s in sessions:
        days[day_of(s["start_ts"])].append(s)
    out = []
    for day in sorted(days):
        ss = days[day]
        stool = [s for s in ss if s.get("has_stool")]
        urine = [s for s in ss if s.get("has_urine")]
        gas = defaultdict(list)
        for s in ss:
            for ch, v in s.get("gas_features", {}).items():
                gas[ch].append(v)
        out.append({
            "day": day,
            "visits": len(ss),
            "stool_visits": len(stool),
            "bristol_mean": round(float(np.mean([s["bristol_mean"] for s in stool])), 2) if stool else None,
            "digestive_score": int(np.mean([digestive_score(s["bristol_probs"]) for s in stool])) if stool else None,
            "hydration_score": int(np.mean([s["hydration_score"] for s in urine])) if urine else None,
            "gas": {ch: float(np.mean(v)) for ch, v in gas.items()},
        })
    return out


def _streak(days, pred):
    n = 0
    for d in reversed(days):
        if pred(d):
            n += 1
        else:
            break
    return n


def triage(days, gas_eval, today=None):
    flags = []
    stool_days = [d for d in days if d["bristol_mean"] is not None]

    hard = _streak(stool_days, lambda d: d["bristol_mean"] <= 2.5)
    if hard >= 7:
        flags.append({"code": "HARD_STOOL", "level": "consult", "detail": f"hard stools (Bristol 1-2) on {hard} recorded days in a row"})
    elif hard >= 3:
        flags.append({"code": "HARD_STOOL", "level": "watch", "detail": f"hard stools (Bristol 1-2) on {hard} recorded days in a row"})

    loose = _streak(stool_days, lambda d: d["bristol_mean"] >= 5.5)
    if loose >= 7:
        flags.append({"code": "LOOSE_STOOL", "level": "consult", "detail": f"loose stools (Bristol 6-7) on {loose} recorded days in a row"})
    elif loose >= 2:
        flags.append({"code": "LOOSE_STOOL", "level": "watch", "detail": f"loose stools (Bristol 6-7) on {loose} recorded days in a row"})

    hyd_days = [d for d in days if d["hydration_score"] is not None]
    dry = _streak(hyd_days, lambda d: d["hydration_score"] < 50)
    if dry >= 2:
        lvl = "consult" if loose >= 2 else "watch"
        flags.append({"code": "LOW_HYDRATION", "level": lvl, "detail": f"dark urine (low hydration) on {dry} days in a row"})

    if days:
        today = today or days[-1]["day"]
        last_stool = stool_days[-1]["day"] if stool_days else None
        if last_stool:
            gap = (dt.date.fromisoformat(today) - dt.date.fromisoformat(last_stool)).days
            if gap >= 3:
                flags.append({"code": "NO_BOWEL_MOVEMENT", "level": "watch", "detail": f"no bowel movement recorded for {gap} days"})

    for ch in gas_eval.get("alerts", []):
        n = gas_eval["streak"][ch]
        flags.append({"code": f"GAS_{ch}", "level": "consult",
                      "detail": f"{ch} level above your personal baseline for {n} days in a row"})

    level = max((f["level"] for f in flags), key=LEVELS.index, default="normal")
    return {"level": level, "flags": flags}
