

import sqlite3

conn = sqlite3.connect("users.db")
cur = conn.cursor()

cur.execute("""
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT,
    mobile TEXT,
    password TEXT,
    mobile_verified INTEGER DEFAULT 0,
    email_verified INTEGER DEFAULT 0,
    is_admin INTEGER DEFAULT 0
)
""")


conn.commit()
conn.close()
