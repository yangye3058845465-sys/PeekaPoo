import time
from pathlib import Path

import numpy as np
from PIL import Image


class Camera:
    def __init__(self, index=0, width=640, height=480):
        import cv2
        self.cv2 = cv2
        self.cap = cv2.VideoCapture(index)
        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
        if not self.cap.isOpened():
            raise RuntimeError(f"Cannot open camera {index}")

    def grab(self):
        ok, bgr = self.cap.read()
        if not ok:
            return None
        return self.cv2.cvtColor(bgr, self.cv2.COLOR_BGR2RGB)

    def close(self):
        self.cap.release()


class ReplayCamera:
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
    while not stop_event.is_set():
        if capturing_event.is_set():
            frame = camera.grab()
            if frame is not None:
                on_frame(frame, time.time())
                del frame
        time.sleep(interval_s)
