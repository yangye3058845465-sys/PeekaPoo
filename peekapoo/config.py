# config.py
"""
Central configuration for the PeekaPoo edge node (Atlas 200I DK A2).

Everything that PHIND hard-coded across files (EC2 paths, S3 bucket, DynamoDB
table, GPIO pins, thresholds) lives here instead. Any field can be overridden
with an environment variable named PEEKAPOO_<FIELD_NAME_IN_UPPERCASE>.
"""

import os
from dataclasses import dataclass, fields
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


@dataclass
class Config:
    # ---------------- Sensor link (Hi3861 -> Atlas over UART) ----------------
    serial_port: str = "/dev/ttyAMA0"
    serial_baud: int = 115200
    # Names of the 8 gas channels, in the order the Hi3861 reports them
    gas_channels: tuple = ("NH3", "H2S", "VOC", "CH4", "H2", "EtOH", "CO", "NO2")

    # ---------------- Session logic (same idea as PHIND pressure_sensor.py) ----
    capture_interval_s: float = 1.0      # PHIND: one image per second
    session_end_wait_s: float = 30.0     # PHIND: 30 s below threshold ends the event
    max_session_s: float = 1800.0        # safety stop

    # ---------------- Camera ----------------
    camera_index: int = 0
    frame_width: int = 640
    frame_height: int = 480
    # Colour reference card patches: (x, y, w, h) boxes in the fixed camera view,
    # and the reference sRGB value printed on the card for each patch.
    card_patch_boxes: tuple = (
        (20, 20, 16, 16), (40, 20, 16, 16), (60, 20, 16, 16),
        (20, 40, 16, 16), (40, 40, 16, 16), (60, 40, 16, 16),
    )
    card_patch_ref_rgb: tuple = (
        (243, 243, 242), (160, 160, 160), (85, 85, 85),
        (175, 54, 60), (70, 148, 73), (56, 61, 150),
    )
    # Region of the bowl water used for urine colour analysis (x, y, w, h)
    urine_roi: tuple = (220, 200, 200, 160)

    # ---------------- Vision models ----------------
    # backend: "torch" (.pth state_dict, dev PC) or "om" (Ascend .om via ais_bench)
    vision_backend: str = "torch"
    model_dir: str = str(ROOT / "models")
    npu_device_id: int = 0

    # ---------------- Personal baseline / anomaly detection ----------------
    baseline_window_days: int = 14
    baseline_min_days: int = 5           # no gas alerts until this much history exists
    gas_z_threshold: float = 3.0
    persistence_days: int = 3            # "a sustained 3-day deviation triggers an alert"

    # ---------------- Small LLM advisor ----------------
    # backend: "llamacpp" (GGUF on ARM CPU, recommended on Atlas),
    #          "transformers" (HF model on PC / torch_npu), or "template" (no LLM)
    llm_backend: str = "template"
    llm_model: str = str(ROOT / "models" / "qwen2.5-0.5b-instruct-q4_k_m.gguf")
    llm_hf_model: str = "Qwen/Qwen2.5-0.5B-Instruct"
    llm_max_new_tokens: int = 200
    llm_threads: int = 4
    llm_language: str = "English"

    # ---------------- Storage & cloud ----------------
    db_path: str = str(ROOT / "data" / "peekapoo.db")
    default_user: str = "user1"
    # Huawei Cloud IoTDA (MQTT) - device credentials from the IoTDA console
    iotda_host: str = ""                 # e.g. xxxxxxxx.st1.iotda-device.ap-southeast-1.myhuaweicloud.com
    iotda_port: int = 8883
    iotda_device_id: str = ""
    iotda_device_secret: str = ""
    iotda_service_id: str = "GutHealth"
    # Huawei Cloud OBS - long-term history of processed results (never raw images)
    obs_server: str = ""                 # e.g. https://obs.ap-southeast-1.myhuaweicloud.com
    obs_bucket: str = ""
    obs_ak: str = ""
    obs_sk: str = ""

    def __post_init__(self):
        for f in fields(self):
            env = os.environ.get(f"PEEKAPOO_{f.name.upper()}")
            if env is None:
                continue
            cur = getattr(self, f.name)
            if isinstance(cur, bool):
                setattr(self, f.name, env.lower() in ("1", "true", "yes"))
            elif isinstance(cur, int):
                setattr(self, f.name, int(env))
            elif isinstance(cur, float):
                setattr(self, f.name, float(env))
            elif isinstance(cur, str):
                setattr(self, f.name, env)


CONFIG = Config()
