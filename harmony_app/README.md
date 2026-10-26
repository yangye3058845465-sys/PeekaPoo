# PeekaPoo HarmonyOS App

Native ArkTS / ArkUI app (Stage model, API 12 / HarmonyOS NEXT 5.0+) for PeekaPoo.
It talks to the PeekaPoo hub (`dashboard/app.py`) over the local network.

## Screens

| Page | File |
|---|---|
| Log in | `entry/src/main/ets/pages/Login.ets` |
| Sign up (name, email, password, device button 1–4, consent) | `entry/src/main/ets/pages/Register.ets` |
| Home / Data / Alerts / Profile tabs | `entry/src/main/ets/pages/Main.ets` + `components/*Tab.ets` |
| AI assistant chat | `entry/src/main/ets/pages/Chat.ets` |

Shared code: `common/Api.ets` (HTTP), `common/Session.ets` (login state via Preferences),
`common/Models.ets` (JSON types), `common/Bristol.ets` (Bristol scale notes).

## Run

1. Start the hub on the PC (or the Atlas board):
   ```bash
   python tools/seed_demo_history.py --user user1 --days 14
   python tools/seed_demo_history.py --user user2 --days 14 --scenario constipation_gas
   python dashboard/app.py          # listens on 0.0.0.0:8000
   ```
2. Open this `harmony_app` folder in **DevEco Studio** (File → Open). Let it sync and download the SDK if asked.
3. Run on the emulator (Tools → Device Manager) or a real phone with HarmonyOS NEXT.
   For a real phone: File → Project Structure → Signing Configs → tick *Automatically generate signature*.
4. On the login page tap **Change** next to *Hub* and enter the PC's address, e.g. `http://192.168.1.23:8000`.
   The phone/emulator and the PC must be on the same network, and Windows Firewall must allow Python.

Demo account (already in `data/peekapoo.db` on the dev PC): `demo@peekapoo.app` / `peekapoo123` → device button 2.
Or tap **Sign up** to create a new one.

## Hub API used

| Endpoint | Purpose |
|---|---|
| `POST /api/register` | create account → token |
| `POST /api/login` | log in → token |
| `POST /api/logout` | revoke token |
| `GET /api/app?user=` | everything the tabs show |
| `POST /api/ask` | AI assistant answer |

The token is sent as `Authorization: Bearer <token>`. Accounts live in the hub's SQLite (`peekapoo/accounts.py`,
passwords hashed with werkzeug, tokens stored as SHA-256).
