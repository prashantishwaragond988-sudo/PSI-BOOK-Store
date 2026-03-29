
import sqlite3
conn = sqlite3.connect("users.db")
cur = conn.cursor()
cur.execute("ALTER TABLE books ADD COLUMN category_id INTEGER")
conn.close()
