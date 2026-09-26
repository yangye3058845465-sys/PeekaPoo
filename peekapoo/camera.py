# camera.py
"""
Frame capture - replaces PHIND's image_capture.py.

PHIND called `libcamera-still` once per second and wrote every JPEG to disk,
then uploaded all of them to S3. PeekaPoo's privacy boundary forbids that:
frames are grabbed into memory, handed to the analyser, and dropped. Nothing
here ever writes an image file.
"""

import time
from pathlib import Path

import numpy as np
from PIL import Image


class Camera:
    """USB / MIPI camera on the Atlas 200I DK A2, read through OpenCV."""

    def __init__(self, index=0, width=640, height=480):
        import cv2
        self.cv2 = cv2
        self.cap = cv2.VideoCapture(index)
        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
        if not self.cap.isOpened():
            raise RuntimeError(f"Cannot open camera {index}")

    def grab(self):
        """Return one RGB frame as a uint8 HxWx3 array (in memory only)."""
        ok, bgr = self.cap.read()
        if not ok:
            return None
        return self.cv2.cvtColor(bgr, self.cv2.COLOR_BGR2RGB)

    def close(self):
        self.cap.release()


class ReplayCamera:
    """
    Replays sample images (e.g. the PHIND demo folders STO/, URI/, BS4/...)
    as if they came from the camera. For PC demos and regression tests only.
    """

    def __init__(self, image_paths, width=640, height=480):
        self.paths = [Path(p) for p in image_paths]
        self.size = (width, height)
        self.i = 0

    def grab(self):
        if not self.paths:
            return None
        p = self.paths[self.i % len(self.paths)]
        self.i += 1
        return np.asarray(Image.open(p).convert("RGB").resize(self.size))

    def close(self):
        pass


def capture_loop(camera, capturing_event, stop_event, on_frame, interval_s=1.0):
    """Same cadence as PHIND ImageCapture.run(): one frame per interval while capturing."""
    while not stop_event.is_set():
        if capturing_event.is_set():
            frame = camera.grab()
            if frame is not None:
                on_frame(frame, time.time())
                del frame  # the analyser keeps only numbers, never the pixels
        time.sleep(interval_s)
