import json
import sqlite3
import time
from pathlib import Path


class SessionStore:
    def __init__(self, path):
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        self.db = sqlite3.connect(path, check_same_thread=False)
        self.db.execute("""CREATE TABLE IF NOT EXISTS sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user TEXT NOT NULL,
            start_ts REAL NOT NULL,
            record TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0)""")
        self.db.execute("CREATE INDEX IF NOT EXISTS idx_user_ts ON sessions(user, start_ts)")
        self.db.commit()

    def add(self, record):
        cur = self.db.execute("INSERT INTO sessions(user, start_ts, record) VALUES (?, ?, ?)",
                              (record["user"], record["start_ts"], json.dumps(record)))
        self.db.commit()
        return cur.lastrowid

    def update(self, row_id, record):
        self.db.execute("UPDATE sessions SET record=? WHERE id=?", (json.dumps(record), row_id))
        self.db.commit()

    def history(self, user, days=30):
        since = time.time() - days * 86400
        rows = self.db.execute("SELECT record FROM sessions WHERE user=? AND start_ts>=? ORDER BY start_ts",
                               (user, since)).fetchall()
        return [json.loads(r[0]) for r in rows]

    def users(self):
        return [r[0] for r in self.db.execute("SELECT DISTINCT user FROM sessions ORDER BY user")]

    def unsynced(self, limit=50):
        rows = self.db.execute("SELECT id, record FROM sessions WHERE synced=0 ORDER BY id LIMIT ?", (limit,))
        return [(i, json.loads(r)) for i, r in rows.fetchall()]

    def mark_synced(self, row_id):
        self.db.execute("UPDATE sessions SET synced=1 WHERE id=?", (row_id,))
        self.db.commit()
