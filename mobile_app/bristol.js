// Bristol Stool Scale: illustrations + plain-language notes (educational, not a diagnosis)
const BROWN = "#a8643a", BROWN_D = "#7c4426", BROWN_L = "#c98a55";

function blob(cx, cy, r, fill = BROWN) {
  return `<circle cx="${cx}" cy="${cy}" r="${r}" fill="${fill}" stroke="${BROWN_D}" stroke-width="1.5"/>`;
}

const BSS_SVG = {
  1: blob(22, 40, 9) + blob(42, 34, 8) + blob(60, 44, 9) + blob(78, 36, 8) + blob(34, 58, 8) + blob(54, 62, 9) + blob(74, 58, 7),
  2: `<path d="M12 52c0-10 8-14 16-12 4-8 14-8 18-2 6-6 16-5 20 1 8-3 18 2 20 10 3 9-4 16-12 15-4 6-14 6-18 1-6 5-16 5-20-1-8 4-18 2-21-6-2-2-3-4-3-6z" fill="${BROWN}" stroke="${BROWN_D}" stroke-width="1.5"/>
      <circle cx="30" cy="50" r="3" fill="${BROWN_D}" opacity=".35"/><circle cx="52" cy="46" r="3" fill="${BROWN_D}" opacity=".35"/><circle cx="72" cy="52" r="3" fill="${BROWN_D}" opacity=".35"/>`,
  3: `<rect x="10" y="38" width="80" height="26" rx="13" fill="${BROWN}" stroke="${BROWN_D}" stroke-width="1.5"/>
      <path d="M28 40l3 8M44 40l-2 9M60 42l3 7M74 40l-2 8M36 62l2-7M66 62l-2-6" stroke="${BROWN_D}" stroke-width="1.6" stroke-linecap="round"/>`,
  4: `<path d="M10 58c14-18 30-18 44-8s30 10 38-6" fill="none" stroke="${BROWN_D}" stroke-width="17" stroke-linecap="round"/>
      <path d="M10 58c14-18 30-18 44-8s30 10 38-6" fill="none" stroke="${BROWN}" stroke-width="14" stroke-linecap="round"/>
      <path d="M22 50c8-6 16-7 24-3" fill="none" stroke="${BROWN_L}" stroke-width="3" stroke-linecap="round"/>`,
  5: `<ellipse cx="28" cy="40" rx="15" ry="9" fill="${BROWN}" stroke="${BROWN_D}" stroke-width="1.5"/>
      <ellipse cx="66" cy="38" rx="14" ry="8" fill="${BROWN}" stroke="${BROWN_D}" stroke-width="1.5"/>
      <ellipse cx="44" cy="60" rx="16" ry="9" fill="${BROWN}" stroke="${BROWN_D}" stroke-width="1.5"/>
      <ellipse cx="78" cy="60" rx="10" ry="7" fill="${BROWN}" stroke="${BROWN_D}" stroke-width="1.5"/>`,
  6: `<path d="M8 52l6-6 4 3 6-8 7 4 5-5 8 5 6-3 4 4 9-5 5 6 8-2 4 6 6 1-3 7-7 2-4 5-8-2-6 4-7-3-6 4-6-4-8 3-4-5-8 1-3-6-6-2z" fill="${BROWN_L}" stroke="${BROWN_D}" stroke-width="1.5" stroke-linejoin="round"/>
      <path d="M58 30l7-4 6 3 8-1 3 5-6 4-9-1-6 1z" fill="${BROWN_L}" stroke="${BROWN_D}" stroke-width="1.5" stroke-linejoin="round"/>`,
  7: `<path d="M10 56c4-12 18-10 24-14 8-6 22-4 30 0 10 4 24 2 26 12 2 10-8 12-16 14-10 2-18 0-28 2-12 2-26 0-34-4-4-2-3-6-2-10z" fill="#d9a36a" stroke="#b07a45" stroke-width="1.5"/>
      <ellipse cx="44" cy="54" rx="16" ry="5" fill="#e8bb86" opacity=".7"/>`,
};

const BSS = {
  1: { short: "Separate hard lumps", title: "Separate hard lumps, like nuts",
       means: "Often a sign of constipation. Stool has stayed in the large intestine for a long time, so most of its water has been absorbed.",
       causes: ["Low fibre intake", "Not drinking enough water", "Little physical activity", "Ignoring the urge to go"],
       help: ["Drink water regularly through the day", "Add fibre gradually: oats, fruit, vegetables", "Daily walking or light exercise", "Keep a regular toilet routine"] },
  2: { short: "Lumpy and sausage-like", title: "Lumpy and sausage-like",
       means: "Usually mild constipation. Stool is formed but hard and can be difficult to pass.",
       causes: ["Low fibre or fluid intake", "Change in routine or travel", "Sitting for long periods"],
       help: ["Increase fluids and fibre gradually", "Stay active through the day", "Don't hold it in when you feel the urge"] },
  3: { short: "Sausage with cracks", title: "Sausage-shaped with cracks on the surface",
       means: "Within the typical range. Stool is well formed and passes without much effort.",
       causes: ["A balanced diet and normal transit time"],
       help: ["Keep up your current routine of water, fibre and movement"] },
  4: { short: "Smooth and soft", title: "Like a smooth, soft sausage or snake",
       means: "Often considered the ideal form. Transit time and water content are well balanced.",
       causes: ["Good hydration, enough fibre and a regular routine"],
       help: ["Nothing to change: keep doing what you're doing"] },
  5: { short: "Soft blobs", title: "Soft blobs with clear-cut edges",
       means: "At the soft end of the typical range. Can reflect a high-fibre diet or slightly faster transit.",
       causes: ["High fibre intake", "Eating several meals a day", "Mild, temporary changes in diet"],
       help: ["Usually nothing needed", "Notice whether it follows particular foods"] },
  6: { short: "Mushy, ragged edges", title: "Mushy consistency with ragged edges",
       means: "Often considered mild diarrhoea. Stool passed through the large intestine too quickly for enough water to be absorbed.",
       causes: ["Temporary digestive upset, e.g. a change in diet", "Recent high intake of spicy or very fatty food", "Food intolerance or a mild infection", "Stress or anxiety"],
       help: ["Sip water or oral rehydration drinks often", "Choose simple, bland meals for a day or two", "Rest and reduce stress"] },
  7: { short: "Liquid, no solid pieces", title: "Liquid consistency with no solid pieces",
       means: "Diarrhoea. The body is losing a lot of fluid, so staying hydrated matters most.",
       causes: ["Infection or food poisoning", "Food intolerance", "Some medicines"],
       help: ["Replace fluids often with water or rehydration drinks", "Eat light, bland food", "Seek medical advice if it lasts more than 2 days, or sooner if you feel unwell"] },
};

function bssImage(t, withTag = true) {
  return `<div class="bss__img">${withTag ? `<span class="bss__tag">TYPE ${t}</span>` : ""}
    <svg viewBox="0 0 100 100" aria-hidden="true">${BSS_SVG[t]}</svg></div>`;
}
