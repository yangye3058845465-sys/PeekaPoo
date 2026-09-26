import json
import queue
import random
import threading
import time


class SensorEvent:
    __slots__ = ("kind", "value", "ts", "raw")

    def __init__(self, kind, value, ts, raw=None):
        self.kind = kind
        self.value = value
        self.ts = ts
        self.raw = raw

    def __repr__(self):
        return f"SensorEvent({self.kind}, {self.value})"


class SensorLink:
    def __init__(self, port, baud, stop_event):
        import serial
        self.ser = serial.Serial(port, baud, timeout=1)
        self.stop_event = stop_event
        self.events = queue.Queue()

    def send(self, cmd):
        self.ser.write((json.dumps(cmd) + "\n").encode())

    def run(self):
        while not self.stop_event.is_set():
            line = self.ser.readline().decode(errors="ignore").strip()
            if not line:
                continue
            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                print(f"[sensor_link] bad line: {line!r}")
                continue
            self.events.put(SensorEvent(msg.get("t"), msg.get("v"), time.time(), msg))

    def close(self):
        self.ser.close()


class SimulatedSensorLink:
    def __init__(self, stop_event, n_channels=8, session_s=12, gas_boost=1.0,
                 user_button=None, speed=1.0):
        self.stop_event = stop_event
        self.n = n_channels
        self.session_s = session_s
        self.gas_boost = gas_boost
        self.user_button = user_button
        self.speed = speed
        self.events = queue.Queue()

    def send(self, cmd):
        print(f"[sim-hi3861] <- {cmd}")

    def _gas(self, level):
        base = [200 + 10 * i for i in range(self.n)]
        out = []
        for i, b in enumerate(base):
            rise = 60 * level if i < 3 else 10 * min(level, 1)
            out.append(int(b + rise + random.gauss(0, 4)))
        return out

    def _emit(self, kind, value):
        self.events.put(SensorEvent(kind, value, time.time(), {"t": kind, "v": value}))

    def _sleep(self, s):
        time.sleep(s / self.speed)

    def run(self):
        for _ in range(3):
            self._emit("gas", self._gas(0))
            self._sleep(0.5)
        if self.user_button:
            self._emit("uid", self.user_button)
        self._emit("occ", 1)
        t0 = time.time()
        while (time.time() - t0) * self.speed < self.session_s and not self.stop_event.is_set():
            self._emit("gas", self._gas(self.gas_boost))
            self._sleep(0.5)
        self._emit("occ", 0)

    def close(self):
        pass
