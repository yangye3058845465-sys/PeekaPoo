# gas_baseline.py
"""
Module 3 - gas signal processing with a personal baseline.

Per session we compute one feature per channel: the rise of the occupied-period
signal above the ambient level measured just before the visit (this cancels
slow room drift and sensor ageing). Each user's history of these features is
the baseline. A new day is scored with robust z-scores (median / MAD) against
the previous `window_days` days of that same user.

Two-stage alert logic from the proposal:
  1. deviation score - today's z-score for a channel exceeds `z_threshold`
  2. persistence     - that happens on `persistence_days` consecutive days
A one-day spike (diet) never alerts on its own.
"""

import numpy as np


def session_gas_features(ambient_samples, occupied_samples, channels):
    """Rise above ambient per channel, using the 90th percentile of the occupied period."""
    if not occupied_samples:
        return {}
    occ = np.asarray(occupied_samples, dtype=np.float32)
    amb = np.asarray(ambient_samples, dtype=np.float32) if ambient_samples else occ[:1]
    rise = np.percentile(occ, 90, axis=0) - np.median(amb, axis=0)
    return {ch: float(v) for ch, v in zip(channels, rise)}


def robust_z(value, history):
    h = np.asarray(history, dtype=np.float32)
    med = np.median(h)
    mad = np.median(np.abs(h - med)) * 1.4826
    # floor the spread so a very stable history does not turn noise into huge z
    scale = max(mad, 0.05 * abs(med), 1.0)
    return float((value - med) / scale)


class GasBaseline:
    def __init__(self, channels, window_days=14, min_days=5, z_threshold=3.0, persistence_days=3):
        self.channels = channels
        self.window_days = window_days
        self.min_days = min_days
        self.z_threshold = z_threshold
        self.persistence_days = persistence_days

    def daily_z(self, daily_features):
        """
        daily_features: list of (date_str, {channel: value}) sorted by date, one
        entry per day (the day's mean session feature). Returns a list of
        (date_str, {channel: z or None}) where None means "not enough history".
        """
        out = []
        for i, (day, feats) in enumerate(daily_features):
            past = daily_features[max(0, i - self.window_days):i]
            zs = {}
            for ch in self.channels:
                hist = [f[ch] for _, f in past if ch in f]
                if ch not in feats or len(hist) < self.min_days:
                    zs[ch] = None
                else:
                    zs[ch] = robust_z(feats[ch], hist)
            out.append((day, zs))
        return out

    def evaluate(self, daily_features):
        """
        Returns a summary for the most recent day:
            {"today_z": {...}, "streak": {ch: n_days}, "alerts": [ch, ...], "warming_up": bool}
        """
        zs = self.daily_z(daily_features)
        if not zs:
            return {"today_z": {}, "streak": {}, "alerts": [], "warming_up": True}
        streak = {}
        for ch in self.channels:
            n = 0
            for _, z in reversed(zs):
                if z.get(ch) is not None and z[ch] > self.z_threshold:
                    n += 1
                else:
                    break
            streak[ch] = n
        today = zs[-1][1]
        return {
            "today_z": today,
            "streak": streak,
            "alerts": [ch for ch, n in streak.items() if n >= self.persistence_days],
            "warming_up": all(v is None for v in today.values()),
        }
