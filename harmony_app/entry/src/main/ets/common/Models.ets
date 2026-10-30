// Shapes of the JSON returned by dashboard/app.py

export interface Flag {
  code: string;
  level: string;
  detail: string;
}

export interface Triage {
  level: string;
  flags: Flag[];
}

export interface DigestiveInfo {
  score: number;
  bristol_type: number;
  condition: string;
}

export interface HydrationInfo {
  score: number;
  level: number;
}

// colour / quantity are null when the hub has not measured them
export interface StoolInfo {
  ts: number;
  bristol_type: number;
  consistency: string;
  colour: string | null;
  quantity: string | null;
}

export interface TrendDay {
  day: string;
  digestive: number | null;
  hydration: number | null;
}

export interface Dist {
  counts: Record<string, number>;
  share: Record<string, number>;
  n?: number;
}

export interface LookRow {
  label: string;
  pct: number;
}

export interface LookDist {
  n: number;
  rows: LookRow[];
}

// share of stool visits per colour / consistency / quantity
export interface Look {
  colour: LookDist;
  consistency: LookDist;
  quantity: LookDist;
}

export interface GasDay {
  day: string;
  NH3: number | null;
  VOC: number | null;
  z_NH3: number | null;
  z_VOC: number | null;
}

// today's personal normal for a gas channel: window median and the reading that counts as high
export interface GasRef {
  median: number;
  alert: number;
}

export interface GasRefs {
  NH3: GasRef | null;
  VOC: GasRef | null;
}

export interface Visit {
  start_ts: number;
  total_time_s: number | null;
  has_stool: boolean;
  has_urine: boolean;
  bristol_type: number | null;
  condition: string | null;
  hydration_score: number | null;
  digestive_score: number | null;
}

export interface SystemInfo {
  vision_backend: string;
  llm_backend: string;
  cloud: boolean;
  synthetic: boolean;
}

export interface AppData {
  user: string;
  users: string[];
  visits: number;
  last_ts: number | null;
  digestive: DigestiveInfo | null;
  hydration: HydrationInfo | null;
  stool: StoolInfo | null;
  insight: string | null;
  disclaimer: string;
  triage: Triage;
  gas_warming_up: boolean;
  trend: TrendDay[];
  bristol: Dist;
  condition: Dist;
  look: Look;
  urine: Dist;
  gas7: GasDay[];
  gas_ref?: GasRefs;
  z_threshold: number;
  recent: Visit[];
  system: SystemInfo;
}

export interface Account {
  token: string;
  email: string;
  name: string;
  member: string;
}

export interface AskReply {
  text: string;
  source: string;
  disclaimer: string;
}

export interface ErrorReply {
  error: string;
}

export class ChatMsg {
  id: number;
  role: string;
  text: string;
  note: string;

  constructor(id: number, role: string, text: string, note: string) {
    this.id = id;
    this.role = role;
    this.text = text;
    this.note = note;
  }
}

export interface ServerConfig {
  public_demo: boolean;
  scenarios?: string[];
}
