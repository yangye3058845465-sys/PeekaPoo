import os
from dataclasses import dataclass, fields
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


@dataclass
class Config:
    serial_port: str = "/dev/ttyAMA0"
    serial_baud: int = 115200
    gas_channels: tuple = ("NH3", "H2S", "VOC", "CH4", "H2", "EtOH", "CO", "NO2")

    capture_interval_s: float = 1.0
    session_end_wait_s: float = 30.0
    max_session_s: float = 1800.0

    camera_index: int = 0
    frame_width: int = 640
    frame_height: int = 480
    card_patch_boxes: tuple = (
        (20, 20, 16, 16), (40, 20, 16, 16), (60, 20, 16, 16),
        (20, 40, 16, 16), (40, 40, 16, 16), (60, 40, 16, 16),
    )
    card_patch_ref_rgb: tuple = (
        (243, 243, 242), (160, 160, 160), (85, 85, 85),
        (175, 54, 60), (70, 148, 73), (56, 61, 150),
    )
    urine_roi: tuple = (220, 200, 200, 160)

    # "torch" | "om"
    vision_backend: str = "torch"
    model_dir: str = str(ROOT / "models")
    npu_device_id: int = 0

    baseline_window_days: int = 14
    baseline_min_days: int = 5
    gas_z_threshold: float = 3.0
    persistence_days: int = 3

    # "llamacpp" | "transformers" | "template"
    llm_backend: str = "template"
    llm_model: str = str(ROOT / "models" / "qwen2.5-0.5b-instruct-q4_k_m.gguf")
    llm_hf_model: str = "Qwen/Qwen2.5-0.5B-Instruct"
    llm_max_new_tokens: int = 200
    llm_threads: int = 4
    llm_language: str = "English"

    db_path: str = str(ROOT / "data" / "peekapoo.db")
    default_user: str = "user1"
    iotda_host: str = ""  # xxxx.st1.iotda-device.ap-southeast-1.myhuaweicloud.com
    iotda_port: int = 8883
    iotda_device_id: str = ""
    iotda_device_secret: str = ""
    iotda_service_id: str = "GutHealth"
    obs_server: str = ""  # https://obs.ap-southeast-1.myhuaweicloud.com
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
