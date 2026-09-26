# urine.py
"""
Urine colour -> Hydration Score (new in PeekaPoo, PHIND only detected "URI").

After colour correction, the median colour of the bowl-water ROI is matched to
an 8-level urine colour chart (level 1 = pale/well hydrated, 8 = dark/dehydrated)
by nearest distance in CIELAB. Toilet water dilutes urine, so the chart RGB
values below are STARTING POINTS and must be recalibrated on our own bowl
(capture known dilutions and replace URINE_CHART_RGB).
"""

import numpy as np

from .color_correction import srgb_to_linear

# Approximate 8-level urine colour chart (sRGB), pale -> dark.
URINE_CHART_RGB = np.array([
    [250, 250, 225],
    [250, 245, 190],
    [248, 236, 150],
    [245, 222, 110],
    [238, 205, 75],
    [222, 180, 50],
    [200, 150, 40],
    [170, 115, 35],
], dtype=np.float32)

# Level -> Hydration Score (0-100)
LEVEL_SCORE = {1: 100, 2: 95, 3: 80, 4: 65, 5: 50, 6: 35, 7: 20, 8: 10}


def srgb_to_lab(rgb):
    lin = srgb_to_linear(rgb)
    M = np.array([[0.4124, 0.3576, 0.1805],
                  [0.2126, 0.7152, 0.0722],
                  [0.0193, 0.1192, 0.9505]], dtype=np.float32)
    xyz = lin @ M.T / np.array([0.95047, 1.0, 1.08883], dtype=np.float32)
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    L = 116 * f[..., 1] - 16
    a = 500 * (f[..., 0] - f[..., 1])
    b = 200 * (f[..., 1] - f[..., 2])
    return np.stack([L, a, b], axis=-1)


CHART_LAB = srgb_to_lab(URINE_CHART_RGB)


def urine_level(frame, roi):
    x, y, w, h = roi
    patch = frame[y:y + h, x:x + w].reshape(-1, 3).astype(np.float32)
    median = np.median(patch, axis=0)
    lab = srgb_to_lab(median[None])[0]
    d = np.linalg.norm(CHART_LAB - lab, axis=1)
    level = int(np.argmin(d)) + 1
    return level, float(d.min())


def hydration_score(level):
    return LEVEL_SCORE[level]
