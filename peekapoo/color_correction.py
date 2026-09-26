# color_correction.py
"""
Module 1 - colour correction against the reference card in the camera view.

The camera is fixed, so the card patches always sit at known pixel boxes.
We fit a 3x3 colour-correction matrix (plus offset) mapping the measured patch
colours to their printed reference values, in linear RGB, and apply it to the
whole frame. If the card is unreadable (occluded, too dark) we fall back to
gray-world white balance so the pipeline still produces a usable frame.
"""

import numpy as np


def srgb_to_linear(x):
    x = np.asarray(x, dtype=np.float32) / 255.0
    return np.where(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(x):
    x = np.clip(x, 0.0, 1.0)
    y = np.where(x <= 0.0031308, x * 12.92, 1.055 * np.power(x, 1 / 2.4) - 0.055)
    return (y * 255.0 + 0.5).astype(np.uint8)


def measure_patches(frame, boxes):
    """Mean sRGB value inside each (x, y, w, h) box."""
    return np.array([frame[y:y + h, x:x + w].reshape(-1, 3).mean(axis=0) for x, y, w, h in boxes],
                    dtype=np.float32)


def fit_ccm(measured_srgb, reference_srgb):
    """Least-squares 4x3 matrix M so that [rgb_lin, 1] @ M ~= ref_lin."""
    m = srgb_to_linear(measured_srgb)
    r = srgb_to_linear(reference_srgb)
    A = np.hstack([m, np.ones((len(m), 1), dtype=np.float32)])
    M, *_ = np.linalg.lstsq(A, r, rcond=None)
    return M


def card_is_readable(measured_srgb, min_brightness=25.0, min_spread=40.0):
    """Reject obviously bad readings (lights off, card covered)."""
    lum = measured_srgb.mean(axis=1)
    return lum.max() >= min_brightness and (lum.max() - lum.min()) >= min_spread


def gray_world(frame):
    lin = srgb_to_linear(frame)
    means = lin.reshape(-1, 3).mean(axis=0) + 1e-6
    return linear_to_srgb(lin * (means.mean() / means))


def correct_frame(frame, boxes, reference_rgb):
    """
    Returns (corrected_frame, method) where method is "card" or "gray_world".
    """
    measured = measure_patches(frame, boxes)
    if not card_is_readable(measured):
        return gray_world(frame), "gray_world"
    M = fit_ccm(measured, np.asarray(reference_rgb, dtype=np.float32))
    lin = srgb_to_linear(frame).reshape(-1, 3)
    lin = np.hstack([lin, np.ones((len(lin), 1), dtype=np.float32)]) @ M
    return linear_to_srgb(lin).reshape(frame.shape), "card"
