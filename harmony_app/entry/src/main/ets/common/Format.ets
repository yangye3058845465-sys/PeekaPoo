const DAYS: string[] = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTHS: string[] = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

const FLAG_TITLE: Record<string, string> = {
  'HARD_STOOL': 'Hard stools',
  'LOOSE_STOOL': 'Loose stools',
  'LOW_HYDRATION': 'Low hydration',
  'NO_BOWEL_MOVEMENT': 'No bowel movement',
  'GAS_NH3': 'Ammonia above your baseline',
  'GAS_H2S': 'Sulphide gas above your baseline',
  'GAS_VOC': 'VOC above your baseline',
  'GAS_CH4': 'Methane above your baseline',
  'GAS_H2': 'Hydrogen above your baseline'
};

const LEVEL_TEXT: Record<string, string> = {
  'normal': 'Everything looks within your usual range.',
  'watch': "Something has changed for a few days. We'll keep watching.",
  'consult': 'A pattern has lasted several days. Consider talking to a doctor.'
};

const SOURCE_TEXT: Record<string, string> = {
  'template': 'on-device rules',
  'rule': 'safety rule',
  'llamacpp': 'Qwen2.5-0.5B on Atlas',
  'transformers': 'Qwen2.5-0.5B'
};

function pad(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

function parseDay(day: string): Date {
  const p = day.split('-');
  return new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]), 12, 0, 0);
}

export function weekday(day: string): string {
  return DAYS[parseDay(day).getDay()];
}

export function shortDay(day: string): string {
  const d = parseDay(day);
  return `${DAYS[d.getDay()]} ${MONTHS[d.getMonth()]} ${d.getDate()}`;
}

export function fmtTime(ts: number): string {
  const d = new Date(ts * 1000);
  return `${MONTHS[d.getMonth()]} ${d.getDate()}, ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export function capitalize(s: string): string {
  return s.length > 0 ? s.charAt(0).toUpperCase() + s.substring(1) : s;
}

export function flagTitle(code: string): string {
  return FLAG_TITLE[code] ?? code;
}

export function levelText(level: string): string {
  return LEVEL_TEXT[level] ?? '';
}

export function sourceText(source: string): string {
  return SOURCE_TEXT[source] ?? source;
}

export function hydrationLabel(s: number): string {
  if (s >= 80) {
    return 'Well hydrated';
  }
  if (s >= 65) {
    return 'Good';
  }
  return s >= 50 ? 'Slightly low today' : 'Low, drink some water';
}

export function digestiveLabel(t: number): string {
  let feel = 'Typical range';
  if (t <= 2) {
    feel = 'On the hard side';
  } else if (t >= 6) {
    feel = 'On the loose side';
  } else if (t === 4) {
    feel = 'Well formed';
  }
  return `Type ${t} · ${feel}`;
}

export function greeting(): string {
  const h = new Date().getHours();
  if (h < 12) {
    return 'Good morning';
  }
  return h < 18 ? 'Good afternoon' : 'Good evening';
}

// Home alert module: plain-language version of each triage flag. The level itself comes from the hub's rules.
const ALERT_TEXT: Record<string, string[]> = {
  'GAS_NH3': ['Unusual ammonia level', 'Ammonia from your visits has stayed above your personal baseline for {n} days. Drink more water, and consult a doctor if you are feeling uncomfortable.'],
  'GAS_H2S': ['Unusual sulphide gas', 'Sulphide gas has stayed above your personal baseline for {n} days. Notice whether it follows particular foods, and consult a doctor if you are feeling uncomfortable.'],
  'GAS_VOC': ['Unusual VOC signal', 'The VOC signal has stayed above your personal baseline for {n} days. Consult a doctor if you are feeling uncomfortable.'],
  'GAS_CH4': ['Unusual methane level', 'Methane has stayed above your personal baseline for {n} days. Consult a doctor if you are feeling uncomfortable.'],
  'GAS_H2': ['Unusual hydrogen level', 'Hydrogen has stayed above your personal baseline for {n} days. Consult a doctor if you are feeling uncomfortable.'],
  'HARD_STOOL': ['Hard stools', 'Your stools have been hard (Bristol 1–2) for {n} days in a row. Drink water through the day and add fibre such as oats, fruit and vegetables.'],
  'LOOSE_STOOL': ['Loose stools', 'Your stools have been loose (Bristol 6–7) for {n} days in a row. Sip fluids often and choose simple, bland meals.'],
  'LOW_HYDRATION': ['Low hydration', 'Your urine has been darker than usual for {n} days. Keep a water bottle nearby and drink regularly.'],
  'NO_BOWEL_MOVEMENT': ['No bowel movement', 'No bowel movement has been recorded for {n} days. Try a regular toilet time after meals and some light walking.']
};

export function alertTitle(code: string): string {
  const t = ALERT_TEXT[code];
  return t !== undefined ? t[0] : flagTitle(code);
}

export function alertText(code: string, detail: string): string {
  const t = ALERT_TEXT[code];
  if (t === undefined) {
    return capitalize(detail);
  }
  const m = detail.match(/(\d+)/);
  return t[1].replace('{n}', m !== null ? m[1] : 'several');
}
