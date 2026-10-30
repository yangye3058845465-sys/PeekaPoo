export class C {
  static readonly BG: string = '#120d2b';
  static readonly BG2: string = '#0d0921';
  static readonly CARD: string = '#1d1739';
  static readonly LINE: string = '#2c2648';
  static readonly TEXT: string = '#f4f2ff';
  static readonly MUTED: string = '#9a94b8';
  static readonly LIME: string = '#c6f432';
  static readonly MINT: string = '#bfe0d4';
  static readonly CREAM: string = '#e8f3da';
  static readonly INK: string = '#1b1240';
  static readonly SLATE: string = '#48557c';
  static readonly RED: string = '#ff6b6b';
  static readonly AMBER: string = '#ffb547';
  static readonly GREEN: string = '#5ee0a0';
  static readonly BLUE: string = '#6f8fbf';
}

export function levelColor(level: string): string {
  if (level === 'consult') {
    return C.RED;
  }
  return level === 'watch' ? C.AMBER : C.GREEN;
}

// stool colour swatches (Home 'Last stool' card and Data colour chip)
export const STOOL_HEX: Record<string, string> = {
  'Brown': '#8a5a3b',
  'Light brown': '#c08a5c',
  'Dark brown': '#4f3020',
  'Green-ish': '#6f7d3c',
  'Yellow': '#d4b44a',
  'Black': '#1d1714',
  'Red-tinged': '#9b3b32'
};

// hydration scale the camera grades; the hub's urine levels 1-8 fold into these six tubes
export const URINE_TUBES: string[] = ['Clear', 'Light yellow', 'Yellow', 'Dark yellow', 'Amber', 'Brown'];
export const URINE_HEX: string[] = ['#f4f2ea', '#fbf3b5', '#f9ea6b', '#f3cf35', '#f2a528', '#d48a4c'];
export const LEVEL_TUBE: number[] = [0, 0, 1, 2, 3, 3, 4, 4, 5];

export class UrineColour {
  name: string;
  hex: string;
  food: string;
  doctor: string;

  constructor(name: string, hex: string, food: string, doctor: string) {
    this.name = name;
    this.hex = hex;
    this.food = food;
    this.doctor = doctor;
  }
}

// reference guide only: the camera does not classify these colours
export const UNUSUAL_URINE: UrineColour[] = [
  new UrineColour('Pink / Red', '#d9534f', 'Beetroot, red dragon fruit, blackberries or rhubarb.',
    "If you haven't eaten any of these, red can mean blood in the urine. Please see a doctor."),
  new UrineColour('Green', '#9fc63b', 'Asparagus or food colouring.',
    'Some medicines and test dyes do this too. See a doctor if it lasts, or if peeing burns.'),
  new UrineColour('Blue', '#4f9a9e', 'Food colouring.',
    "Usually dyes from medicines or medical tests. Ask a doctor or pharmacist if you're unsure."),
  new UrineColour('Dark brown', '#5b3a2e', 'Fava beans, rhubarb or aloe.',
    'Can come with severe dehydration or a liver or bile-duct problem. See a doctor if it lasts, especially with pale stool or yellow skin.'),
  new UrineColour('Black', '#1a1414', 'Rarely, food colouring.',
    'This is very uncommon. Please see a doctor.'),
  new UrineColour('Milky', '#f3e7a6', 'Protein-rich meals such as anchovies, herring or red meat.',
    'Can come with an infection or kidney stones. See a doctor if you also have pain, fever or burning.')
];
