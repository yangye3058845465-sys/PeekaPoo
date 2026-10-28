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
