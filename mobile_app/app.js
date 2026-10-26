const $ = (s, el = document) => el.querySelector(s);
const $$ = (s, el = document) => [...el.querySelectorAll(s)];
const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

const store = {
  get(k, d) { try { return JSON.parse(localStorage.getItem(k)) ?? d; } catch { return d; } },
  set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch { /* private mode */ } },
};

const FLAG_TITLE = {
  HARD_STOOL: "Hard stools", LOOSE_STOOL: "Loose stools", LOW_HYDRATION: "Low hydration",
  NO_BOWEL_MOVEMENT: "No bowel movement", GAS_NH3: "Ammonia above your baseline", GAS_H2S: "Sulphide gas above your baseline",
  GAS_VOC: "VOC above your baseline", GAS_CH4: "Methane above your baseline", GAS_H2: "Hydrogen above your baseline",
};
const LEVEL_TEXT = {
  normal: "Everything looks within your usual range.",
  watch: "Something has changed for a few days. We'll keep watching.",
  consult: "A pattern has lasted several days. Consider talking to a doctor.",
};
const SOURCE_TEXT = { template: "on-device rules", rule: "safety rule", llamacpp: "Qwen2.5-0.5B on Atlas", transformers: "Qwen2.5-0.5B" };

// Address of the PeekaPoo hub. Served from the hub itself -> same origin; packaged in the Android app -> configurable.
const DEFAULT_HUB = "http://192.168.135.74:8000";
const SAME_ORIGIN = location.protocol.startsWith("http");
const hub = () => store.get("pp_hub", SAME_ORIGIN ? location.origin : DEFAULT_HUB);

let state = { user: null, data: null, bristolSel: null, view: "consistency" };
const account = () => store.get("pp_account", null);
const displayName = u => (account() && u === account().member ? account().name : `Button ${String(u).replace("user", "")}`);

async function api(path, opts = {}) {
  const token = store.get("pp_token", null);
  const headers = { "Content-Type": "application/json" };
  if (token) headers.Authorization = `Bearer ${token}`;
  let r;
  try {
    r = await fetch(hub() + path, { ...opts, headers });
  } catch {
    throw new Error(`Can't reach your PeekaPoo hub at ${hub()}. Check the address and that you're on the same Wi-Fi.`);
  }
  const body = await r.json().catch(() => ({}));
  if (r.status === 401 && token) {
    logout(false);
    throw new Error("Please log in again");
  }
  if (!r.ok) throw new Error(body.error || `Server error (${r.status})`);
  return body;
}

async function load() {
  const q = state.user ? `?user=${encodeURIComponent(state.user)}` : "";
  state.data = await api(`/api/app${q}`);
  state.user = state.data.user;
  store.set("pp_user", state.user);
  renderAll();
}

function renderAll() {
  const d = state.data;
  renderHome(d);
  renderData(d);
  renderAlerts(d);
  renderProfile(d);
}

/* ---------- helpers ---------- */
function ring(el, score, color, track) {
  const r = 36, c = 2 * Math.PI * r, v = score == null ? 0 : score / 100;
  el.innerHTML = `<svg viewBox="0 0 86 86"><circle cx="43" cy="43" r="${r}" fill="none" stroke="${track}" stroke-width="8"/>
    <circle cx="43" cy="43" r="${r}" fill="none" stroke="${color}" stroke-width="8" stroke-linecap="round"
      stroke-dasharray="${c * v} ${c}"/></svg><b>${score ?? "–"}</b>`;
}

const dayDate = day => new Date(`${day}T12:00:00`);
const weekday = day => dayDate(day).toLocaleDateString("en", { weekday: "short" });
const fmtTime = ts => new Date(ts * 1000).toLocaleString("en", { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" });

function hbar(label, pct, color) {
  return `<div class="hbar"><span>${esc(label)}</span><div class="hbar__track"><div class="hbar__fill" style="width:${pct}%;${color ? `background:${color}` : ""}"></div></div><span>${pct}%</span></div>`;
}

function hydrationLabel(s) {
  return s >= 80 ? "Well hydrated" : s >= 65 ? "Good" : s >= 50 ? "Slightly low today" : "Low, drink some water";
}
function digestiveLabel(t) {
  return `Type ${t} · ${t <= 2 ? "On the hard side" : t >= 6 ? "On the loose side" : t === 4 ? "Well formed" : "Typical range"}`;
}

/* ---------- home ---------- */
function renderHome(d) {
  const h = new Date().getHours();
  $("#greeting").textContent = h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening";
  $("#name").textContent = displayName(d.user);
  $("#avatar-btn").textContent = displayName(d.user).charAt(0).toUpperCase();

  ring($("#ring-dig"), d.digestive?.score, "#1b1240", "rgba(27,18,64,.15)");
  ring($("#ring-hyd"), d.hydration?.score, "#6f8fbf", "rgba(27,18,64,.12)");
  $("#dig-sub").textContent = d.digestive ? digestiveLabel(d.digestive.bristol_type) : "No stool visit yet";
  $("#hyd-sub").textContent = d.hydration ? hydrationLabel(d.hydration.score) : "No urine visit yet";

  $("#insight").textContent = d.insight || "Your first toilet visit will appear here.";

  const flags = d.triage.flags;
  $("#alert-card").hidden = !flags.length;
  $("#tab-dot").hidden = !flags.length;
  if (flags.length) {
    $("#alert-title").textContent = d.triage.level === "consult" ? "ALERT! Unusual pattern detected" : "Heads up: something changed";
    $("#alert-title").className = `eyebrow ${d.triage.level === "consult" ? "eyebrow--red" : ""}`;
    $("#alert-title").style.color = d.triage.level === "watch" ? "var(--amber)" : "";
    $("#alert-flags").innerHTML = flags.map(f => `<li>${esc(f.detail.charAt(0).toUpperCase() + f.detail.slice(1))}</li>`).join("");
  }

  spark($("#spark"), d.trend.slice(-7));
  $("#last-visit").textContent = d.last_ts ? `Last visit ${fmtTime(d.last_ts)} · ${d.visits} visits in 30 days` : "No visits recorded yet";
}

function spark(el, days) {
  if (!days.length) { el.innerHTML = `<p class="muted">No data yet</p>`; return; }
  const W = 320, H = 110, L = 6, R = 6, T = 10, B = 22;
  const x = i => L + (days.length === 1 ? (W - L - R) / 2 : i * (W - L - R) / (days.length - 1));
  const y = v => T + (1 - v / 100) * (H - T - B);
  const line = (key, color) => {
    const pts = days.map((d, i) => d[key] == null ? null : [x(i), y(d[key])]).filter(Boolean);
    if (!pts.length) return "";
    return `<polyline points="${pts.map(p => p.join(",")).join(" ")}" fill="none" stroke="${color}" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round"/>`
      + pts.map(p => `<circle cx="${p[0]}" cy="${p[1]}" r="3" fill="${color}"/>`).join("");
  };
  const grid = [0, 50, 100].map(v => `<line x1="${L}" x2="${W - R}" y1="${y(v)}" y2="${y(v)}" stroke="rgba(255,255,255,.07)"/>`).join("");
  const labels = days.map((d, i) => `<text x="${x(i)}" y="${H - 6}" text-anchor="middle">${weekday(d.day).charAt(0)}</text>`).join("");
  el.innerHTML = `<svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="none">${grid}${line("digestive", "#bfe0d4")}${line("hydration", "#c6f432")}${labels}</svg>`;
}

/* ---------- data ---------- */
function renderData(d) {
  $("#data-sub").textContent = `${d.visits} logged visits in the last 30 days · your own history only`;

  const share = d.bristol.share, n = d.bristol.n;
  const top = n ? Object.entries(d.bristol.counts).sort((a, b) => b[1] - a[1])[0][0] : null;
  const keys = ["All", "T1", "T2", "T3", "T4", "T5", "T6", "T7"];
  const max = Math.max(1, ...Object.values(share));
  const sel = state.bristolSel || top || "All";
  $("#bristol-bars").innerHTML = keys.map(k => {
    const pct = k === "All" ? 100 : share[k];
    const hgt = k === "All" ? 100 : 8 + 92 * pct / max;
    const cls = ["bar", k === "All" ? "is-all" : "", k === top ? "is-hi" : "", k === sel ? "is-sel" : ""].join(" ");
    return `<button class="${cls}" data-k="${k}"><i style="height:${hgt}%"></i><b>${k}</b><small>${n ? pct : 0}%</small></button>`;
  }).join("");
  $$("#bristol-bars .bar").forEach(b => b.onclick = () => { state.bristolSel = b.dataset.k; renderData(state.data); });

  let note;
  if (!n) note = "No stool visits yet in the last 30 days.";
  else if (sel === "All") note = `${n} stool visits analysed. Your most common is Type ${top.slice(1)} (${share[top]}%).`;
  else {
    const t = +sel.slice(1);
    note = `Type ${t}${sel === top ? ", your most common type" : ""}: ${BSS[t].short.toLowerCase()}. Logged ${share[sel]}% of the time this month.`;
  }
  $("#bristol-note").textContent = note;

  renderChipView(d);

  $("#bss-grid").innerHTML = [1, 2, 3, 4, 5, 6, 7].map(t =>
    `<button class="bss ${`T${t}` === top ? "is-hi" : ""}" data-t="${t}">${bssImage(t)}<span>${BSS[t].short}</span></button>`).join("");
  $$("#bss-grid .bss").forEach(b => b.onclick = () => openSheet(+b.dataset.t));

  const uShare = d.urine.share;
  const ucol = { "Pale yellow": "#f4f1c9", "Light amber": "#bfe0d4", "Dark amber": "#6f8fbf" };
  $("#urine-bars").innerHTML = ["Pale yellow", "Light amber", "Dark amber"].map(k => hbar(k, uShare[k], ucol[k])).join("");
  const dark = uShare["Dark amber"];
  $("#urine-note").textContent = !d.urine.n ? "No urine visits yet."
    : dark >= 30 ? `Dark amber on ${dark}% of visits: drinking a little more water through the day may help.`
    : "Mostly pale yellow to light amber this month, consistent with a well-hydrated baseline.";

  gasBars($("#nh3-bars"), d.gas7, "NH3", d.z_threshold);
  gasBars($("#voc-bars"), d.gas7, "VOC", d.z_threshold);
  const high = d.gas7.filter(g => g.z_NH3 != null && g.z_NH3 > d.z_threshold).map(g => weekday(g.day));
  $("#nh3-note").textContent = d.gas_warming_up ? "Still building your personal baseline (needs at least 5 days)."
    : high.length ? `Above your personal baseline on ${high.join(", ")}. An alert is raised only after 3 days in a row.`
    : "Within your personal baseline all week.";
}

function gasBars(el, gas7, ch, thr) {
  const vals = gas7.map(g => g[ch]);
  const max = Math.max(1, ...vals.filter(v => v != null));
  el.innerHTML = gas7.map(g => {
    const v = g[ch], hi = g[`z_${ch}`] != null && g[`z_${ch}`] > thr;
    return `<div class="bar ${hi ? "is-hi" : ""}"><i style="height:${v == null ? 4 : 10 + 90 * v / max}%"></i>
      <b>${weekday(g.day).charAt(0)}</b><small>${v == null ? "–" : Math.round(v)}</small></div>`;
  }).join("");
}

function renderChipView(d) {
  $$("#chips .chip").forEach(c => c.classList.toggle("is-on", c.dataset.view === state.view));
  const el = $("#chip-view");
  if (state.view === "consistency") {
    const s = d.condition.share;
    el.innerHTML = hbar("Hard (1–2)", s.Constipation, "#6f8fbf") + hbar("Typical (3–5)", s.Normal) + hbar("Loose (6–7)", s.Diarrhea, "#ffb547");
  } else if (state.view === "scores") {
    el.innerHTML = `<div class="card" style="margin-top:0">${d.trend.slice().reverse().slice(0, 7).map(t =>
      `<div class="visit-row"><span>${weekday(t.day)} ${t.day.slice(5)}</span><span>Digestive <b>${t.digestive ?? "–"}</b> · Hydration <b>${t.hydration ?? "–"}</b></span></div>`).join("")}</div>`;
  } else {
    el.innerHTML = `<div class="card" style="margin-top:0">${d.recent.slice(0, 6).map(v =>
      `<div class="visit-row"><span>${fmtTime(v.start_ts)}</span><span>${Math.round((v.total_time_s || 0) / 60)} min</span></div>`).join("") || "<p class='muted'>No visits yet</p>"}</div>`;
  }
}

/* ---------- alerts ---------- */
function renderAlerts(d) {
  const lvl = d.triage.level;
  $("#status-badge").textContent = lvl;
  $("#status-badge").className = `status__badge lvl-${lvl}`;
  $("#status-text").textContent = LEVEL_TEXT[lvl];

  $("#flag-cards").innerHTML = d.triage.flags.map(f => `
    <article class="card flag">
      <span class="flag__bar lvl-${f.level}"></span>
      <div><h4>${esc(FLAG_TITLE[f.code] || f.code)}</h4><p>${esc(f.detail.charAt(0).toUpperCase() + f.detail.slice(1))}.</p></div>
    </article>`).join("") || `<article class="card flag"><span class="flag__bar lvl-normal"></span><div><h4>No active alerts</h4><p>Keep using PeekaPoo as usual; it watches in the background.</p></div></article>`;

  $("#timeline").innerHTML = d.recent.slice(0, 10).map(v => {
    const bits = [];
    if (v.has_stool) bits.push(`Stool · Type ${v.bristol_type}`);
    if (v.has_urine) bits.push(`Hydration ${v.hydration_score}`);
    return `<li><time>${fmtTime(v.start_ts)}</time><span>${esc(bits.join(" · ") || "Visit recorded")}</span></li>`;
  }).join("") || `<li class="muted">No visits yet</li>`;
}

/* ---------- profile ---------- */
function memberLabel(u) {
  const slot = `Button ${String(u).replace("user", "")}`;
  return account() && u === account().member ? `${slot} · You` : slot;
}

function renderProfile(d) {
  const acc = account() || { name: "-", email: "", member: d.user };
  $("#avatar-lg").textContent = acc.name.charAt(0).toUpperCase();
  $("#profile-name").textContent = acc.name;
  $("#profile-email").textContent = acc.email;
  $("#profile-id").textContent = serverConfig.public_demo ? "Demo account" : `Device button ${String(acc.member).replace("user", "")}`;
  $("#household").hidden = serverConfig.public_demo;
  $("#members").innerHTML = d.users.map(u => `<button class="member ${u === d.user ? "is-on" : ""}" data-u="${esc(u)}">${esc(memberLabel(u))}</button>`).join("");
  $$("#members .member").forEach(b => b.onclick = () => { state.user = b.dataset.u; state.bristolSel = null; resetChat(); load().then(() => go("home")); });

  const s = d.system;
  $("#sys-vision").textContent = s.vision_backend === "om" ? "Ascend NPU (.om)" : "PyTorch (CPU)";
  $("#sys-llm").textContent = s.llm_backend === "template" ? "Rule templates" : `Qwen2.5-0.5B (${s.llm_backend})`;
  $("#sys-cloud").textContent = s.cloud ? "Connected" : "Offline (local only)";
  $("#sys-data").textContent = s.synthetic ? "Demo data" : "Live device";
  $("#disclaimer").textContent = d.disclaimer;
}

/* ---------- auth ---------- */
let serverConfig = { public_demo: false };

// a public demo hub gives every sign-up its own data, so there is no device button to pick
async function loadServerConfig() {
  try {
    serverConfig = await api("/api/config");
  } catch {
    serverConfig = { public_demo: false };
  }
  $("#register-form .slots").hidden = serverConfig.public_demo;
}

function showAuth(which) {
  loadServerConfig();
  $("#auth").hidden = false;
  $("#login-form").hidden = which !== "login";
  $("#register-form").hidden = which !== "register";
  $("#auth-brand").hidden = which !== "login";
  $("#hub-label").textContent = hub();
  $$(".auth__error").forEach(e => { e.hidden = true; });
  $("#auth").scrollTop = 0;
}

function authError(form, msg) {
  const el = $(".auth__error", form);
  el.textContent = msg;
  el.hidden = !msg;
}

function signedIn(r) {
  store.set("pp_token", r.token);
  store.set("pp_account", { name: r.name, email: r.email, member: r.member });
  state.user = r.member;
  state.bristolSel = null;
  resetChat();
  $("#auth").hidden = true;
  go("home");
  load().catch(e => { $("#insight").textContent = e.message; });
}

async function submitAuth(form, path, body, busyText) {
  const btn = $(".btn", form), label = btn.textContent;
  btn.disabled = true;
  btn.textContent = busyText;
  try {
    signedIn(await api(path, { method: "POST", body: JSON.stringify(body) }));
  } catch (e) {
    authError(form, e.message);
  } finally {
    btn.disabled = false;
    btn.textContent = label;
  }
}

$("#login-form").onsubmit = e => {
  e.preventDefault();
  const f = e.target, email = f.email.value.trim(), password = f.password.value;
  if (!email || !password) return authError(f, "Please enter your email and password");
  submitAuth(f, "/api/login", { email, password }, "Logging in…");
};

$("#register-form").onsubmit = e => {
  e.preventDefault();
  const f = e.target, slot = f.querySelector("input[name=slot]:checked");
  const err = !f.elements.name.value.trim() ? "Please enter your name"
    : !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(f.email.value.trim()) ? "Please enter a valid email"
    : f.password.value.length < 8 ? "Password must be at least 8 characters"
    : f.password.value !== f.confirm.value ? "Passwords don't match"
    : !slot && !serverConfig.public_demo ? "Please choose your button on the device"
    : !f.agree.checked ? "Please accept the consent to continue" : "";
  if (err) return authError(f, err);
  submitAuth(f, "/api/register", { name: f.elements.name.value.trim(), email: f.email.value.trim(), password: f.password.value,
    member: slot ? `user${slot.value}` : "" }, "Creating account…");
};

$$("[data-auth]").forEach(b => b.onclick = () => showAuth(b.dataset.auth));

$("#hub-change").onclick = () => {
  const input = $("#hub-input");
  if (input.hidden) {
    input.value = hub();
    input.hidden = false;
    $("#hub-change").textContent = "Done";
    input.focus();
  } else {
    let v = input.value.trim().replace(/\/+$/, "");
    if (v && !/^https?:\/\//.test(v)) v = `http://${v}`;
    store.set("pp_hub", v || (SAME_ORIGIN ? location.origin : DEFAULT_HUB));
    loadServerConfig();
    input.hidden = true;
    $("#hub-change").textContent = "Change";
    $("#hub-label").textContent = hub();
  }
};

function logout(callServer = true) {
  if (callServer) api("/api/logout", { method: "POST" }).catch(() => {});
  for (const k of ["pp_token", "pp_account", "pp_user"]) {
    try { localStorage.removeItem(k); } catch { /* private mode */ }
  }
  $("#chat").hidden = true;
  $("#login-form").reset();
  $("#register-form").reset();
  showAuth("login");
}
$("#logout").onclick = () => logout(true);
$("#delete-account").onclick = async () => {
  if (!confirm("Delete your account? This permanently deletes your account and all your PeekaPoo results.")) return;
  try {
    await api("/api/delete_account", { method: "POST" });
    logout(false);
  } catch (e) {
    alert(e.message);
  }
};

/* ---------- navigation ---------- */
function go(tab) {
  $$(".screen").forEach(s => s.classList.toggle("is-active", s.dataset.tab === tab));
  $$(".tab").forEach(t => t.classList.toggle("is-on", t.dataset.goto === tab));
  $(`#screen-${tab}`).scrollTop = 0;
}
document.addEventListener("click", e => {
  const g = e.target.closest("[data-goto]");
  if (g) go(g.dataset.goto);
});
$("#avatar-btn").onclick = () => go("profile");
$$("#chips .chip").forEach(c => c.onclick = () => { state.view = c.dataset.view; renderChipView(state.data); });

/* ---------- bristol sheet ---------- */
function openSheet(t) {
  const b = BSS[t];
  $("#sheet-body").innerHTML = `${bssImage(t)}<h3>${esc(b.title)}</h3>
    <section><h4>WHAT THIS REPRESENTS</h4><p>${esc(b.means)}</p></section>
    <section><h4>POSSIBLE CAUSES</h4><ul>${b.causes.map(c => `<li>${esc(c)}</li>`).join("")}</ul></section>
    <section><h4>WHAT MAY HELP</h4><ul>${b.help.map(c => `<li>${esc(c)}</li>`).join("")}</ul></section>
    <p class="disclaimer">General information only, not a diagnosis. See a doctor if a change lasts, or if you notice blood, black stool or severe pain.</p>`;
  $("#sheet").hidden = false;
}
$("#sheet-close").onclick = () => { $("#sheet").hidden = true; };
$("#sheet").onclick = e => { if (e.target.id === "sheet") $("#sheet").hidden = true; };

/* ---------- chat ---------- */
function bubble(role, html) {
  const log = $("#chat-log");
  const div = document.createElement("div");
  div.innerHTML = role === "bot"
    ? `<div class="msg__wrap"><span class="bot"></span><div class="msg msg--bot"><div>${html}</div></div></div>`
    : `<div class="msg msg--user">${html}</div>`;
  const node = div.firstElementChild;
  if (role === "user") node.style.alignSelf = "flex-end";
  log.appendChild(node);
  log.scrollTop = log.scrollHeight;
  return node;
}

function resetChat() {
  $("#chat-log").innerHTML = "";
  $("#suggest").hidden = false;
}

function openChat() {
  $("#chat").hidden = false;
  if (!$("#chat-log").children.length)
    bubble("bot", `Hi ${esc(displayName(state.user))}! I can help explain your scores, trends, or anything unusual I've spotted. What would you like to know?`);
  setTimeout(() => $("#chat-input").focus(), 50);
}

async function ask(q) {
  q = q.trim();
  if (!q) return;
  $("#suggest").hidden = true;
  bubble("user", esc(q));
  const typing = bubble("bot", `<span class="msg--typing">Thinking…</span>`);
  try {
    const r = await api("/api/ask", { method: "POST", body: JSON.stringify({ user: state.user, question: q }) });
    $(".msg--bot > div", typing).innerHTML = `${esc(r.text)}<small>Answered by ${esc(SOURCE_TEXT[r.source] || r.source)} · not a diagnosis</small>`;
  } catch (e) {
    $(".msg--bot > div", typing).textContent = e.message;
  }
  $("#chat-log").scrollTop = $("#chat-log").scrollHeight;
}

$("#open-chat").onclick = openChat;
$("#close-chat").onclick = () => { $("#chat").hidden = true; };
$("#chat-form").onsubmit = e => { e.preventDefault(); const i = $("#chat-input"); ask(i.value); i.value = ""; };
$$("#suggest button").forEach(b => b.onclick = () => ask(b.textContent));

if ("serviceWorker" in navigator && window.isSecureContext) navigator.serviceWorker.register("sw.js").catch(() => {});

if (store.get("pp_token", null)) {
  state.user = store.get("pp_user", null) || account()?.member || null;
  loadServerConfig().then(load).catch(e => { $("#insight").textContent = e.message; });
} else {
  showAuth("login");
}
