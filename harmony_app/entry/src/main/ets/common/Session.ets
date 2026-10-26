import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Account } from './Models';

// Address of the PeekaPoo hub: the public demo server, or a local hub (Atlas board / PC running dashboard/app.py)
export const DEFAULT_HUB: string = 'https://peekapoo.pythonanywhere.com';

const KEYS: string[] = ['token', 'name', 'email', 'member', 'view'];

export class Session {
  private static prefs: preferences.Preferences | null = null;

  static init(ctx: common.Context): void {
    Session.prefs = preferences.getPreferencesSync(ctx, { name: 'peekapoo' });
  }

  static get(key: string, def: string): string {
    if (Session.prefs === null) {
      return def;
    }
    return Session.prefs.getSync(key, def) as string;
  }

  static set(key: string, value: string): void {
    if (Session.prefs === null) {
      return;
    }
    Session.prefs.putSync(key, value);
    Session.prefs.flush();
  }

  static hub(): string {
    return Session.get('hub', DEFAULT_HUB);
  }

  static setHub(value: string): void {
    let h = value.trim();
    while (h.endsWith('/')) {
      h = h.substring(0, h.length - 1);
    }
    if (h.length > 0 && !h.startsWith('http')) {
      h = 'http://' + h;
    }
    Session.set('hub', h.length > 0 ? h : DEFAULT_HUB);
  }

  static loggedIn(): boolean {
    return Session.get('token', '').length > 0;
  }

  static saveAccount(a: Account): void {
    Session.set('token', a.token);
    Session.set('name', a.name);
    Session.set('email', a.email);
    Session.set('member', a.member);
    Session.set('view', a.member);
  }

  static clearAccount(): void {
    if (Session.prefs === null) {
      return;
    }
    for (const k of KEYS) {
      Session.prefs.deleteSync(k);
    }
    Session.prefs.flush();
  }
}
