
import sqlite3
conn = sqlite3.connect("users.db")
cur = conn.cursor()

cur.execute("UPDATE users SET is_admin = 1 WHERE email = 'gamerpsi328@gmail.com'")
conn.commit()
conn.close()
exit()
