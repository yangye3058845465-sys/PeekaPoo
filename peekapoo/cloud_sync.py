# cloud_sync.py
"""
Module 5 - result sync to Huawei Cloud. Replaces PHIND's s3_upload.py,
the Lambda function and DynamoDB.

PHIND uploaded every raw JPEG to S3. PeekaPoo uploads ONLY the session record
(scores, Bristol type, flags, advice text) - see `cloud_payload()`, which is an
explicit allow-list, so nothing unexpected can leak even if the record grows.

  * IoTDA (MQTT)  - device shadow properties (latest scores) and an event when
                    triage level is "watch"/"consult"; the HarmonyOS app
                    subscribes to these for alerts.
  * OBS           - one JSON object per session for long-term history/trends.
"""

import hashlib
import hmac
import json
import ssl
import time

# Fields allowed to leave the device.
CLOUD_FIELDS = (
    "user", "start_ts", "end_ts", "total_time_s", "defecation_time_s",
    "has_stool", "has_urine", "bristol_type", "bristol_mean", "bristol_probs",
    "condition", "condition_probs", "digestive_score", "urine_level", "hydration_score",
    "triage", "advice",
)


def cloud_payload(record):
    return {k: record[k] for k in CLOUD_FIELDS if k in record}


def iotda_password(secret, timestamp):
    """IoTDA MQTT password = HMAC-SHA256(key=timestamp YYYYMMDDHH, msg=device secret)."""
    return hmac.new(timestamp.encode(), secret.encode(), hashlib.sha256).hexdigest()


class IoTDAClient:
    def __init__(self, host, port, device_id, secret, service_id):
        import paho.mqtt.client as mqtt
        ts = time.strftime("%Y%m%d%H", time.gmtime())
        self.device_id = device_id
        self.service_id = service_id
        client_id = f"{device_id}_0_0_{ts}"
        try:  # paho-mqtt >= 2.0
            self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=client_id)
        except AttributeError:
            self.client = mqtt.Client(client_id=client_id)
        self.client.username_pw_set(device_id, iotda_password(secret, ts))
        self.client.tls_set(cert_reqs=ssl.CERT_REQUIRED)
        self.client.connect(host, port, keepalive=120)
        self.client.loop_start()

    def report_properties(self, props):
        topic = f"$oc/devices/{self.device_id}/sys/properties/report"
        body = {"services": [{"service_id": self.service_id, "properties": props}]}
        return self.client.publish(topic, json.dumps(body), qos=1).wait_for_publish(10)

    def report_event(self, event_type, paras):
        topic = f"$oc/devices/{self.device_id}/sys/events/up"
        body = {"services": [{"service_id": self.service_id, "event_type": event_type,
                              "event_time": time.strftime("%Y%m%dT%H%M%SZ", time.gmtime()),
                              "paras": paras}]}
        return self.client.publish(topic, json.dumps(body), qos=1).wait_for_publish(10)

    def close(self):
        self.client.loop_stop()
        self.client.disconnect()


class OBSClient:
    def __init__(self, server, bucket, ak, sk):
        from obs import ObsClient  # pip install esdk-obs-python
        self.client = ObsClient(access_key_id=ak, secret_access_key=sk, server=server)
        self.bucket = bucket

    def put_record(self, record):
        day = time.strftime("%Y/%m/%d", time.localtime(record["start_ts"]))
        key = f"sessions/{record['user']}/{day}/{int(record['start_ts'])}.json"
        resp = self.client.putContent(self.bucket, key, json.dumps(record))
        if resp.status >= 300:
            raise RuntimeError(f"OBS put failed: {resp.status} {resp.errorMessage}")
        return key


class CloudSync:
    """Pushes unsynced records from the local store; silently stays offline if not configured."""

    def __init__(self, cfg, store):
        self.store = store
        self.iot = self.obs = None
        if cfg.iotda_host and cfg.iotda_device_id:
            try:
                self.iot = IoTDAClient(cfg.iotda_host, cfg.iotda_port, cfg.iotda_device_id,
                                       cfg.iotda_device_secret, cfg.iotda_service_id)
            except Exception as e:
                print(f"[cloud] IoTDA unavailable: {e}")
        if cfg.obs_server and cfg.obs_bucket:
            try:
                self.obs = OBSClient(cfg.obs_server, cfg.obs_bucket, cfg.obs_ak, cfg.obs_sk)
            except Exception as e:
                print(f"[cloud] OBS unavailable: {e}")
        if not (self.iot or self.obs):
            print("[cloud] not configured - results stay on the device (offline mode)")

    def flush(self):
        if not (self.iot or self.obs):
            return 0
        n = 0
        for row_id, rec in self.store.unsynced():
            payload = cloud_payload(rec)
            try:
                if self.obs:
                    self.obs.put_record(payload)
                if self.iot:
                    self.iot.report_properties({
                        "user": payload["user"],
                        "digestive_score": payload.get("digestive_score"),
                        "hydration_score": payload.get("hydration_score"),
                        "bristol_type": payload.get("bristol_type"),
                        "risk_level": payload.get("triage", {}).get("level", "normal"),
                    })
                    level = payload.get("triage", {}).get("level", "normal")
                    if level != "normal":
                        self.iot.report_event("gut_alert", {
                            "user": payload["user"], "level": level,
                            "flags": [f["code"] for f in payload["triage"]["flags"]],
                            "message": payload.get("advice", {}).get("text", ""),
                        })
                self.store.mark_synced(row_id)
                n += 1
            except Exception as e:
                print(f"[cloud] sync failed for record {row_id}, will retry: {e}")
                break
        return n
