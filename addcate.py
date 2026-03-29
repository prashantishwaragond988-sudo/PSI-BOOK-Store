import sqlite3
conn = sqlite3.connect("users.db")
cur = conn.cursor()

cur.execute("INSERT INTO categories(name) VALUES('Programming')")
cur.execute("INSERT INTO categories(name) VALUES('Science')")
cur.execute("INSERT INTO categories(name) VALUES('Fiction')")

conn.commit()
conn.close()
