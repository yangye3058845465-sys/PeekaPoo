import random
import re
import secrets
import sys
from pathlib import Path

from flask import Flask, abort, jsonify, redirect, render_template, request, send_from_directory

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from peekapoo.accounts import AccountStore  # noqa: E402
from peekapoo.config import CONFIG  # noqa: E402
from peekapoo.demo import SCENARIOS, seed_history  # noqa: E402
from peekapoo.gas_baseline import GasBaseline  # noqa: E402
from peekapoo.llm_advisor import DISCLAIMER, GutAdvisor, template_report  # noqa: E402
from peekapoo.scoring import daily_summary, digestive_score, triage  # noqa: E402
from peekapoo.store import SessionStore  # noqa: E402

MOBILE_DIR = Path(__file__).resolve().parent.parent / "mobile_app"

app = Flask(__name__)
store = SessionStore(CONFIG.db_path)
accounts = AccountStore(CONFIG.db_path)
baseline = GasBaseline(list(CONFIG.gas_channels), CONFIG.baseline_window_days, CONFIG.baseline_min_days,
                       CONFIG.gas_z_threshold, CONFIG.persistence_days)
_advisor = None


@app.after_request
def allow_app_origin(resp):
    # the Android app loads its pages from the APK, so API calls are cross-origin
    if request.path.startswith("/api/"):
        resp.headers["Access-Control-Allow-Origin"] = "*"
        resp.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
        resp.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    return resp


def advisor():
    global _advisor
    if _advisor is None:
        _advisor = GutAdvisor(CONFIG)
    return _advisor


def user_state(user):
    sessions = store.history(user, days=30)
    days = daily_summary(sessions)
    gas_eval = baseline.evaluate([(d["day"], d["gas"]) for d in days])
    return sessions, days, triage(days, gas_eval)


EMAIL_RE = re.compile(r"[^@\s]+@[^@\s]+\.[^@\s]+")
MEMBER_RE = re.compile(r"user[1-4]")


def bearer():
    auth = request.headers.get("Authorization", "")
    return auth[7:] if auth.startswith("Bearer ") else None


def current_account():
    token = bearer()
    return accounts.lookup(token) if token else None


def member_of(requested):
    acc = current_account()
    if CONFIG.public_demo:
        # strangers share this server: only ever show the caller's own data
        if not acc:
            abort(401)
        return acc["member"]
    return requested or (acc and acc["member"]) or CONFIG.default_user


@app.errorhandler(401)
def unauthorized(_):
    return jsonify({"error": "Please log in again"}), 401


@app.route("/api/config")
def config():
    return jsonify({"public_demo": CONFIG.public_demo})


@app.route("/api/register", methods=["POST"])
def register():
    body = request.get_json(force=True)
    name = (body.get("name") or "").strip()
    email = (body.get("email") or "").strip().lower()
    password = body.get("password") or ""
    member = body.get("member") or ""
    if not name:
        return jsonify({"error": "Please enter your name"}), 400
    if not EMAIL_RE.fullmatch(email):
        return jsonify({"error": "Please enter a valid email"}), 400
    if len(password) < 8:
        return jsonify({"error": "Password must be at least 8 characters"}), 400
    if CONFIG.public_demo:
        member = "m_" + secrets.token_hex(6)
    elif not MEMBER_RE.fullmatch(member):
        return jsonify({"error": "Please choose your button on the device"}), 400
    try:
        token = accounts.register(email, name, password, member)
    except ValueError as e:
        return jsonify({"error": str(e)}), 409
    if CONFIG.public_demo:
        seed_history(store, member, 14, random.choice(SCENARIOS), seed=secrets.randbits(32))
    return jsonify({"token": token, **accounts.lookup(token)})


@app.route("/api/login", methods=["POST"])
def login():
    body = request.get_json(force=True)
    try:
        token = accounts.login((body.get("email") or "").strip().lower(), body.get("password") or "")
    except ValueError as e:
        return jsonify({"error": str(e)}), 401
    return jsonify({"token": token, **accounts.lookup(token)})


@app.route("/api/me")
def me():
    acc = current_account()
    return jsonify(acc) if acc else (jsonify({"error": "Please log in again"}), 401)


@app.route("/api/logout", methods=["POST"])
def logout():
    token = bearer()
    if token:
        accounts.logout(token)
    return jsonify({"ok": True})


@app.route("/")
def index():
    if CONFIG.public_demo:
        return redirect("/m/")
    users = store.users() or [CONFIG.default_user]
    return render_template("index.html", users=users, user=request.args.get("user", users[0]))


@app.route("/api/summary")
def summary():
    if CONFIG.public_demo:
        abort(404)
    user = request.args.get("user", CONFIG.default_user)
    sessions, days, tri = user_state(user)
    last = sessions[-1] if sessions else None
    last_stool = next((s for s in reversed(sessions) if s.get("has_stool")), None)
    return jsonify({
        "user": user,
        "last": last and {k: last.get(k) for k in (
            "start_ts", "total_time_s", "defecation_time_s", "bristol_type", "condition",
            "digestive_score", "hydration_score", "urine_level", "advice")},
        "last_stool": last_stool and {"bristol_probs": last_stool["bristol_probs"],
                                      "condition_probs": last_stool["condition_probs"],
                                      "bristol_type": last_stool["bristol_type"],
                                      "condition": last_stool["condition"]},
        "days": days,
        "triage": tri,
    })


URINE_GROUPS = (("Pale yellow", (1, 2, 3)), ("Light amber", (4, 5)), ("Dark amber", (6, 7, 8)))


def _share(counts, total):
    return {k: round(100 * v / total) if total else 0 for k, v in counts.items()}


@app.route("/m/")
@app.route("/m/<path:path>")
def mobile(path="index.html"):
    return send_from_directory(MOBILE_DIR, path)


@app.route("/api/app")
def app_data():
    user = member_of(request.args.get("user"))
    sessions, days, tri = user_state(user)
    gas_eval = baseline.evaluate([(d["day"], d["gas"]) for d in days])
    stool = [s for s in sessions if s.get("has_stool")]
    urine = [s for s in sessions if s.get("has_urine")]
    last = sessions[-1] if sessions else None
    last_stool = stool[-1] if stool else None
    last_urine = urine[-1] if urine else None

    advice = (last or {}).get("advice") or {}
    insight = advice.get("text") or (template_report(last, tri) if last else None)

    bristol = {f"T{i}": sum(s["bristol_type"] == i for s in stool) for i in range(1, 8)}
    condition = {c: sum(s.get("condition") == c for s in stool) for c in ("Constipation", "Normal", "Diarrhea")}
    urine_groups = {name: sum(s["urine_level"] in levels for s in urine) for name, levels in URINE_GROUPS}

    z_by_day = dict(baseline.daily_z([(d["day"], d["gas"]) for d in days]))
    gas7 = [{"day": d["day"], "NH3": d["gas"].get("NH3"), "VOC": d["gas"].get("VOC"),
             "z_NH3": (z_by_day.get(d["day"]) or {}).get("NH3"),
             "z_VOC": (z_by_day.get(d["day"]) or {}).get("VOC")} for d in days[-7:]]

    return jsonify({
        "user": user,
        "users": [user] if CONFIG.public_demo else (store.users() or [CONFIG.default_user]),
        "visits": len(sessions),
        "last_ts": last and last["start_ts"],
        "digestive": last_stool and {"score": last_stool.get("digestive_score") or digestive_score(last_stool["bristol_probs"]),
                                     "bristol_type": last_stool["bristol_type"],
                                     "condition": last_stool["condition"]},
        "hydration": last_urine and {"score": last_urine["hydration_score"], "level": last_urine["urine_level"]},
        "insight": insight,
        "disclaimer": DISCLAIMER,
        "triage": tri,
        "gas_warming_up": gas_eval["warming_up"],
        "trend": [{"day": d["day"], "digestive": d["digestive_score"], "hydration": d["hydration_score"]} for d in days[-14:]],
        "bristol": {"counts": bristol, "share": _share(bristol, len(stool)), "n": len(stool)},
        "condition": {"counts": condition, "share": _share(condition, len(stool))},
        "urine": {"counts": urine_groups, "share": _share(urine_groups, len(urine)), "n": len(urine)},
        "gas7": gas7,
        "z_threshold": CONFIG.gas_z_threshold,
        "recent": [{k: s.get(k) for k in ("start_ts", "total_time_s", "has_stool", "has_urine", "bristol_type",
                                          "condition", "hydration_score", "digestive_score")}
                   for s in reversed(sessions[-20:])],
        "system": {"vision_backend": CONFIG.vision_backend, "llm_backend": CONFIG.llm_backend,
                   "cloud": bool(CONFIG.iotda_host or CONFIG.obs_server),
                   "synthetic": any(s.get("synthetic") for s in sessions)},
    })


@app.route("/api/ask", methods=["POST"])
def ask():
    body = request.get_json(force=True)
    user = member_of(body.get("user"))
    question = (body.get("question") or "").strip()
    if not question:
        return jsonify({"error": "empty question"}), 400
    sessions, days, tri = user_state(user)
    return jsonify(advisor().ask(question, days, tri, sessions[-1] if sessions else None))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
