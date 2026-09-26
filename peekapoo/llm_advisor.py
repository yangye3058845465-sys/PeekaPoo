# llm_advisor.py
"""
Small on-device LLM that turns PeekaPoo's numbers into plain-language advice.

PHIND stopped at charts (ring charts of class percentages, a BS curve); a user
still had to interpret "BS2 62%" themselves. PeekaPoo adds a small language
model (default: Qwen2.5-0.5B-Instruct, ~0.5B parameters, 4-bit GGUF ~400 MB)
running on the Atlas 200I DK A2 so that:
  * after every visit the user gets a 2-3 sentence explanation + tips, and
  * the app can ask follow-up questions ("why is my score lower this week?").

Safety design - the LLM is a *writer*, not a *decider*:
  1. Risk level and flags come from scoring.triage() (fixed rules). The LLM
     receives them as facts and is told not to change them.
  2. The LLM only sees structured numbers - never images, never raw sensor data.
  3. Every output passes check_output(): no diagnoses, no drug doses, no
     invented numbers, and a clinician mention whenever level == "consult".
     A failed check falls back to a deterministic template.
  4. Questions mentioning emergency symptoms (blood, black stool, severe pain...)
     bypass the LLM and get a fixed "seek medical care" answer.
  5. The medical disclaimer is appended by code, not generated.

Backends:
  "llamacpp"     - llama-cpp-python + GGUF, runs on the Atlas ARM CPU (recommended)
  "transformers" - HF transformers, for PC development (cuda/cpu) or torch_npu
  "template"     - no model at all; deterministic text (fallback & unit tests)
"""

import re

DISCLAIMER = ("PeekaPoo is a wellness screening aid, not a medical diagnosis. "
              "If you feel unwell, please talk to a healthcare professional.")

EMERGENCY_TERMS = re.compile(
    r"\b(blood|bloody|black stool|tarry|severe pain|faint|fainted|vomit\w*|high fever|chest pain|"
    r"can'?t pee|cannot urinate|unconscious)\b", re.I)

EMERGENCY_ANSWER = ("What you describe can need prompt medical attention. Please contact a doctor or "
                    "clinic today, or emergency services if it is severe. PeekaPoo cannot assess this.")

BANNED = [
    re.compile(r"\bdiagnos", re.I),
    re.compile(r"\byou (have|may have|might have|are suffering from|suffer from)\b[^.]*\b"
               r"(cancer|tumou?r|infection|disease|syndrome|ibs|crohn\w*|colitis|diabetes|uti|disorder)\b", re.I),
    re.compile(r"\b\d+(\.\d+)?\s?(mg|ml|tablets?|pills?)\b", re.I),
    re.compile(r"\b(prescri\w*|antibiotic\w*|laxative\w*|dosage)\b", re.I),
]
CLINICIAN = re.compile(r"\b(doctor|clinician|gp|healthcare|health care|medical|physician|pharmacist|clinic)\b", re.I)
NUMBER = re.compile(r"\d+(?:\.\d+)?")

SYSTEM_PROMPT = """You are PeekaPoo, a friendly gut-health assistant built into a smart toilet.
Rules you must follow:
- You are not a doctor. Never diagnose, never say the user has a disease, never mention medicines or doses.
- Use only the facts in DATA. Do not make up numbers; only quote numbers that appear in DATA.
- The risk level is already decided as "{level}". Do not raise or lower it.
- If the level is "consult", clearly suggest talking to a healthcare professional.
- If the level is "normal", be reassuring and brief.
- Answer in {language}, in at most 80 words, warm and simple, no markdown headings."""

TASK_REPORT = ("Write a short message for the user about this toilet visit: one sentence explaining the result, "
               "then 2 or 3 short practical tips (water, fibre, movement, routine) that fit the data.")


# ----------------------------------------------------------------------------- facts


def build_facts(session, days, triage_result):
    """Compact, model-friendly bullet list. Only these facts reach the LLM."""
    lines = []
    if session:
        if session.get("has_stool"):
            lines.append(f"Stool type this visit: Bristol type {session['bristol_type']} "
                         f"(scale 1 hard to 7 watery; 3-5 is typical)")
            lines.append(f"Stool pattern: {session['condition']}")
            if session.get("digestive_score") is not None:
                lines.append(f"Digestive Score this visit: {session['digestive_score']} out of 100")
        if session.get("has_urine"):
            lines.append(f"Hydration Score this visit: {session['hydration_score']} out of 100 "
                         f"(urine colour level {session['urine_level']} of 8)")
    recent = days[-7:]
    ds = [d["digestive_score"] for d in recent if d["digestive_score"] is not None]
    hs = [d["hydration_score"] for d in recent if d["hydration_score"] is not None]
    if len(ds) >= 2:
        lines.append(f"Digestive Score over the last {len(ds)} recorded days: " + ", ".join(map(str, ds)))
    if len(hs) >= 2:
        lines.append(f"Hydration Score over the last {len(hs)} recorded days: " + ", ".join(map(str, hs)))
    lines.append(f"Risk level: {triage_result['level']}")
    for f in triage_result["flags"]:
        lines.append(f"Flag: {f['detail']}")
    if not triage_result["flags"]:
        lines.append("Flags: none")
    return "\n".join("- " + l for l in lines)


# ----------------------------------------------------------------------------- guard


def check_output(text, level, facts):
    """Returns (ok, reason)."""
    if not text or len(text.split()) < 5:
        return False, "empty"
    for pat in BANNED:
        if pat.search(text):
            return False, f"banned:{pat.pattern[:30]}"
    if level == "consult" and not CLINICIAN.search(text):
        return False, "missing-clinician"
    allowed = set(NUMBER.findall(facts))
    for n in NUMBER.findall(text):
        if float(n) > 10 and n not in allowed:
            return False, f"invented-number:{n}"
    return True, "ok"


def trim_words(text, max_words=110):
    words = text.split()
    if len(words) <= max_words:
        return text.strip()
    cut = " ".join(words[:max_words])
    end = max(cut.rfind("."), cut.rfind("!"), cut.rfind("?"))
    return (cut[:end + 1] if end > 0 else cut + "...").strip()


# ----------------------------------------------------------------------------- backends


class TemplateBackend:
    name = "template"

    def chat(self, messages, max_new_tokens=200):
        return None  # signals "use the deterministic template"


class LlamaCppBackend:
    name = "llamacpp"

    def __init__(self, model_path, threads=4, n_ctx=2048):
        from llama_cpp import Llama
        self.llm = Llama(model_path=model_path, n_ctx=n_ctx, n_threads=threads, verbose=False)

    def chat(self, messages, max_new_tokens=200):
        r = self.llm.create_chat_completion(messages=messages, max_tokens=max_new_tokens,
                                            temperature=0.2, top_p=0.9, repeat_penalty=1.1)
        return r["choices"][0]["message"]["content"]


class TransformersBackend:
    name = "transformers"

    def __init__(self, model_id):
        import torch
        from transformers import AutoModelForCausalLM, AutoTokenizer
        try:
            import torch_npu  # noqa: F401  (Ascend NPU plugin, present on Atlas images)
            device = "npu:0"
        except ImportError:
            device = "cuda" if torch.cuda.is_available() else "cpu"
        dtype = torch.float16 if device != "cpu" else torch.float32
        self.torch = torch
        self.device = device
        self.tok = AutoTokenizer.from_pretrained(model_id)
        self.model = AutoModelForCausalLM.from_pretrained(model_id, torch_dtype=dtype).to(device).eval()

    def chat(self, messages, max_new_tokens=200):
        ids = self.tok.apply_chat_template(messages, add_generation_prompt=True, return_tensors="pt").to(self.device)
        with self.torch.no_grad():
            out = self.model.generate(ids, max_new_tokens=max_new_tokens, do_sample=False,
                                      repetition_penalty=1.1, pad_token_id=self.tok.eos_token_id)
        return self.tok.decode(out[0, ids.shape[1]:], skip_special_tokens=True)


def load_backend(cfg):
    try:
        if cfg.llm_backend == "llamacpp":
            return LlamaCppBackend(cfg.llm_model, threads=cfg.llm_threads)
        if cfg.llm_backend == "transformers":
            return TransformersBackend(cfg.llm_hf_model)
    except Exception as e:  # missing package / model file -> keep the device working
        print(f"[llm] could not load '{cfg.llm_backend}' backend ({e}); using template")
    return TemplateBackend()


# ----------------------------------------------------------------------------- templates

TIPS = {
    "HARD_STOOL": "Drink water regularly through the day and add fibre such as oats, fruit and vegetables.",
    "NO_BOWEL_MOVEMENT": "Try a regular toilet time after meals and some light daily walking.",
    "LOOSE_STOOL": "Sip fluids often and choose simple, bland meals until things settle.",
    "LOW_HYDRATION": "Your urine looks darker than usual - keep a water bottle nearby and drink regularly.",
    "GAS": "Stay well hydrated and do not hold in urine for long periods.",
}


def template_report(session, triage_result):
    level = triage_result["level"]
    parts = []
    if session and session.get("has_stool"):
        bt = session["bristol_type"]
        feel = "in the typical range" if 3 <= bt <= 5 else ("on the hard side" if bt < 3 else "on the loose side")
        parts.append(f"Today's stool looked like Bristol type {bt}, which is {feel}.")
    if session and session.get("has_urine"):
        hs = session["hydration_score"]
        verdict = ", nicely hydrated." if hs >= 65 else (", a little low." if hs >= 40 else ", which is low.")
        parts.append(f"Your Hydration Score is {hs}/100{verdict}")
    if not parts:
        parts.append("Your visit has been recorded.")
    keys = ["GAS" if f["code"].startswith("GAS_") else f["code"] for f in triage_result["flags"]]
    if session and session.get("has_stool"):   # one-off visit tips, even without a multi-day flag
        keys += ["HARD_STOOL"] if session["bristol_type"] < 3 else (["LOOSE_STOOL"] if session["bristol_type"] > 5 else [])
    if session and session.get("has_urine") and session["hydration_score"] < 50:
        keys.append("LOW_HYDRATION")
    tips = []
    for key in keys:
        if TIPS.get(key) and TIPS[key] not in tips:
            tips.append(TIPS[key])
    if level == "normal" and not tips:
        tips.append("Keep up your current routine of water, fibre and movement.")
    parts += tips[:3]
    if level == "consult":
        parts.append("Because this pattern has lasted several days, it is a good idea to talk to a doctor or healthcare professional.")
    elif level == "watch":
        parts.append("We will keep an eye on this over the next few days.")
    return " ".join(parts)


# ----------------------------------------------------------------------------- advisor


class GutAdvisor:
    def __init__(self, cfg):
        self.cfg = cfg
        self.backend = load_backend(cfg)

    def _generate(self, facts, level, user_msg):
        system = SYSTEM_PROMPT.format(level=level, language=self.cfg.llm_language)
        messages = [{"role": "system", "content": system},
                    {"role": "user", "content": f"DATA:\n{facts}\n\n{user_msg}"}]
        try:
            text = self.backend.chat(messages, max_new_tokens=self.cfg.llm_max_new_tokens)
        except Exception as e:
            return None, f"error:{e}"
        if text is None:
            return None, "template-backend"
        text = trim_words(text.replace("**", "").strip())
        ok, reason = check_output(text, level, facts)
        return (text if ok else None), reason

    def session_report(self, session, days, triage_result):
        facts = build_facts(session, days, triage_result)
        text, reason = self._generate(facts, triage_result["level"], TASK_REPORT)
        source = self.backend.name if text else "template"
        if text is None:
            text = template_report(session, triage_result)
        return {"text": text, "disclaimer": DISCLAIMER, "source": source,
                "guard": reason, "level": triage_result["level"]}

    def ask(self, question, days, triage_result, last_session=None):
        """Follow-up question from the app, grounded in the user's own recent records."""
        if EMERGENCY_TERMS.search(question):
            return {"text": EMERGENCY_ANSWER, "disclaimer": DISCLAIMER, "source": "rule", "guard": "emergency"}
        facts = build_facts(last_session, days, triage_result)
        text, reason = self._generate(facts, triage_result["level"],
                                      f"The user asks: \"{question.strip()[:300]}\"\n"
                                      f"Answer using only DATA. If DATA cannot answer it, say so kindly.")
        source = self.backend.name if text else "template"
        if text is None:
            text = ("I can only comment on what PeekaPoo has measured. "
                    + template_report(last_session, triage_result))
        return {"text": text, "disclaimer": DISCLAIMER, "source": source, "guard": reason}
