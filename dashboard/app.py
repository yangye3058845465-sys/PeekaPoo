import sys
from pathlib import Path

from flask import Flask, jsonify, render_template, request

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from peekapoo.config import CONFIG  # noqa: E402
from peekapoo.gas_baseline import GasBaseline  # noqa: E402
from peekapoo.llm_advisor import GutAdvisor  # noqa: E402
from peekapoo.scoring import daily_summary, triage  # noqa: E402
from peekapoo.store import SessionStore  # noqa: E402

app = Flask(__name__)
store = SessionStore(CONFIG.db_path)
baseline = GasBaseline(list(CONFIG.gas_channels), CONFIG.baseline_window_days, CONFIG.baseline_min_days,
                       CONFIG.gas_z_threshold, CONFIG.persistence_days)
_advisor = None


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


@app.route("/")
def index():
    users = store.users() or [CONFIG.default_user]
    return render_template("index.html", users=users, user=request.args.get("user", users[0]))


@app.route("/api/summary")
def summary():
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


@app.route("/api/ask", methods=["POST"])
def ask():
    body = request.get_json(force=True)
    user = body.get("user", CONFIG.default_user)
    question = (body.get("question") or "").strip()
    if not question:
        return jsonify({"error": "empty question"}), 400
    sessions, days, tri = user_state(user)
    return jsonify(advisor().ask(question, days, tri, sessions[-1] if sessions else None))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
