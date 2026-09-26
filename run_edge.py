import argparse
import collections
import glob
import signal
import threading
from pathlib import Path

from peekapoo.camera import Camera, ReplayCamera, capture_loop
from peekapoo.classifiers import GutAnalyzer
from peekapoo.cloud_sync import CloudSync
from peekapoo.color_correction import correct_frame
from peekapoo.config import CONFIG, ROOT
from peekapoo.gas_baseline import GasBaseline
from peekapoo.llm_advisor import GutAdvisor
from peekapoo.scoring import daily_summary, digestive_score, triage
from peekapoo.sensor_link import SensorLink, SimulatedSensorLink
from peekapoo.session import SessionAccumulator
from peekapoo.store import SessionStore
from peekapoo.urine import urine_level


class EdgeNode:
    def __init__(self, cfg, link, camera, stop_event, once=False):
        self.cfg = cfg
        self.link = link
        self.camera = camera
        self.stop_event = stop_event
        self.once = once
        self.capturing_event = threading.Event()
        self.lock = threading.Lock()
        self.session = None
        self.user = cfg.default_user
        self.ambient = collections.deque(maxlen=10)

        self.analyzer = GutAnalyzer(cfg.vision_backend, cfg.model_dir, cfg.npu_device_id)
        self.baseline = GasBaseline(list(cfg.gas_channels), cfg.baseline_window_days, cfg.baseline_min_days,
                                    cfg.gas_z_threshold, cfg.persistence_days)
        self.advisor = GutAdvisor(cfg)
        self.store = SessionStore(cfg.db_path)
        self.cloud = CloudSync(cfg, self.store)

    def on_frame(self, frame, ts):
        frame, method = correct_frame(frame, self.cfg.card_patch_boxes, self.cfg.card_patch_ref_rgb)
        result = self.analyzer.analyze(frame)
        result["cc"] = method
        if result["state"] == "URI":
            result["urine_level"], _ = urine_level(frame, self.cfg.urine_roi)
        with self.lock:
            if self.session is not None:
                self.session.add_frame(ts, result)
        print(f"[frame] {result['state']}" + (f" BS-probs top={max(result['bristol_probs'], key=result['bristol_probs'].get)}"
                                              if "bristol_probs" in result else ""))

    def handle_events(self):
        while not self.stop_event.is_set():
            try:
                ev = self.link.events.get(timeout=0.5)
            except Exception:
                continue
            if ev.kind == "uid":
                self.user = f"user{int(ev.value)}"
                print(f"[edge] active user -> {self.user}")
            elif ev.kind == "gas":
                with self.lock:
                    if self.session is not None:
                        self.session.add_gas(ev.value)
                    else:
                        self.ambient.append(ev.value)
            elif ev.kind == "occ" and ev.value == 1:
                with self.lock:
                    self.session = SessionAccumulator(self.user, list(self.cfg.gas_channels), self.ambient)
                self.capturing_event.set()
                print(f"[edge] session started for {self.user}")
            elif ev.kind == "occ" and ev.value == 0:
                self.capturing_event.clear()
                with self.lock:
                    acc, self.session = self.session, None
                if acc is not None:
                    self.process_session(acc)
                self.user = self.cfg.default_user
                if self.once:
                    self.stop_event.set()

    def process_session(self, acc):
        rec = acc.finish()
        if rec["n_frames"] == 0:
            print("[edge] empty session, ignored")
            return
        if rec.get("has_stool"):
            rec["digestive_score"] = digestive_score(rec["bristol_probs"])

        days = daily_summary(self.store.history(rec["user"], days=self.cfg.baseline_window_days + 16) + [rec])
        gas_eval = self.baseline.evaluate([(d["day"], d["gas"]) for d in days])
        rec["gas_eval"] = gas_eval
        rec["triage"] = triage(days, gas_eval)
        rec["advice"] = self.advisor.session_report(rec, days, rec["triage"])

        self.store.add(rec)
        synced = self.cloud.flush()
        print("\n========== session summary ==========")
        print(f"user={rec['user']}  frames={rec['n_frames']}  states={rec['state_counts']}")
        if rec.get("has_stool"):
            print(f"Bristol type {rec['bristol_type']} ({rec['condition']}), Digestive Score {rec['digestive_score']}")
        if rec.get("has_urine"):
            print(f"Urine level {rec['urine_level']}/8, Hydration Score {rec['hydration_score']}")
        print(f"triage: {rec['triage']['level']}  flags={[f['code'] for f in rec['triage']['flags']]}")
        print(f"advice [{rec['advice']['source']}/{rec['advice']['guard']}]: {rec['advice']['text']}")
        print(f"synced to cloud: {synced}")
        print("=====================================\n")

    def run(self):
        threads = [
            threading.Thread(target=self.link.run, daemon=True),
            threading.Thread(target=capture_loop, daemon=True,
                             args=(self.camera, self.capturing_event, self.stop_event, self.on_frame,
                                   self.cfg.capture_interval_s)),
            threading.Thread(target=self.handle_events, daemon=True),
        ]
        for t in threads:
            t.start()
        self.stop_event.wait()
        self.capturing_event.clear()
        self.link.send({"cmd": "led", "v": 0})
        self.camera.close()
        self.link.close()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--simulate", action="store_true", help="no hardware: simulated Hi3861 + replayed images")
    ap.add_argument("--images", default=None, help="glob of images to replay in --simulate mode")
    ap.add_argument("--gas-boost", type=float, default=1.0, help="simulated gas rise (try 4 for an anomaly)")
    ap.add_argument("--user-button", type=int, default=None)
    ap.add_argument("--once", action="store_true", help="exit after one session")
    args = ap.parse_args()

    stop_event = threading.Event()
    signal.signal(signal.SIGINT, lambda *_: stop_event.set())

    if args.simulate:
        pattern = args.images or str(ROOT.parent / "PHIND-system-main" / "*" / "*.jpg")
        images = sorted(glob.glob(pattern))
        link = SimulatedSensorLink(stop_event, len(CONFIG.gas_channels), gas_boost=args.gas_boost,
                                   user_button=args.user_button)
        camera = ReplayCamera(images[::7] or images, CONFIG.frame_width, CONFIG.frame_height)
        print(f"[sim] replaying {len(camera.paths)} images from {Path(pattern).parent}")
    else:
        link = SensorLink(CONFIG.serial_port, CONFIG.serial_baud, stop_event)
        camera = Camera(CONFIG.camera_index, CONFIG.frame_width, CONFIG.frame_height)

    EdgeNode(CONFIG, link, camera, stop_event, once=args.once).run()


if __name__ == "__main__":
    main()
