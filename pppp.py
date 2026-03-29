from werkzeug.security import generate_password_hash, check_password_hash
from flask import Flask, render_template, request, redirect, session, jsonify
import sqlite3,random,time,smtplib,datetime
from flask import flash

from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

def send_email_otp(to_email, otp):

    sender_email = "gamerpsi328@gmail.com"
    app_password = "bywv qlrf xqwb vjcr"

    # Create message container
    msg = MIMEMultipart("alternative")
    msg["Subject"] = "🔐 Email Verification - PSI Book Store"
    msg["From"] = sender_email
    msg["To"] = to_email

    # Email body (HTML format)
    html = f"""
    <html>
        <body style="font-family: Arial; background-color:#f4f4f4; padding:20px;">
            <div style="background:white; padding:20px; border-radius:10px;">
                <h2 style="color:#11998e;">Email Verification</h2>
                <p>Dear User,</p>
                <p>Thank you for registering with <b>PSI Book Store</b>.</p>
                <p>Your One Time Password (OTP) is:</p>
                <h1 style="color:#38ef7d;">{otp}</h1>
                <p>This OTP is valid for <b>2 minutes</b>.</p>
                <p>If you did not request this, please ignore this email.</p>
                <br>
                <p>Regards,<br>PSI Book Store Team</p>
            </div>
        </body>
    </html>
    """

    msg.attach(MIMEText(html, "html"))

    server = smtplib.SMTP("smtp.gmail.com", 587)
    server.starttls()
    server.login(sender_email, app_password)
    server.send_message(msg)
    server.quit()


app = Flask(__name__)
app.secret_key = "secret123"

# ---------------- DB ----------------

def get_db():
    return sqlite3.connect("users.db")






# ---------------- REGISTER + OTP (YOUR SAME CODE) ----------------


@app.route("/register", methods=["GET","POST"])
def register():
    if request.method=="POST":
        session["email"]=request.form["email"]
        session["mobile"]=request.form["mobile"]
        session["password"]=request.form["password"]
        
        conn = get_db()
        cur = conn.cursor()

        cur.execute("SELECT * FROM users WHERE email=?", (request.form["email"],))
        existing = cur.fetchone()

        if existing:
            flash("Email already registered","error")
            return redirect("/register")

        
    
        # Generate EMAIL OTP directly
        email_otp = random.randint(100000, 999999)
        session["email_otp"] = email_otp
        session["email_otp_time"] = time.time()

        send_email_otp(session['email'], email_otp)
        print("Email OTP:", email_otp)  # optional for debugging

        return redirect("/verify-email")
        



    """otp=random.randint(100000,999999)
        session["mobile_otp"]=otp
        session["mobile_otp_time"]=time.time()

        print("Mobile OTP:",otp)

        print ("Sending sms otp",session["mobile"])
        print ("OTP",session["mobile_otp"])
        return redirect("/verify-mobile")"""
        
      
       
    return render_template("register.html")




"""
@app.route("/verify-mobile", methods=["GET","POST"])
def verify_mobile():
    if request.method == "POST":

        if time.time() - session["mobile_otp_time"] > 120:
            return "OTP Expired"

        if request.form["otp"] == str(session["mobile_otp"]):

            # generate EMAIL OTP
            email_otp = random.randint(100000, 999999)
            session["email_otp"] = email_otp
            session["email_otp_time"] = time.time()
            
            send_email_otp(session['email'],email_otp)

            print("Email OTP:", email_otp)

            return redirect("/verify-email")

        return "Wrong OTP"

    return render_template("otp_mobile.html")
"""

# ---------------- VERIFY EMAIL ----------------
@app.route("/verify-email", methods=["GET","POST"])
def verify_email():

    if request.method == "POST":

        if time.time() - session["email_otp_time"] > 120:
            flash("⏰ OTP expired","error")
            return redirect("/register")

        if request.form["otp"] == str(session["email_otp"]):

            conn = get_db()
            cur = conn.cursor()

            hashed_password = generate_password_hash(session["password"])

            cur.execute("""
            INSERT INTO users(email,mobile,password,mobile_verified,email_verified)
            VALUES(?,?,?,?,?)
            """,(session["email"],session["mobile"],hashed_password,1,1))

            conn.commit()
            conn.close()

            flash("🎉 Registration successful. Please login","success")
            return redirect("/login")

        else:
            flash("❌ Wrong OTP","error")

    return render_template("otp_email.html")


@app.route("/login", methods=["GET","POST"])
def login():
    if request.method=="POST":
        value=request.form["value"]
        password=request.form["password"]

        conn=get_db()
        cur=conn.cursor()

        cur.execute("""
        SELECT * FROM users WHERE (email=? OR mobile=?)
        AND mobile_verified=1 AND email_verified=1
        """,(value,value))

        user = cur.fetchone()

        if user and check_password_hash(user[3], password):
            session["user"] = value
            return redirect("/store")
        else:
            flash("Invalid email or password","error")
            return redirect("/login")


       

    return render_template("p1.html")


# ---------------- STORE PAGES ----------------

@app.route("/store")
def store():
    if "user" not in session:
        return redirect("/login")
    return render_template("index.html", user=session["user"])



# ---------------- BOOK API ----------------

@app.route("/api/books")
def get_books():

    conn = get_db()
    cur = conn.cursor()

    cur.execute("""
        SELECT books.id, books.title, books.author,
               books.description, books.price,
               categories.name, books.image
        FROM books
        LEFT JOIN categories
        ON books.category_id = categories.id
    """)

    data = cur.fetchall()
    conn.close()

    books = []

    for b in data:
        books.append({
            "id": b[0],
            "title": b[1],
            "author": b[2],
            "desc": b[3],
            "price": b[4],
            "category": b[5],
            "image": b[6]
        })

    return jsonify(books)




# ---------------- CART SYSTEM (FIXED) ----------------

@app.route("/api/cart/add", methods=["POST"])
def add_cart():
    if "user" not in session:
        return jsonify({"error":"login required"})

    book_id=request.json["book_id"]

    conn=get_db()
    cur=conn.cursor()

    cur.execute("SELECT * FROM cart WHERE user=? AND book_id=?",(session["user"],book_id))
    item=cur.fetchone()

    if item:
        cur.execute("UPDATE cart SET qty=qty+1 WHERE id=?",(item[0],))
    else:
        cur.execute("INSERT INTO cart(user,book_id,qty) VALUES(?,?,1)",(session["user"],book_id))

    conn.commit()
    conn.close()

    return jsonify({"msg":"added"})


@app.route("/api/cart/delete", methods=["POST"])
def delete_cart():
    book_id=request.json["book_id"]

    conn=get_db()
    cur=conn.cursor()

    cur.execute("DELETE FROM cart WHERE user=? AND book_id=?",(session["user"],book_id))

    conn.commit()
    conn.close()

    return jsonify({"msg":"deleted"})


@app.route("/api/cart")
def view_cart():
    conn=get_db()
    cur=conn.cursor()

    cur.execute("""
    SELECT books.id,books.title,books.price,cart.qty
    FROM cart JOIN books ON cart.book_id=books.id
    WHERE cart.user=?
    """,(session["user"],))

    rows=cur.fetchall()
    conn.close()

    total=0
    items=[]

    for r in rows:
        total+=r[2]*r[3]
        items.append({
            "id":r[0],
            "title":r[1],
            "price":r[2],
            "qty":r[3]
        })

    return jsonify({"items":items,"total":total})


# ---------------- ADDRESS ----------------

@app.route("/api/address", methods=["POST"])
def add_address():
    data=request.json

    conn=get_db()
    cur=conn.cursor()

    cur.execute("""
    INSERT INTO address(user,fullname,mobile,city,pincode,street)
    VALUES(?,?,?,?,?,?)
    """,(session["user"],data.get("fullname"),data.get("mobile"),data.get("city"),data.get("pincode"),data.get("street")))

    conn.commit()
    conn.close()

    return jsonify({"msg":"address saved"})


# ---------------- PLACE ORDER ----------------

@app.route("/api/order", methods=["POST"])
def place_order():

    conn=get_db()
    cur=conn.cursor()

    # get cart
    cur.execute("SELECT book_id,qty FROM cart WHERE user=?",(session["user"],))
    items=cur.fetchall()

    if not items:
        return jsonify({"error":"cart empty"})

    total=0
    for i in items:
        cur.execute("SELECT price FROM books WHERE id=?",(i[0],))
        total+=cur.fetchone()[0]*i[1]

    order_time=str(datetime.datetime.now())

    cur.execute("INSERT INTO orders(user,total,time) VALUES(?,?,?)",(session["user"],total,order_time))
    order_id=cur.lastrowid

    for i in items:
        cur.execute("INSERT INTO order_items(order_id,book_id,qty) VALUES(?,?,?)",(order_id,i[0],i[1]))

    # clear cart
    cur.execute("DELETE FROM cart WHERE user=?",(session["user"],))

    conn.commit()
    conn.close()

    return jsonify({"redirect": f"/order-success/{order_id}"})



# ---------------- ORDER HISTORY ----------------

@app.route("/api/orders")
def orders():
    conn=get_db()
    cur=conn.cursor()

    cur.execute("SELECT * FROM orders WHERE user=?",(session["user"],))
    rows=cur.fetchall()
    conn.close()

    return jsonify(rows)


# ---------------- LOGOUT ----------------

@app.route("/logout")
def logout():
    session.clear()
    return redirect("/login")


# ---------------- RUN ----------------

# DECREASE QUANTITY

@app.route("/api/cart/decrease", methods=["POST"])
def decrease_cart():
    if "user" not in session:
        return jsonify({"error":"login required"})

    book_id = request.json["book_id"]

    conn = get_db()
    cur = conn.cursor()

    cur.execute("SELECT id,qty FROM cart WHERE user=? AND book_id=?", 
                (session["user"], book_id))
    item = cur.fetchone()

    if item:
        if item[1] > 1:
            cur.execute("UPDATE cart SET qty=qty-1 WHERE id=?", (item[0],))
        else:
            cur.execute("DELETE FROM cart WHERE id=?", (item[0],))

    conn.commit()
    conn.close()

    return jsonify({"msg":"decreased"})

@app.route("/")
def home():
    return redirect("/register")


@app.route("/about")
def about_page():
    return render_template("about.html")


@app.route("/help")
def help_page():
    return render_template("help.html")


@app.route("/profile")
def profile_page():
    if "user" in session:
        return render_template("profile.html")
    return redirect("/login")


@app.route("/checkout")
def checkout_page():
    if "user" in session:
        return render_template("checkout.html")
    return redirect("/login")

@app.route("/orders")
def orders_page():
    if "user" in session:
        return render_template("orders.html")
    return redirect("/login")

@app.route("/order-success/<int:order_id>")
def order_success(order_id):
    if "user" not in session:
        return redirect("/login")
    return render_template("success.html", order_id=order_id)



#----------Admin-------------
@app.route("/admin")
def admin():
    if not admin_required():
        return "ACCESS DENIED"

    conn = get_db()
    cur = conn.cursor()

    cur.execute("""
     SELECT books.id, books.title, books.price, categories.name
     FROM books
     LEFT JOIN categories
     ON books.category_id = categories.id
     """)
    books = cur.fetchall()


    cur.execute("SELECT * FROM categories")
    categories = cur.fetchall()

    conn.close()

    return render_template("admin.html", books=books, categories=categories)



#--------Add  Book Route--------------
@app.route("/add-book", methods=["GET", "POST"])
def add_book():

    conn = get_db()
    cur = conn.cursor()

    if request.method == "POST":
        title = request.form["title"]
        author = request.form["author"]
        description = request.form["description"]
        price = request.form["price"]
        category_id = request.form["category_id"]
        image = request.form["image"]

        cur.execute("""
        INSERT INTO books(title, author, description, price, category_id, image)
        VALUES (?, ?, ?, ?, ?, ?)
        """,(title, author, description, price, category_id, image))

        conn.commit()
        return redirect("/admin")

    # ✅ THIS PART IS REQUIRED
    cur.execute("SELECT * FROM categories")
    categories = cur.fetchall()

    conn.close()

    return render_template("add_book.html", categories=categories)





#-------------- Delete Book Route--------
@app.route("/delete-book/<int:id>")
def delete_book(id):
    if not admin_required():
        return "ACCESS DENIED"

    conn = get_db()
    cur = conn.cursor()
    cur.execute("DELETE FROM books WHERE id=?", (id,))
    conn.commit()
    conn.close()

    return redirect("/admin")



#--------Admin access Protection----
def admin_required():
    if "user" not in session:
        return False

    conn = get_db()
    cur = conn.cursor()
    cur.execute("SELECT is_admin FROM users WHERE email=?", (session["user"],))
    user = cur.fetchone()

    return user and user[0] == 1

#---------Add Category------
@app.route("/add-category", methods=["POST"])
def add_category():
    if not admin_required():
        return "ACCESS DENIED"

    name = request.form["name"]

    conn = get_db()
    cur = conn.cursor()
    cur.execute("INSERT INTO categories(name) VALUES(?)", (name,))
    conn.commit()
    conn.close()

    return redirect("/admin")

#------------Delete Category------
@app.route("/delete-category/<int:id>")
def delete_category(id):
    if not admin_required():
        return "ACCESS DENIED"

    conn = get_db()
    cur = conn.cursor()
    cur.execute("DELETE FROM categories WHERE id=?", (id,))
    conn.commit()
    conn.close()

    return redirect("/admin")

@app.route("/api/categories")
def get_categories():
    conn = get_db()
    cur = conn.cursor()

    cur.execute("SELECT name FROM categories")
    data = cur.fetchall()

    conn.close()

    return jsonify([{"name": c[0]} for c in data])





app.run(debug=True)
