import sqlite3

conn = sqlite3.connect("users.db")
cur = conn.cursor()

categories = ["Programming","Science","Fiction","Kids"]

for i in range(1,51):
    cur.execute("""
    INSERT INTO books(title,author,description,price,category,image)
    VALUES(?,?,?,?,?,?)
    """,(
        f"Book {i}",
        "Author "+str(i),
        "This is description of book "+str(i),
        200 + i*5,
        categories[i%4],
        f"https://covers.openlibrary.org/b/id/{8000000+i}-L.jpg"
    ))

conn.commit()
conn.close()

print("Books added!")
