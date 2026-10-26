// Bristol Stool Scale notes: educational, not a diagnosis

export interface BssInfo {
  short: string;
  title: string;
  means: string;
  causes: string[];
  help: string[];
}

export const BSS: BssInfo[] = [
  {
    short: 'Separate hard lumps',
    title: 'Separate hard lumps, like nuts',
    means: 'Often a sign of constipation. Stool has stayed in the large intestine for a long time, so most of its water has been absorbed.',
    causes: ['Low fibre intake', 'Not drinking enough water', 'Little physical activity', 'Ignoring the urge to go'],
    help: ['Drink water regularly through the day', 'Add fibre gradually: oats, fruit, vegetables', 'Daily walking or light exercise', 'Keep a regular toilet routine']
  },
  {
    short: 'Lumpy and sausage-like',
    title: 'Lumpy and sausage-like',
    means: 'Usually mild constipation. Stool is formed but hard and can be difficult to pass.',
    causes: ['Low fibre or fluid intake', 'Change in routine or travel', 'Sitting for long periods'],
    help: ['Increase fluids and fibre gradually', 'Stay active through the day', "Don't hold it in when you feel the urge"]
  },
  {
    short: 'Sausage with cracks',
    title: 'Sausage-shaped with cracks on the surface',
    means: 'Within the typical range. Stool is well formed and passes without much effort.',
    causes: ['A balanced diet and normal transit time'],
    help: ['Keep up your current routine of water, fibre and movement']
  },
  {
    short: 'Smooth and soft',
    title: 'Like a smooth, soft sausage or snake',
    means: 'Often considered the ideal form. Transit time and water content are well balanced.',
    causes: ['Good hydration, enough fibre and a regular routine'],
    help: ["Nothing to change: keep doing what you're doing"]
  },
  {
    short: 'Soft blobs',
    title: 'Soft blobs with clear-cut edges',
    means: 'At the soft end of the typical range. Can reflect a high-fibre diet or slightly faster transit.',
    causes: ['High fibre intake', 'Eating several meals a day', 'Mild, temporary changes in diet'],
    help: ['Usually nothing needed', 'Notice whether it follows particular foods']
  },
  {
    short: 'Mushy, ragged edges',
    title: 'Mushy consistency with ragged edges',
    means: 'Often considered mild diarrhoea. Stool passed through the large intestine too quickly for enough water to be absorbed.',
    causes: ['Temporary digestive upset, e.g. a change in diet', 'Recent high intake of spicy or very fatty food', 'Food intolerance or a mild infection', 'Stress or anxiety'],
    help: ['Sip water or oral rehydration drinks often', 'Choose simple, bland meals for a day or two', 'Rest and reduce stress']
  },
  {
    short: 'Liquid, no solid pieces',
    title: 'Liquid consistency with no solid pieces',
    means: 'Diarrhoea. The body is losing a lot of fluid, so staying hydrated matters most.',
    causes: ['Infection or food poisoning', 'Food intolerance', 'Some medicines'],
    help: ['Replace fluids often with water or rehydration drinks', 'Eat light, bland food', 'Seek medical advice if it lasts more than 2 days, or sooner if you feel unwell']
  }
];

export const BSS_IMG: Resource[] = [
  $r('app.media.bss_1'), $r('app.media.bss_2'), $r('app.media.bss_3'), $r('app.media.bss_4'),
  $r('app.media.bss_5'), $r('app.media.bss_6'), $r('app.media.bss_7')
];

export const BSS_NOTE: string =
  'General information only, not a diagnosis. See a doctor if a change lasts, or if you notice blood, black stool or severe pain.';
