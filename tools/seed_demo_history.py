import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from peekapoo.config import CONFIG  # noqa: E402
from peekapoo.demo import SCENARIOS, seed_history  # noqa: E402
from peekapoo.store import SessionStore  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--user", default=CONFIG.default_user)
    ap.add_argument("--days", type=int, default=14)
    ap.add_argument("--scenario", choices=SCENARIOS, default="healthy")
    args = ap.parse_args()

    seed_history(SessionStore(CONFIG.db_path), args.user, args.days, args.scenario)
    print(f"seeded {args.days} synthetic days for {args.user} ({args.scenario}) into {CONFIG.db_path}")


if __name__ == "__main__":
    main()
