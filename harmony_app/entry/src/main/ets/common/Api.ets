import { http } from '@kit.NetworkKit';
import { Session } from './Session';
import { Account, AppData, AskReply, ErrorReply, ServerConfig } from './Models';

interface LoginBody {
  email: string;
  password: string;
}

interface RegisterBody {
  name: string;
  email: string;
  password: string;
  member: string;
}

interface AskBody {
  user: string;
  question: string;
}

export class AuthError extends Error {
}

function errorOf(text: string, code: number): string {
  try {
    const r = JSON.parse(text) as ErrorReply;
    if (r && r.error) {
      return r.error;
    }
  } catch (e) {
    // not JSON
  }
  return `Server error (${code})`;
}

async function call(path: string, method: http.RequestMethod, body: Object | null): Promise<string> {
  const header: Record<string, string> = { 'Content-Type': 'application/json' };
  const token = Session.get('token', '');
  if (token.length > 0) {
    header['Authorization'] = 'Bearer ' + token;
  }
  const opts: http.HttpRequestOptions = {
    method: method,
    header: header,
    connectTimeout: 8000,
    readTimeout: 60000,
    expectDataType: http.HttpDataType.STRING
  };
  if (body !== null) {
    opts.extraData = JSON.stringify(body);
  }
  const req = http.createHttp();
  let resp: http.HttpResponse;
  try {
    resp = await req.request(Session.hub() + path, opts);
  } catch (e) {
    req.destroy();
    throw new Error(`Can't reach your PeekaPoo hub at ${Session.hub()}. Check the address and that you're on the same Wi-Fi.`);
  }
  req.destroy();
  const text = resp.result as string;
  if (resp.responseCode === 401) {
    throw new AuthError(errorOf(text, resp.responseCode));
  }
  if (resp.responseCode >= 400) {
    throw new Error(errorOf(text, resp.responseCode));
  }
  return text;
}

export class Api {
  static async login(email: string, password: string): Promise<Account> {
    const b: LoginBody = { email: email, password: password };
    return JSON.parse(await call('/api/login', http.RequestMethod.POST, b)) as Account;
  }

  static async register(name: string, email: string, password: string, member: string): Promise<Account> {
    const b: RegisterBody = { name: name, email: email, password: password, member: member };
    return JSON.parse(await call('/api/register', http.RequestMethod.POST, b)) as Account;
  }

  static async logout(): Promise<void> {
    await call('/api/logout', http.RequestMethod.POST, null);
  }

  static async deleteAccount(): Promise<void> {
    await call('/api/delete_account', http.RequestMethod.POST, null);
  }

  // public demo hubs give every sign-up its own data, so there is no device button to pick
  static async config(): Promise<ServerConfig> {
    try {
      return JSON.parse(await call('/api/config', http.RequestMethod.GET, null)) as ServerConfig;
    } catch (e) {
      const fallback: ServerConfig = { public_demo: false };
      return fallback;
    }
  }

  static async app(member: string): Promise<AppData> {
    return JSON.parse(await call('/api/app?user=' + encodeURIComponent(member), http.RequestMethod.GET, null)) as AppData;
  }

  static async ask(member: string, question: string): Promise<AskReply> {
    const b: AskBody = { user: member, question: question };
    return JSON.parse(await call('/api/ask', http.RequestMethod.POST, b)) as AskReply;
  }
}
