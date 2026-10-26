import hashlib
import secrets
import sqlite3
import time
from pathlib import Path

from werkzeug.security import check_password_hash, generate_password_hash


def _digest(token):
    return hashlib.sha256(token.encode()).hexdigest()


class AccountStore:
    def __init__(self, path):
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        self.db = sqlite3.connect(path, check_same_thread=False)
        self.db.execute("""CREATE TABLE IF NOT EXISTS accounts (
            email TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            member TEXT NOT NULL,
            pw_hash TEXT NOT NULL,
            created REAL NOT NULL)""")
        self.db.execute("""CREATE TABLE IF NOT EXISTS tokens (
            token_hash TEXT PRIMARY KEY,
            email TEXT NOT NULL,
            created REAL NOT NULL)""")
        self.db.commit()

    def register(self, email, name, password, member):
        if self.db.execute("SELECT 1 FROM accounts WHERE email=?", (email,)).fetchone():
            raise ValueError("An account with this email already exists")
        self.db.execute("INSERT INTO accounts VALUES (?, ?, ?, ?, ?)",
                        (email, name, member, generate_password_hash(password), time.time()))
        self.db.commit()
        return self._issue(email)

    def login(self, email, password):
        row = self.db.execute("SELECT pw_hash FROM accounts WHERE email=?", (email,)).fetchone()
        if not row or not check_password_hash(row[0], password):
            raise ValueError("Wrong email or password")
        return self._issue(email)

    def _issue(self, email):
        token = secrets.token_urlsafe(32)
        self.db.execute("INSERT INTO tokens VALUES (?, ?, ?)", (_digest(token), email, time.time()))
        self.db.commit()
        return token

    def lookup(self, token):
        row = self.db.execute("""SELECT a.email, a.name, a.member FROM tokens t
                                 JOIN accounts a ON a.email = t.email WHERE t.token_hash=?""",
                              (_digest(token),)).fetchone()
        return row and {"email": row[0], "name": row[1], "member": row[2]}

    def logout(self, token):
        self.db.execute("DELETE FROM tokens WHERE token_hash=?", (_digest(token),))
        self.db.commit()

    def delete(self, email):
        self.db.execute("DELETE FROM tokens WHERE email=?", (email,))
        self.db.execute("DELETE FROM accounts WHERE email=?", (email,))
        self.db.commit()
