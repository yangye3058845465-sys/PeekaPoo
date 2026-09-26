import numpy as np


def session_gas_features(ambient_samples, occupied_samples, channels):
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
