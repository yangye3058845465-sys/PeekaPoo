# PeekaPoo system

AI-powered, non-contact gut health advisor (Team InsideOut, USM - 11th Huawei ICT Competition, Innovation Track).

This code base is derived from the **PHIND system** (Nature Protocols, `../PHIND-system-main`),
re-architected for PeekaPoo's edge-first design on Huawei hardware, and extended with a
**small on-device LLM** that explains results in plain language.

> PeekaPoo is a wellness **screening** aid, not a diagnostic device. All risk decisions are made by
> fixed rules (`peekapoo/scoring.py`); the LLM only rewords them.

## Architecture

```
 Sensing                 Edge control            Edge inference (Atlas 200I DK A2)              Cloud / App
 ───────                 ────────────            ──────────────────────────────────             ───────────
 seat pressure / PIR ─┐                          camera frame (memory only)
 8-ch gas array ──────┼─► Hi3861 ──UART JSON──►   → colour-card correction
 user button ─────────┘   (occupancy, LED,        → state CNN  CLE / STO / TPI / URI
                           30 s end rule,           ├ STO → Bristol 1-7 CNN + condition CNN
                           gas sampling)            └ URI → urine colour → Hydration Score
                                                  session end:
                                                    → personal gas baseline (robust z + 3-day persistence)
                                                    → triage rules  normal / watch / consult
                                                    → small LLM (Qwen2.5-0.5B) → advice text     ──► IoTDA (MQTT): scores, alerts
                                                    → SQLite history                             ──► OBS: session JSON
                                                                                                  ──► HarmonyOS app
```

Raw images never leave the Atlas and are never written to disk; only the fields listed in
`cloud_sync.CLOUD_FIELDS` are uploaded.

## What changed from PHIND

| PHIND file | PeekaPoo file | Change |
|---|---|---|
| Step 34/35/36 ADC, pressure, LED tests; Step 74 `pressure_sensor.py`; Step 75 `led_control.py` | `hi3861_firmware/peekapoo_ctrl.c` | Low-level sensing moves from the Raspberry Pi to the Hi3861 (OpenHarmony). Same 30 s end rule; adds the 8-channel gas array (ADS7828) and a user button. |
| Step 76/77 fingerprint enrolment/sensor | Hi3861 user button → `{"t":"uid"}` | Fingerprint scanner removed; per-user baselines use a user-select button (or the app). |
| Step 74 `main.py`, `cleanup.py`, `plot_graph.py`, `PHIND_run.sh` | `run_edge.py`, `peekapoo/sensor_link.py` | One process on the Atlas; `--simulate` mode runs without hardware. |
| Step 77 `image_capture.py` (libcamera → JPEG files) | `peekapoo/camera.py`, `peekapoo/color_correction.py` | Frames stay in memory; colour-reference-card correction added. |
| Step 77 `s3_upload.py` (all raw images → S3) | `peekapoo/cloud_sync.py` | Results only → Huawei Cloud IoTDA + OBS; offline queue in SQLite. |
| Step 121 Lambda (S3→SQS→SSM→EC2, regex on stdout) | `peekapoo/classifiers.py::GutAnalyzer` | Same 4-class → (7-class + 3-class) cascade, run in-process on the NPU (`.om`) or CPU (`.pt`). |
| Step 128 `analyze_{3,4,7}class.py` | `peekapoo/classifiers.py` | Models loaded once; torch or Ascend `.om` backend. |
| Step 65/66/67 training scripts | `training/train_classifier.py` | One script, fixes: un-augmented validation, per-class strong augmentation, per-sample focal loss, correct class order, state_dict saving. |
| — | `training/export_onnx.py`, `training/convert_om.sh` | ONNX → ATC → `.om` for the Ascend 310B. |
| Step 130 Django app + DynamoDB | `peekapoo/session.py`, `peekapoo/store.py`, `dashboard/` | Session aggregation on the edge; Flask dashboard with Chart.js + AI advisor card. |
| — | `peekapoo/urine.py` | **New**: urine colour → Hydration Score. |
| — | `peekapoo/gas_baseline.py` | **New**: personal baseline & 2-stage anomaly detection. |
| — | `peekapoo/scoring.py` | **New**: Digestive Score, deterministic triage rules. |
| — | `peekapoo/llm_advisor.py` | **New**: small LLM advisor with guardrails. |

## The small LLM (`peekapoo/llm_advisor.py`)

* **Model**: Qwen2.5-0.5B-Instruct (Apache-2.0), 4-bit GGUF ≈ 0.4 GB RAM. Swap to Qwen2.5-1.5B if memory allows.
* **Where**: on the Atlas 200I DK A2 ARM CPU via `llama-cpp-python` (`llm_backend="llamacpp"`).
  The NPU stays free for the CNNs. On a PC use `llm_backend="transformers"`.
* **What it does**: after each visit, writes 2-3 sentences + tips; answers follow-up questions
  from the dashboard/app (`/api/ask`), grounded only in the user's own recent records.
* **Guardrails**
  1. It receives structured facts only (`build_facts`), never images or raw sensor data.
  2. The risk level is decided by `scoring.triage()` and passed in as fixed.
  3. `check_output()` rejects diagnoses, drug names/doses, invented numbers, and missing
     clinician advice when level = consult → falls back to a deterministic template.
  4. Emergency words (blood, black stool, severe pain...) skip the LLM entirely.
  5. The disclaimer is appended by code.
* **No model file?** It silently uses the template backend, so the device always works.

Get the model:
```bash
pip install -U "huggingface_hub[cli]"
huggingface-cli download Qwen/Qwen2.5-0.5B-Instruct-GGUF qwen2.5-0.5b-instruct-q4_k_m.gguf --local-dir models
export PEEKAPOO_LLM_BACKEND=llamacpp
```

## Quick start (PC, no hardware)

```bash
pip install -r requirements-dev.txt
python tools/seed_demo_history.py --user user1 --days 14                              # healthy history
python tools/seed_demo_history.py --user user2 --days 14 --scenario constipation_gas  # 3 bad days
python run_edge.py --simulate --once                                  # one visit, user1
python run_edge.py --simulate --once --user-button 2 --gas-boost 3    # anomalous visit, user2
python dashboard/app.py                                                # http://localhost:8000
```
Without trained models the classifiers are RANDOM placeholders (a warning is printed) - the
pipeline runs, but the labels are meaningless until you train.

## Dataset

Our dataset is partially hosted on Google Drive:
https://drive.google.com/file/d/1aVG-MeGbs6UDDamuYg-NkCbmNdBAvjhE/view?usp=sharing

Download it and arrange it as one folder per class (CLE/STO/TPI/URI for `state`, BS1..BS7 for
`bristol`) before training.

## Train and deploy the vision models

```bash
# data: one folder per class (CLE/STO/TPI/URI, BS1..BS7). Run locally or in a ModelArts notebook.
python training/train_classifier.py --task state     --data-dir DATA/state
python training/train_classifier.py --task bristol   --data-dir DATA/bristol
python training/train_classifier.py --task condition --data-dir DATA/bristol --from-bristol
for t in state bristol condition; do python training/export_onnx.py --task $t; done
# copy models/*.onnx to the Atlas, then:
bash training/convert_om.sh
export PEEKAPOO_VISION_BACKEND=om
python run_edge.py
```

## Configuration

All settings are in `peekapoo/config.py` and can be overridden with `PEEKAPOO_<NAME>` environment
variables, e.g. `PEEKAPOO_SERIAL_PORT`, `PEEKAPOO_IOTDA_HOST`, `PEEKAPOO_IOTDA_DEVICE_ID`,
`PEEKAPOO_IOTDA_DEVICE_SECRET`, `PEEKAPOO_OBS_SERVER`, `PEEKAPOO_OBS_BUCKET`, `PEEKAPOO_OBS_AK`,
`PEEKAPOO_OBS_SK`, `PEEKAPOO_LLM_BACKEND`, `PEEKAPOO_DB_PATH`. Never commit AK/SK or device secrets.

## Status / TODO

- [x] End-to-end simulated run on PC (placeholder models, template advice)
- [x] Training script smoke-tested on the PHIND sample images
- [ ] Train real models on our dataset; report accuracy on a held-out test split
- [ ] Verify ONNX → `.om` conversion and `ais_bench` inference on the Atlas
- [ ] Build `llama-cpp-python` on the Atlas, measure LLM latency / RAM
- [ ] Flash and tune the Hi3861 firmware (pins, pressure threshold, gas ADC)
- [ ] Calibrate `URINE_CHART_RGB` and colour-card patch boxes on our actual toilet
- [ ] IoTDA product model (service `GutHealth`) + HarmonyOS app subscription
