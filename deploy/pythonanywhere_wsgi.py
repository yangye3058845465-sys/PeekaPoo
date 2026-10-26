# Paste into PythonAnywhere: Web tab -> "WSGI configuration file". Replace YOUR_USERNAME.
import os
import sys

PROJECT = "/home/YOUR_USERNAME/PeekaPoo-system"
sys.path.insert(0, PROJECT)

os.environ["PEEKAPOO_PUBLIC_DEMO"] = "1"  # every sign-up gets its own demo data and sees only itself
os.environ["PEEKAPOO_DB_PATH"] = PROJECT + "/data/public.db"

from dashboard.app import app as application  # noqa: E402
