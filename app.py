from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
import datetime
import os
import re
import smtplib
import time
import uuid

from flask import Flask, flash, jsonify, redirect, render_template, request, send_from_directory, session
from werkzeug.security import generate_password_hash
from werkzeug.utils import secure_filename

import firebase_admin
from firebase_admin import credentials, firestore
import pyrebase

from models.constants import ROLE_ADMIN, ROLE_CUSTOMER, ROLE_SHOP_OWNER
from routes import register_extended_routes
from services.book_service import create_book as create_role_book
from services.order_service import list_orders as list_role_orders
from services.store_service import get_store_by_owner as get_shop_by_owner
from services.user_role_service import (
    authenticate_user as authenticate_role_user,
    get_user_by_phone as get_role_user_by_phone,
    register_user as register_role_user,
    upsert_legacy_user_role,
)
from utils.http import request_data as request_payload
from utils.http import wants_json as wants_json_request
from utils.role_auth import set_role_session


firebaseConfig = {
    "apiKey": "AIzaSyDZALZVhpwuPcHlRIevG2VA0lGbDZ4I61s",
    "authDomain": "psi-book-store-e75a3.firebaseapp.com",
    "databaseURL": "https://psi-book-store-e75a3-default-rtdb.firebaseio.com",
    "projectId": "psi-book-store-e75a3",
    "storageBucket": "psi-book-store-e75a3.appspot.com",
    "messagingSenderId": "304704218262",
    "appId": "1:304704218262:web:111e0c388ecc561be6ceb7",
}

firebase = pyrebase.initialize_app(firebaseConfig)
auth_client = firebase.auth()

cred = credentials.Certificate("firebase_key.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

app = Flask(__name__)
app.secret_key = "secret123"
app.config["UPLOAD_FOLDER"] = os.path.join(app.root_path, "static")
app.config["FIRESTORE_DB"] = db
app.config["FIREBASE_AUTH_CLIENT"] = auth_client

ALLOWED_IMAGE_EXTENSIONS = {"jpg", "jpeg", "png", "webp", "gif"}
DEFAULT_STORE_ID = "main-store"
DEFAULT_STORE_NAME = "Main Store"
OWNER_ROLE = "owner"
PAYMENT_METHODS = {"COD", "UPI", "CARD"}


def role_dashboard_redirect(role):
    role = str(role or "").strip().upper()
    if role == ROLE_ADMIN:
        return "/admin/dashboard"
    if role == ROLE_SHOP_OWNER:
        return "/shop/dashboard"
    return "/store"


def send_email_otp(to_email, otp):
    sender_email = "gamerpsi328@gmail.com"
    app_password = "bywv qlrf xqwb vjcr"
    msg = MIMEMultipart("alternative")
    msg["Subject"] = "Email Verification - PSI Book Store"
    msg["From"] = sender_email
    msg["To"] = to_email
    html = f"<p>Your OTP is <b>{otp}</b></p>"
    msg.attach(MIMEText(html, "html"))
    server = smtplib.SMTP("smtp.gmail.com", 587)
    server.starttls()
    server.login(sender_email, app_password)
    server.send_message(msg)
    server.quit()


def normalize_email(value):
    return (value or "").strip().lower()


def normalize_mobile(value):
    return (
        (value or "")
        .replace("+91", "")
        .replace(" ", "")
        .replace("-", "")
        .replace("(", "")
        .replace(")", "")
        .lstrip("0")
    )


def to_int(value, fallback=0):
    try:
        return int(value)
    except Exception:
        return fallback


def allowed_image(filename):
    if "." not in filename:
        return False
    return filename.rsplit(".", 1)[1].lower() in ALLOWED_IMAGE_EXTENSIONS


def sanitize_store_id(name):
    slug = re.sub(r"[^a-z0-9]+", "-", (name or "").strip().lower()).strip("-")
    if slug:
        return slug
    return f"store-{uuid.uuid4().hex[:8]}"


def default_store_permissions():
    return {
        "manage_books": True,
        "manage_categories": True,
        "view_orders": True,
    }


def user_doc_ref(email):
    return db.collection("users").document(normalize_email(email))


def user_addresses_ref(email):
    return user_doc_ref(email).collection("addresses")


def get_user_doc(email=None):
    target = normalize_email(email or session.get("user", ""))
    if not target:
        return {}
    snap = user_doc_ref(target).get()
    return (snap.to_dict() or {}) if snap.exists else {}


def get_doc_store_id(data):
    raw = (data or {}).get("store_id")
    if isinstance(raw, str) and raw.strip():
        return raw.strip()
    return DEFAULT_STORE_ID


def store_ref(store_id):
    return db.collection("stores").document(store_id)


def get_store_doc(store_id):
    snap = store_ref(store_id).get()
    if not snap.exists:
        return None
    data = snap.to_dict() or {}
    return {
        "id": snap.id,
        "name": (data.get("name") or snap.id),
        "nameLower": (data.get("nameLower") or (data.get("name") or snap.id).lower()),
        "status": data.get("status", "active"),
    }


def ensure_default_store():
    snap = store_ref(DEFAULT_STORE_ID).get()
    if snap.exists:
        return
    store_ref(DEFAULT_STORE_ID).set(
        {
            "name": DEFAULT_STORE_NAME,
            "nameLower": DEFAULT_STORE_NAME.lower(),
            "status": "active",
            "created_at": datetime.datetime.utcnow().isoformat(),
        },
        merge=True,
    )


def active_stores():
    ensure_default_store()
    data = []
    for doc in db.collection("stores").stream():
        value = doc.to_dict() or {}
        status = (value.get("status") or "active").strip().lower()
        if status != "active":
            continue
        name = (value.get("name") or doc.id).strip()
        if not name:
            name = doc.id
        data.append({"id": doc.id, "name": name, "nameLower": name.lower(), "status": status})
    data.sort(key=lambda s: s["nameLower"])
    if not any(store["id"] == DEFAULT_STORE_ID for store in data):
        data.insert(
            0,
            {
                "id": DEFAULT_STORE_ID,
                "name": DEFAULT_STORE_NAME,
                "nameLower": DEFAULT_STORE_NAME.lower(),
                "status": "active",
            },
        )
    return data


def get_current_store_id():
    store_id = (session.get("store_id") or "").strip()
    if store_id:
        return store_id

    if "user" in session:
        user_data = get_user_doc(session["user"])
        store_id = (user_data.get("active_store_id") or "").strip()

    if not store_id:
        store_id = DEFAULT_STORE_ID

    session["store_id"] = store_id
    return store_id


def set_current_store(store_id, persist=True):
    store = get_store_doc(store_id)
    if not store:
        return False
    if (store.get("status") or "").lower() != "active":
        return False
    session["store_id"] = store_id
    if persist and "user" in session:
        user_doc_ref(session["user"]).set({"active_store_id": store_id}, merge=True)
    return True


def get_store_role_payload(user_data, store_id):
    store_roles = user_data.get("store_roles", {})
    if not isinstance(store_roles, dict):
        return {}
    payload = store_roles.get(store_id, {})
    if isinstance(payload, dict):
        return payload
    if isinstance(payload, str):
        return {"role": payload}
    return {}


def is_store_owner(user_data, store_id):
    payload = get_store_role_payload(user_data, store_id)
    role = (payload.get("role") or "").lower()
    is_active = payload.get("active", True) is not False
    return role == OWNER_ROLE and is_active


def owner_store_ids(user_data):
    store_roles = user_data.get("store_roles", {})
    if not isinstance(store_roles, dict):
        return []

    ids = []
    for sid, payload in store_roles.items():
        if not isinstance(payload, dict):
            continue
        if (payload.get("role") or "").lower() != OWNER_ROLE:
            continue
        if payload.get("active", True) is False:
            continue
        store = get_store_doc(str(sid))
        if not store:
            continue
        if (store.get("status") or "").lower() != "active":
            continue
        ids.append(str(sid))
    return sorted(set(ids))


def is_superadmin(user_data):
    if not user_data:
        return False
    if (user_data.get("global_role") or "").lower() == "superadmin":
        return True
    return to_int(user_data.get("is_admin"), 0) == 1


def admin_required(permission=None, store_id=None):
    if "user" not in session:
        return False

    user_data = get_user_doc(session["user"])
    if is_superadmin(user_data):
        return True

    target_store = store_id or get_current_store_id()
    if is_store_owner(user_data, target_store):
        return True

    # If owner is currently on a non-owned store, auto-switch to first owned store.
    # This prevents "ACCESS DENIED" when owner clicks admin after browsing another store.
    if store_id:
        return False
    owner_ids = owner_store_ids(user_data)
    if owner_ids:
        set_current_store(owner_ids[0], persist=True)
        return True
    return False


def current_user_role_label(store_id):
    user_data = get_user_doc()
    if is_superadmin(user_data):
        return "Super Admin"
    role = (get_store_role_payload(user_data, store_id).get("role") or "").lower()
    if role == OWNER_ROLE:
        return "Store Owner"
    return "Customer"


def category_lookup_for_store(store_id):
    mapping = {}
    for doc in db.collection("categories").stream():
        data = doc.to_dict() or {}
        name = (data.get("name") or "").strip()
        if name:
            mapping[doc.id] = name
    return mapping


def list_categories_for_store(store_id, include_all=False):
    categories = []
    for doc in db.collection("categories").stream():
        data = doc.to_dict() or {}
        if not include_all and get_doc_store_id(data) != store_id:
            continue
        name = (data.get("name") or "").strip()
        if not name:
            continue
        categories.append({"id": doc.id, "name": name, "store_id": get_doc_store_id(data)})
    categories.sort(key=lambda x: x["name"].lower())
    return categories


def list_books_for_store(store_id):
    category_map = category_lookup_for_store(store_id)
    store_data = get_store_doc(store_id) or {"id": store_id, "name": store_id}
    books = []
    for doc in db.collection("books").stream():
        data = doc.to_dict() or {}
        if get_doc_store_id(data) != store_id:
            continue
        category_id = (data.get("category") or "").strip()
        books.append(
            {
                "id": doc.id,
                "title": data.get("title"),
                "author": data.get("author"),
                "desc": data.get("description"),
                "price": data.get("price"),
                "category": category_map.get(category_id, ""),
                "category_id": category_id,
                "image": data.get("image"),
                "store_id": store_id,
                "store_name": store_data.get("name", store_id),
            }
        )
    books.sort(key=lambda b: (b.get("title") or "").lower())
    return books


def list_books_all_active_stores():
    rows = []
    for store in active_stores():
        rows.extend(list_books_for_store(store["id"]))
    rows.sort(key=lambda b: ((b.get("title") or "").lower(), (b.get("store_name") or "").lower()))
    return rows


def get_book_if_store_matches(book_id, store_id):
    snap = db.collection("books").document(str(book_id)).get()
    if not snap.exists:
        return None
    data = snap.to_dict() or {}
    if get_doc_store_id(data) != store_id:
        return None
    return data


def user_store_bucket_doc(collection, user_email, store_id):
    safe_email = normalize_email(user_email).replace("/", "_")
    return db.collection(collection).document(f"{store_id}__{safe_email}")


def cart_items_ref(user_email, store_id):
    return user_store_bucket_doc("cart", user_email, store_id).collection("items")


def wishlist_items_ref(user_email, store_id):
    return user_store_bucket_doc("wishlist", user_email, store_id).collection("items")


def list_store_owners(store_id=None):
    members = []
    for doc in db.collection("users").stream():
        data = doc.to_dict() or {}
        store_roles = data.get("store_roles", {})
        if not isinstance(store_roles, dict):
            continue
        for sid, payload in store_roles.items():
            if not isinstance(payload, dict):
                continue
            if (payload.get("role") or "").lower() != OWNER_ROLE:
                continue
            if store_id and sid != store_id:
                continue
            store = get_store_doc(sid) or {"id": sid, "name": sid}
            members.append(
                {
                    "email": data.get("email") or doc.id,
                    "store_id": sid,
                    "store_name": store.get("name") or sid,
                    "active": payload.get("active", True) is not False,
                }
            )
    members.sort(key=lambda row: ((row["store_name"] or "").lower(), (row["email"] or "").lower()))
    return members


def owner_emails_for_store(store_id):
    emails = []
    for row in list_store_owners(store_id):
        if row["active"]:
            emails.append(normalize_email(row["email"]))
    return emails


def normalize_address_doc(doc_id, data):
    value = data or {}
    return {
        "id": doc_id,
        "user": normalize_email(value.get("user")),
        "store_id": get_doc_store_id(value),
        "fullname": (value.get("fullname") or "").strip(),
        "mobile": (value.get("mobile") or "").strip(),
        "city": (value.get("city") or "").strip(),
        "pincode": (value.get("pincode") or "").strip(),
        "street": (value.get("street") or "").strip(),
        "landmark": (value.get("landmark") or "").strip(),
        "address_type": (value.get("address_type") or "Home").strip() or "Home",
        "created_at": value.get("created_at", ""),
    }


def latest_address_for_user_store(user_email, store_id):
    email = normalize_email(user_email)
    latest = None

    # Primary source: per-user address subcollection
    for doc in user_addresses_ref(email).stream():
        row = normalize_address_doc(doc.id, doc.to_dict() or {})
        if row["store_id"] != store_id:
            continue
        if latest is None or (row.get("created_at") or "") > (latest.get("created_at") or ""):
            latest = row

    if latest:
        return latest

    # Legacy fallback
    for doc in db.collection("address").where("user", "==", email).stream():
        row = normalize_address_doc(doc.id, doc.to_dict() or {})
        if row["store_id"] != store_id:
            continue
        if latest is None or (row.get("created_at") or "") > (latest.get("created_at") or ""):
            latest = row
    return latest or {}


def list_addresses_for_user(user_email):
    rows = []
    email = normalize_email(user_email)
    seen = set()

    # Primary source: per-user address subcollection
    for doc in user_addresses_ref(email).stream():
        row = normalize_address_doc(doc.id, doc.to_dict() or {})
        if row["user"] and row["user"] != email:
            continue
        row["user"] = email
        rows.append(row)
        seen.add(row["id"])

    # Legacy fallback + one-time migration into per-user subcollection
    for doc in db.collection("address").where("user", "==", email).stream():
        if doc.id in seen:
            continue
        row = normalize_address_doc(doc.id, doc.to_dict() or {})
        row["user"] = email
        rows.append(row)
        seen.add(row["id"])
        user_addresses_ref(email).document(doc.id).set(row, merge=True)

    rows.sort(key=lambda r: r.get("created_at", ""), reverse=True)
    return rows


def get_address_doc_for_user(user_email, address_id):
    email = normalize_email(user_email)
    address_id = (address_id or "").strip()
    if not address_id:
        return None

    # Primary source: per-user subcollection
    own_snap = user_addresses_ref(email).document(address_id).get()
    if own_snap.exists:
        row = normalize_address_doc(own_snap.id, own_snap.to_dict() or {})
        if row["user"] and row["user"] != email:
            return None
        row["user"] = email
        return row

    # Legacy fallback
    snap = db.collection("address").document(address_id).get()
    if not snap.exists:
        return None
    row = normalize_address_doc(snap.id, snap.to_dict() or {})
    if row["user"] != email:
        return None

    # Migrate the legacy address into per-user subcollection for isolation
    user_addresses_ref(email).document(snap.id).set(row, merge=True)
    return row


def get_selected_address_for_user(user_email):
    selected_id = (session.get("selected_address_id") or "").strip()
    if not selected_id:
        return None
    return get_address_doc_for_user(user_email, selected_id)


def send_owner_order_email(owner_email, store_name, order_data):
    sender_email = "gamerpsi328@gmail.com"
    app_password = "bywv qlrf xqwb vjcr"
    subject = f"New Order for {store_name}"
    lines = [
        f"Store: {store_name}",
        f"Order ID: {order_data.get('order_id', '-')}",
        f"DateTime: {order_data.get('time', '-')}",
        f"User: {order_data.get('user', '-')}",
        f"Books: {order_data.get('books_text', '-')}",
        f"Address: {order_data.get('address_text', '-')}",
        "Payment: handled by Admin",
    ]
    body = "<br>".join(lines)
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = sender_email
    msg["To"] = owner_email
    msg.attach(MIMEText(body, "html"))
    try:
        server = smtplib.SMTP("smtp.gmail.com", 587)
        server.starttls()
        server.login(sender_email, app_password)
        server.send_message(msg)
        server.quit()
    except Exception as e:
        print("OWNER NOTIFY MAIL ERROR:", e)


def list_all_books():
    rows = []
    for doc in db.collection("books").stream():
        data = doc.to_dict() or {}
        sid = get_doc_store_id(data)
        store = get_store_doc(sid) or {"name": sid}
        rows.append(
            {
                "id": doc.id,
                "title": data.get("title"),
                "author": data.get("author"),
                "price": data.get("price"),
                "store_id": sid,
                "store_name": store.get("name") or sid,
            }
        )
    rows.sort(key=lambda r: ((r.get("store_name") or "").lower(), (r.get("title") or "").lower()))
    return rows


def list_all_users_with_roles():
    rows = []
    for doc in db.collection("users").stream():
        data = doc.to_dict() or {}
        owners = []
        store_roles = data.get("store_roles", {})
        if isinstance(store_roles, dict):
            for sid, payload in store_roles.items():
                if not isinstance(payload, dict):
                    continue
                if (payload.get("role") or "").lower() != OWNER_ROLE:
                    continue
                store = get_store_doc(sid) or {"name": sid}
                owners.append(
                    {
                        "store_id": sid,
                        "store_name": store.get("name") or sid,
                        "active": payload.get("active", True) is not False,
                    }
                )
        rows.append(
            {
                "email": data.get("email") or doc.id,
                "mobile": data.get("mobile", ""),
                "global_role": data.get("global_role", "user"),
                "is_admin": to_int(data.get("is_admin"), 0),
                "owners": owners,
            }
        )
    rows.sort(key=lambda r: (r["email"] or "").lower())
    return rows


def owner_notifications(owner_email, store_id=None):
    email = normalize_email(owner_email)
    rows = []
    for doc in db.collection("owner_notifications").where("owner_email", "==", email).stream():
        data = doc.to_dict() or {}
        if store_id and get_doc_store_id(data) != store_id:
            continue
        data["id"] = doc.id
        rows.append(data)
    rows.sort(key=lambda r: r.get("time", ""), reverse=True)
    return rows


def stores_for_user(user_data):
    if is_superadmin(user_data):
        return active_stores()

    owner_ids = owner_store_ids(user_data)
    if owner_ids:
        candidate_ids = set(owner_ids)
    else:
        candidate_ids = {get_current_store_id(), DEFAULT_STORE_ID}

    stores = []
    for store_id in candidate_ids:
        store = get_store_doc(store_id)
        if not store:
            continue
        if (store.get("status") or "").lower() != "active":
            continue
        stores.append(store)

    stores.sort(key=lambda row: (row.get("name") or "").lower())
    if stores:
        return stores
    return [{"id": DEFAULT_STORE_ID, "name": DEFAULT_STORE_NAME, "status": "active"}]


ensure_default_store()


@app.route("/register", methods=["GET", "POST"])
def register():
    if request.method == "POST":
        if wants_json_request(request):
            payload = request_payload(request)
            name = (payload.get("name") or "").strip()
            email = normalize_email(payload.get("email"))
            phone = normalize_mobile(payload.get("phone") or payload.get("mobile"))
            password = payload.get("password")
            role = (payload.get("role") or ROLE_CUSTOMER).strip().upper()

            if not name and email:
                name = email.split("@", 1)[0]

            try:
                user = register_role_user(
                    name=name,
                    email=email,
                    phone=phone,
                    password=password,
                    role=role,
                )
                return jsonify({"success": True, "user": user}), 201
            except Exception as e:
                return jsonify({"success": False, "error": str(e)}), 400

        email = normalize_email(request.form.get("email"))
        password = request.form.get("password")
        mobile = normalize_mobile(request.form.get("mobile"))
        if not email or not password:
            flash("Email and password are required", "error")
            return redirect("/register")

        try:
            user = auth_client.create_user_with_email_and_password(email, password)
            auth_client.send_email_verification(user["idToken"])
            user_doc_ref(email).set(
                {
                    "email": email,
                    "mobile": mobile,
                    "is_admin": 0,
                    "global_role": "user",
                    "active_store_id": DEFAULT_STORE_ID,
                    "store_roles": {},
                },
                merge=True,
            )
            upsert_legacy_user_role(
                email=email,
                role=ROLE_CUSTOMER,
                name=(request.form.get("name") or ""),
                phone=mobile,
            )
            flash("Registered. Verify email before login.", "success")
            return redirect("/login")
        except Exception as e:
            print(e)
            flash("Email exists or weak password (min 6)", "error")
            return redirect("/register")

    return render_template("register.html")


@app.route("/verify-email", methods=["GET", "POST"])
def verify_email():
    if request.method == "POST":
        required = {"email_otp_time", "email_otp", "email", "mobile", "password"}
        if not required.issubset(set(session.keys())):
            flash("Verification session expired. Please register again.", "error")
            return redirect("/register")

        if time.time() - session["email_otp_time"] > 120:
            flash("OTP expired", "error")
            return redirect("/register")

        if request.form["otp"] == str(session["email_otp"]):
            user_doc_ref(session["email"]).set(
                {
                    "email": session["email"],
                    "mobile": session["mobile"],
                    "password": generate_password_hash(session["password"]),
                    "mobile_verified": 1,
                    "email_verified": 1,
                    "is_admin": 0,
                    "global_role": "user",
                    "active_store_id": DEFAULT_STORE_ID,
                    "store_roles": {},
                },
                merge=True,
            )
            upsert_legacy_user_role(
                email=session["email"],
                role=ROLE_CUSTOMER,
                name=(request.form.get("name") or ""),
                phone=session["mobile"],
            )
            flash("Registration successful. Please login", "success")
            return redirect("/login")

        flash("Wrong OTP", "error")

    return render_template("otp_email.html")


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "GET":
        if "user" in session:
            return redirect(role_dashboard_redirect(session.get("role")))
        return render_template("index.html")

    payload = request_payload(request)
    identifier = (payload.get("identifier") or payload.get("email") or payload.get("value") or "").strip()
    password = str(payload.get("password") or "")

    email = normalize_email(identifier)
    clean_mobile = normalize_mobile(identifier)
    if clean_mobile.isdigit():
        phone_user = get_role_user_by_phone(clean_mobile)
        if phone_user and phone_user.get("email"):
            email = normalize_email(phone_user.get("email"))

    expected_role = ROLE_CUSTOMER
    user, err = authenticate_role_user(
        email=email,
        password=password,
        expected_role=expected_role,
    )
    if err:
        if wants_json_request(request):
            return jsonify({"success": False, "error": err}), 401
        flash(err, "error")
        return redirect("/login")

    set_role_session(user["user_id"], user["role"])
    session["user"] = user.get("email", email)
    session.pop("selected_address_id", None)

    user_data = get_user_doc(session["user"])
    active_store = (user_data.get("active_store_id") or "").strip() or DEFAULT_STORE_ID
    set_current_store(active_store, persist=False)

    if wants_json_request(request):
        return jsonify(
            {
                "success": True,
                "redirect": role_dashboard_redirect(user["role"]),
                "user": user,
            }
        )

    flash("Login successful", "success")
    return redirect(role_dashboard_redirect(user["role"]))


@app.route("/forgot-password", methods=["GET", "POST"])
def forgot_password():
    if request.method == "POST":
        email = normalize_email(request.form.get("email"))
        if not email:
            flash("Please enter your email", "error")
            return redirect("/forgot-password")

        try:
            auth_client.send_password_reset_email(email)
            flash("Password reset link sent to your email", "success")
            return redirect("/login")
        except Exception as e:
            print("FORGOT PASSWORD ERROR:", e)
            flash("Unable to send reset link. Check email and try again.", "error")
            return redirect("/forgot-password")
    return render_template("forgot_password.html")


@app.route("/api/stores/search")
def search_stores():
    if "user" not in session:
        return jsonify([])
    q = (request.args.get("q") or "").strip().lower()
    stores = active_stores()
    if q:
        stores = [store for store in stores if q in store["nameLower"]]
    return jsonify([{"id": row["id"], "name": row["name"], "status": row["status"]} for row in stores[:20]])


@app.route("/api/stores/current")
def current_store():
    if "user" not in session:
        return jsonify({"id": DEFAULT_STORE_ID, "name": DEFAULT_STORE_NAME, "status": "active"})
    store = get_store_doc(get_current_store_id()) or {"id": DEFAULT_STORE_ID, "name": DEFAULT_STORE_NAME, "status": "active"}
    return jsonify(store)


@app.route("/api/stores/select", methods=["POST"])
def select_store():
    if "user" not in session:
        return jsonify({"error": "login required"}), 401

    payload = request.get_json(silent=True) or {}
    store_id = (payload.get("store_id") or request.form.get("store_id") or "").strip()
    if not store_id:
        return jsonify({"error": "store_id is required"}), 400

    if not set_current_store(store_id, persist=True):
        return jsonify({"error": "Invalid or inactive store"}), 400

    return jsonify({"msg": "store selected", "store_id": store_id})


@app.route("/api/stores", methods=["GET", "POST"])
def manage_stores():
    if "user" not in session:
        return jsonify({"error": "login required"}), 401

    user_data = get_user_doc()
    if request.method == "GET":
        if not admin_required():
            return jsonify({"error": "access denied"}), 403
        return jsonify(stores_for_user(user_data))

    if not is_superadmin(user_data):
        return jsonify({"error": "super admin required"}), 403

    payload = request.get_json(silent=True) or request.form
    name = (payload.get("name") or "").strip()
    if not name:
        return jsonify({"error": "Store name required"}), 400

    store_id = (payload.get("store_id") or "").strip() or sanitize_store_id(name)
    while store_ref(store_id).get().exists:
        store_id = f"{store_id}-{uuid.uuid4().hex[:4]}"

    now = datetime.datetime.utcnow().isoformat()
    store_ref(store_id).set(
        {
            "name": name,
            "nameLower": name.lower(),
            "status": "active",
            "created_at": now,
            "created_by": session["user"],
        },
        merge=True,
    )

    owner_email = normalize_email(payload.get("owner_email"))
    if owner_email:
        user_doc_ref(owner_email).set(
            {
                "email": owner_email,
                "active_store_id": store_id,
                "store_roles": {
                    store_id: {
                        "role": OWNER_ROLE,
                        "active": True,
                    }
                },
                "updated_at": now,
            },
            merge=True,
        )

    return jsonify({"msg": "store created", "store_id": store_id})


@app.route("/api/stores/delete", methods=["POST"])
def delete_store():
    if "user" not in session:
        return jsonify({"error": "login required"}), 401
    if not is_superadmin(get_user_doc()):
        return jsonify({"error": "super admin required"}), 403

    payload = request.get_json(silent=True) or request.form
    store_id = (payload.get("store_id") or "").strip()
    if not store_id:
        return jsonify({"error": "store_id required"}), 400
    if store_id == DEFAULT_STORE_ID:
        return jsonify({"error": "default store cannot be deleted"}), 400
    if not get_store_doc(store_id):
        return jsonify({"error": "store not found"}), 404

    store_ref(store_id).set(
        {
            "status": "disabled",
            "updated_at": datetime.datetime.utcnow().isoformat(),
            "updated_by": session["user"],
        },
        merge=True,
    )
    return jsonify({"msg": "store disabled"})


@app.route("/api/books")
def get_books():
    include_all = (request.args.get("all") or "").strip() == "1"
    if include_all:
        return jsonify(list_books_all_active_stores())

    store_id = (request.args.get("store_id") or "").strip()
    if not store_id:
        store_id = get_current_store_id() if "user" in session else DEFAULT_STORE_ID
    books = list_books_for_store(store_id)
    return jsonify(books)


@app.route("/store")
def store():
    if "user" not in session:
        return redirect("/login")

    role = (session.get("role") or "").strip().upper()
    if role == ROLE_ADMIN:
        return redirect("/admin/dashboard")
    if role == ROLE_SHOP_OWNER:
        return redirect("/shop/dashboard")

    store_id = get_current_store_id()
    store_data = get_store_doc(store_id) or {"id": DEFAULT_STORE_ID, "name": DEFAULT_STORE_NAME}
    can_view_admin = admin_required()
    return render_template(
        "store.html",
        user=session["user"],
        active_store_id=store_data["id"],
        active_store_name=store_data["name"],
        can_view_admin=can_view_admin,
    )


@app.route("/api/cart/add", methods=["POST"])
def add_cart():
    if "user" not in session:
        return jsonify({"error": "login required"})

    data = request.get_json(silent=True) or {}
    book_id = str(data.get("book_id") or "").strip()
    if not book_id:
        return jsonify({"error": "book_id required"}), 400

    store_id = (data.get("store_id") or "").strip() or get_current_store_id()
    if not get_book_if_store_matches(book_id, store_id):
        return jsonify({"error": "book not found in selected store"}), 404

    set_current_store(store_id, persist=True)
    cart_items_ref(session["user"], store_id).document(book_id).set(
        {"qty": firestore.Increment(1), "store_id": store_id}, merge=True
    )
    return jsonify({"msg": "added"})


@app.route("/api/cart/delete", methods=["POST"])
def delete_cart():
    if "user" not in session:
        return jsonify({"error": "login required"})
    data = request.get_json(silent=True) or {}
    book_id = str(data.get("book_id") or "").strip()
    store_id = get_current_store_id()
    cart_items_ref(session["user"], store_id).document(book_id).delete()
    return jsonify({"msg": "deleted"})


@app.route("/api/cart")
def view_cart():
    if "user" not in session:
        return jsonify({"items": [], "total": 0})

    store_id = get_current_store_id()
    items = []
    total = 0
    for item_doc in cart_items_ref(session["user"], store_id).stream():
        book = get_book_if_store_matches(item_doc.id, store_id)
        if not book:
            continue
        qty = to_int((item_doc.to_dict() or {}).get("qty"), 1)
        price = to_int(book.get("price"), 0)
        total += price * qty
        items.append(
            {
                "id": item_doc.id,
                "title": book.get("title", "Unknown"),
                "price": price,
                "qty": qty,
            }
        )
    return jsonify({"items": items, "total": total, "store_id": store_id})


@app.route("/api/address", methods=["GET", "POST"])
def add_address():
    if "user" not in session:
        return jsonify({"error": "login required"}), 401
    if request.method == "GET":
        addresses = list_addresses_for_user(session["user"])
        selected_id = (session.get("selected_address_id") or "").strip()
        if selected_id and not any(row["id"] == selected_id for row in addresses):
            selected_id = ""
            session.pop("selected_address_id", None)
        if not selected_id and addresses:
            # Auto-pick first available address so continue-to-payment works
            # even when user has not clicked "Deliver Here" explicitly.
            selected_id = addresses[0]["id"]
            session["selected_address_id"] = selected_id
        return jsonify({"addresses": addresses, "selected_address_id": selected_id})

    data = request.get_json(silent=True) or {}
    payload = {
        "user": normalize_email(session["user"]),
        "store_id": get_current_store_id(),
        "fullname": (data.get("fullname") or "").strip(),
        "mobile": (data.get("mobile") or "").strip(),
        "city": (data.get("city") or "").strip(),
        "pincode": (data.get("pincode") or "").strip(),
        "street": (data.get("street") or "").strip(),
        "landmark": (data.get("landmark") or "").strip(),
        "address_type": (data.get("address_type") or "Home").strip() or "Home",
        "created_at": datetime.datetime.utcnow().isoformat(),
    }
    required = ["fullname", "mobile", "city", "pincode", "street"]
    if any(not payload[key] for key in required):
        return jsonify({"error": "Please fill all required address fields."}), 400

    email = normalize_email(session["user"])
    ref = user_addresses_ref(email).document()
    ref.set(payload)
    # Keep legacy collection in sync for backward compatibility with old app flows.
    db.collection("address").document(ref.id).set(payload, merge=True)
    if data.get("is_default") or not session.get("selected_address_id"):
        session["selected_address_id"] = ref.id
    return jsonify({"msg": "address saved", "address_id": ref.id})


@app.route("/api/address/select", methods=["POST"])
def select_address():
    if "user" not in session:
        return jsonify({"error": "login required"}), 401

    data = request.get_json(silent=True) or {}
    address_id = (data.get("address_id") or "").strip()
    address = get_address_doc_for_user(session["user"], address_id)
    if not address:
        return jsonify({"error": "address not found"}), 404

    session["selected_address_id"] = address_id
    return jsonify({"msg": "address selected", "address_id": address_id})


@app.route("/api/order", methods=["POST"])
def place_order():
    if "user" not in session:
        return jsonify({"error": "login required"})

    payload = request.get_json(silent=True) or {}
    payment_method = (payload.get("payment_method") or "COD").strip().upper()
    if payment_method not in PAYMENT_METHODS:
        payment_method = "COD"
    transaction_id = (payload.get("transaction_id") or "").strip()

    store_id = get_current_store_id()
    store = get_store_doc(store_id) or {"id": store_id, "name": store_id}
    items = []
    item_titles = []
    total = 0
    for item_doc in cart_items_ref(session["user"], store_id).stream():
        book = get_book_if_store_matches(item_doc.id, store_id)
        if not book:
            continue
        qty = to_int((item_doc.to_dict() or {}).get("qty"), 0)
        price = to_int(book.get("price"), 0)
        if qty <= 0 or price <= 0:
            continue
        total += price * qty
        items.append({"book": item_doc.id, "qty": qty})
        item_titles.append(f"{book.get('title', item_doc.id)} x{qty}")

    if not items:
        return jsonify({"error": "Cart empty"})

    selected_address_id = (
        (payload.get("address_id") or "").strip()
        or (session.get("selected_address_id") or "").strip()
    )
    address = get_address_doc_for_user(session["user"], selected_address_id)
    if not address:
        # Backward-compatible fallback (for existing app flows):
        # use latest saved address if explicit selection is missing.
        legacy = latest_address_for_user_store(session["user"], store_id)
        if legacy:
            address = legacy
    if not address:
        return jsonify({"error": "Select delivery address before payment"}), 400

    address_text = ", ".join(
        [
            str(address.get("fullname", "")).strip(),
            str(address.get("street", "")).strip(),
            str(address.get("city", "")).strip(),
            str(address.get("pincode", "")).strip(),
            str(address.get("mobile", "")).strip(),
        ]
    ).strip(", ").strip()
    payment_status = "pay_on_delivery" if payment_method == "COD" else ("paid" if transaction_id else "pending")

    order = db.collection("orders").add(
        {
            "user": session["user"],
            "store_id": store_id,
            "store_name": store.get("name", store_id),
            "total": total,
            "time": datetime.datetime.utcnow().isoformat(),
            "items": items,
            "books_text": ", ".join(item_titles) if item_titles else "-",
            "payment_method": payment_method,
            "payment_status": payment_status,
            "payment_receiver": "admin",
            "transaction_id": transaction_id,
            "address_id": selected_address_id,
            "address": address,
        }
    )

    for item in items:
        cart_items_ref(session["user"], store_id).document(item["book"]).delete()

    order_id = order[1].id
    notify_payload = {
        "order_id": order_id,
        "store_id": store_id,
        "store_name": store.get("name", store_id),
        "user": session["user"],
        "time": datetime.datetime.utcnow().isoformat(),
        "books_text": ", ".join(item_titles) if item_titles else "-",
        "address_text": address_text or "-",
    }
    for owner_email in owner_emails_for_store(store_id):
        db.collection("owner_notifications").add(
            {
                "owner_email": owner_email,
                "store_id": store_id,
                "store_name": store.get("name", store_id),
                "order_id": order_id,
                "user": session["user"],
                "time": notify_payload["time"],
                "books_text": notify_payload["books_text"],
                "address_text": notify_payload["address_text"],
                "payment_scope": "handled_by_admin",
            }
        )
        send_owner_order_email(owner_email, store.get("name", store_id), notify_payload)

    return jsonify({"redirect": f"/order-success/{order_id}"})


@app.route("/api/orders")
def orders():
    if "user" not in session:
        return jsonify([])

    store_id = get_current_store_id()
    data = []
    for doc in db.collection("orders").where("user", "==", session["user"]).stream():
        order = doc.to_dict() or {}
        if get_doc_store_id(order) != store_id:
            continue
        store = get_store_doc(get_doc_store_id(order))
        if store and not order.get("store_name"):
            order["store_name"] = store.get("name", store["id"])
        order["id"] = doc.id
        data.append(order)
    data.sort(key=lambda row: row.get("time", ""), reverse=True)
    return jsonify(data)


@app.route("/logout")
def logout():
    session.clear()
    return redirect("/login")


@app.route("/api/cart/decrease", methods=["POST"])
def decrease_cart():
    if "user" not in session:
        return jsonify({"error": "login required"})

    data = request.get_json(silent=True) or {}
    book_id = str(data.get("book_id") or "").strip()
    store_id = get_current_store_id()
    ref = cart_items_ref(session["user"], store_id).document(book_id)
    snap = ref.get()
    if snap.exists:
        qty = to_int((snap.to_dict() or {}).get("qty"), 1)
        if qty > 1:
            ref.update({"qty": firestore.Increment(-1)})
        else:
            ref.delete()
    return jsonify({"msg": "decreased"})


@app.route("/")
def home():
    return redirect("/login")


@app.route("/about")
def about_page():
    return render_template("about.html")


@app.route("/book-assets/<path:filename>")
def book_assets(filename):
    assets_dir = os.path.join(app.root_path, "user_app", "assets", "books")
    return send_from_directory(assets_dir, filename)


@app.route("/help")
def help_page():
    return render_template("help.html")


@app.route("/profile")
def profile_page():
    if "user" not in session:
        return redirect("/login")
    store_id = get_current_store_id()
    store_data = get_store_doc(store_id) or {"id": store_id, "name": store_id}
    return render_template(
        "profile.html",
        active_store_id=store_data["id"],
        active_store_name=store_data["name"],
        role_label=current_user_role_label(store_id),
    )


@app.route("/checkout")
def checkout_page():
    if "user" not in session:
        return redirect("/login")

    store_id = get_current_store_id()
    has_cart_items = False
    for item_doc in cart_items_ref(session["user"], store_id).stream():
        book = get_book_if_store_matches(item_doc.id, store_id)
        if not book:
            continue
        qty = to_int((item_doc.to_dict() or {}).get("qty"), 0)
        if qty > 0:
            has_cart_items = True
            break

    if not has_cart_items:
        return redirect("/store?cart_required=1")

    selected = get_selected_address_for_user(session["user"])
    return render_template(
        "checkout.html",
        selected_address_id=(selected or {}).get("id", ""),
    )


@app.route("/payment")
def payment_page():
    if "user" not in session:
        return redirect("/login")

    selected = get_selected_address_for_user(session["user"])
    if not selected:
        # Recover from stale/missing session selection by defaulting
        # to the first saved address for the logged-in user.
        addresses = list_addresses_for_user(session["user"])
        if addresses:
            selected = addresses[0]
            session["selected_address_id"] = selected.get("id", "")
    if not selected:
        flash("Select delivery address before payment", "error")
        return redirect("/checkout")
    return render_template("payment.html", selected_address=selected)


@app.route("/orders")
def orders_page():
    if wants_json_request(request):
        role = (session.get("role") or "").strip().upper()
        user_id = (session.get("user_id") or "").strip()
        if user_id and role == ROLE_ADMIN:
            return jsonify(list_role_orders())
        if user_id and role == ROLE_CUSTOMER:
            return jsonify(list_role_orders(user_id=user_id))
        if "user" in session:
            return orders()
        return jsonify([]), 401

    if "user" in session:
        return render_template("orders.html")
    return redirect("/login")


@app.route("/order-success/<order_id>")
def order_success(order_id):
    if "user" not in session:
        return redirect("/login")
    return render_template("success.html", order_id=order_id)


@app.route("/admin")
def admin():
    if not admin_required():
        if "user" not in session:
            return redirect("/login")
        return render_template("access_denied.html", target_page="Admin Dashboard"), 403

    # New admin control center lives at /admin/dashboard.
    if (request.args.get("legacy") or "").strip() != "1":
        return redirect("/admin/dashboard")

    store_id = get_current_store_id()
    store_data = get_store_doc(store_id) or {"id": store_id, "name": store_id}
    user_data = get_user_doc()
    super_admin = is_superadmin(user_data)
    owner_mode = is_store_owner(user_data, store_id)

    categories = list_categories_for_store(store_id, include_all=True)
    books = list_books_for_store(store_id)
    books_all = list_all_books()
    owners_for_view = list_store_owners(None if super_admin else store_id)
    users_for_view = list_all_users_with_roles() if super_admin else []

    store_orders = []
    all_orders = []
    for doc in db.collection("orders").stream():
        data = doc.to_dict() or {}
        order_store_id = get_doc_store_id(data)
        store_row = get_store_doc(order_store_id) or {"id": order_store_id, "name": order_store_id}
        row = {
            "id": doc.id,
            "store_id": order_store_id,
            "store_name": store_row.get("name", order_store_id),
            "user": data.get("user"),
            "total": data.get("total"),
            "time": data.get("time"),
            "payment_method": data.get("payment_method", "COD"),
            "payment_status": data.get("payment_status", "pending"),
            "address": data.get("address", {}),
        }

        if order_store_id == store_id:
            store_orders.append(row)

        if not super_admin:
            continue

        all_orders.append(row)
    store_orders.sort(key=lambda row: row.get("time", ""), reverse=True)
    all_orders.sort(key=lambda row: row.get("time", ""), reverse=True)

    my_notifications = owner_notifications(session["user"], store_id if owner_mode and not super_admin else None)

    return render_template(
        "admin.html",
        books=books,
        books_all=books_all,
        categories=categories,
        stores=stores_for_user(user_data),
        active_store_id=store_data["id"],
        active_store_name=store_data["name"],
        current_role_label=current_user_role_label(store_id),
        owners=owners_for_view,
        users_all=users_for_view,
        can_manage_books=super_admin or owner_mode,
        can_manage_categories=super_admin or owner_mode,
        can_manage_owners=super_admin,
        can_manage_stores=super_admin,
        can_view_orders=super_admin or owner_mode,
        is_super_admin=super_admin,
        owner_notifications=my_notifications[:40],
        store_orders=store_orders[:25],
        all_orders=all_orders[:50],
    )


@app.route("/assign-owner", methods=["POST"])
def assign_owner():
    if "user" not in session or not is_superadmin(get_user_doc()):
        return "ACCESS DENIED"

    email = normalize_email(request.form.get("email"))
    store_id = (request.form.get("store_id") or "").strip()
    if not email or not store_id:
        flash("Owner email and store are required", "error")
        return redirect("/admin")
    if not get_store_doc(store_id):
        flash("Invalid store selected", "error")
        return redirect("/admin")

    user_doc_ref(email).set(
        {
            "email": email,
            "store_roles": {
                store_id: {
                    "role": OWNER_ROLE,
                    "active": True,
                }
            },
            "active_store_id": store_id,
            "updated_at": datetime.datetime.utcnow().isoformat(),
        },
        merge=True,
    )
    flash("Store owner assigned successfully", "success")
    return redirect("/admin")


@app.route("/set-owner-access", methods=["POST"])
def set_owner_access():
    if "user" not in session or not is_superadmin(get_user_doc()):
        return "ACCESS DENIED"

    email = normalize_email(request.form.get("email"))
    store_id = (request.form.get("store_id") or "").strip()
    action = (request.form.get("action") or "block").strip().lower()
    is_active = action == "allow"

    target = get_user_doc(email)
    if not target:
        flash("Owner account not found", "error")
        return redirect("/admin")
    payload = get_store_role_payload(target, store_id)
    if (payload.get("role") or "").lower() != OWNER_ROLE:
        flash("User is not owner for this store", "error")
        return redirect("/admin")

    user_doc_ref(email).set(
        {
            "store_roles": {
                store_id: {
                    "role": OWNER_ROLE,
                    "active": is_active,
                }
            },
            "updated_at": datetime.datetime.utcnow().isoformat(),
        },
        merge=True,
    )
    flash("Owner access updated", "success")
    return redirect("/admin")


@app.route("/add-book", methods=["GET", "POST"])
def add_book():
    if request.method == "POST" and wants_json_request(request):
        role = (session.get("role") or "").strip().upper()
        if role not in {ROLE_ADMIN, ROLE_SHOP_OWNER}:
            return jsonify({"success": False, "error": "forbidden"}), 403

        payload = request_payload(request)
        store_id = (payload.get("store_id") or payload.get("shop_id") or "").strip()
        if role == ROLE_SHOP_OWNER:
            shop = get_shop_by_owner(session.get("user_id", ""))
            if not shop:
                return jsonify({"success": False, "error": "store not registered"}), 400
            store_id = shop.get("store_id", "") or shop.get("shop_id", "")

        try:
            book = create_role_book(payload, shop_id=store_id)
            return jsonify({"success": True, "book": book}), 201
        except Exception as e:
            return jsonify({"success": False, "error": str(e)}), 400

    if not admin_required():
        return "ACCESS DENIED"

    current_store = get_current_store_id()
    user_data = get_user_doc()
    super_admin = is_superadmin(user_data)
    store_id = current_store
    if request.method == "POST":
        if super_admin:
            requested_store = (request.form.get("store_id") or "").strip()
            if requested_store and get_store_doc(requested_store):
                store_id = requested_store
        image_value = (request.form.get("image") or "").strip()
        image_file = request.files.get("image_file")

        if image_file and image_file.filename:
            filename = secure_filename(image_file.filename)
            if not allowed_image(filename):
                flash("Invalid image type. Use jpg, jpeg, png, webp, or gif.", "error")
                return redirect("/add-book")

            ext = filename.rsplit(".", 1)[1].lower()
            image_value = f"{uuid.uuid4().hex}.{ext}"
            os.makedirs(app.config["UPLOAD_FOLDER"], exist_ok=True)
            image_file.save(os.path.join(app.config["UPLOAD_FOLDER"], image_value))
        elif image_value and not image_value.startswith("http"):
            image_value = image_value.replace("\\", "/").split("/")[-1]

        if not image_value:
            flash("Add an image file or image name.", "error")
            return redirect("/add-book")

        category_id = (request.form.get("category_id") or "").strip()
        category_doc = db.collection("categories").document(category_id).get() if category_id else None
        if category_id and (not category_doc or not category_doc.exists):
            category_id = ""

        db.collection("books").add(
            {
                "title": request.form["title"],
                "author": request.form["author"],
                "description": request.form["description"],
                "price": request.form["price"],
                "category": category_id,
                "image": image_value,
                "store_id": store_id,
                "created_at": datetime.datetime.utcnow().isoformat(),
            }
        )
        flash("Book added successfully", "success")
        return redirect("/admin")

    categories = list_categories_for_store(store_id, include_all=True)
    return render_template(
        "add_book.html",
        categories=categories,
        stores=stores_for_user(user_data),
        active_store_id=store_id,
        is_super_admin=super_admin,
    )


@app.route("/delete-book/<id>")
def delete_book(id):
    if not admin_required():
        return "ACCESS DENIED"

    store_id = get_current_store_id()
    book = get_book_if_store_matches(id, store_id)
    if book or is_superadmin(get_user_doc()):
        db.collection("books").document(id).delete()
    return redirect("/admin")


@app.route("/update-book-price/<id>", methods=["POST"])
def update_book_price(id):
    if not admin_required():
        return "ACCESS DENIED"

    new_price = to_int(request.form.get("price"), -1)
    if new_price < 0:
        flash("Invalid price", "error")
        return redirect("/admin")

    snap = db.collection("books").document(id).get()
    if not snap.exists:
        flash("Book not found", "error")
        return redirect("/admin")

    data = snap.to_dict() or {}
    store_id = get_doc_store_id(data)
    user_data = get_user_doc()
    if not is_superadmin(user_data) and store_id != get_current_store_id():
        return "ACCESS DENIED"

    db.collection("books").document(id).set(
        {
            "price": new_price,
            "updated_at": datetime.datetime.utcnow().isoformat(),
            "updated_by": session.get("user"),
        },
        merge=True,
    )
    flash("Book price updated", "success")
    return redirect("/admin")


@app.route("/add-category", methods=["POST"])
def add_category():
    if not admin_required("manage_categories"):
        return "ACCESS DENIED"

    category_name = (request.form.get("name") or "").strip()
    if not category_name:
        flash("Category name required", "error")
        return redirect("/admin")

    db.collection("categories").add(
        {
            "name": category_name,
            "store_id": get_current_store_id(),
            "shared": True,
            "created_at": datetime.datetime.utcnow().isoformat(),
        }
    )
    return redirect("/admin")


@app.route("/delete-category/<id>")
def delete_category(id):
    if not admin_required("manage_categories"):
        return "ACCESS DENIED"

    store_id = get_current_store_id()
    doc = db.collection("categories").document(id).get()
    if doc.exists:
        data = doc.to_dict() or {}
        if is_superadmin(get_user_doc()) or get_doc_store_id(data) == store_id:
            db.collection("categories").document(id).delete()
    return redirect("/admin")


@app.route("/api/categories")
def get_categories():
    store_id = (request.args.get("store_id") or "").strip()
    if not store_id:
        store_id = get_current_store_id() if "user" in session else DEFAULT_STORE_ID
    include_all = (request.args.get("all") or "").strip() == "1"
    dedupe = (request.args.get("dedupe") or "").strip() == "1"
    rows = list_categories_for_store(store_id, include_all=include_all)
    data = [{"id": row["id"], "name": row["name"]} for row in rows]
    if dedupe:
        seen = set()
        unique = []
        for row in data:
            key = (row.get("name") or "").strip().lower()
            if not key or key in seen:
                continue
            seen.add(key)
            unique.append(row)
        data = unique
    return jsonify(data)


@app.route("/make-admin/<email>")
def make_admin(email):
    if "user" not in session or not is_superadmin(get_user_doc()):
        return "ACCESS DENIED"
    target_email = normalize_email(email)
    user_doc_ref(target_email).set(
        {
            "email": target_email,
            "is_admin": 1,
            "global_role": "superadmin",
            "updated_at": datetime.datetime.utcnow().isoformat(),
        },
        merge=True,
    )
    return "Admin created successfully"


@app.route("/api/wishlist/add", methods=["POST"])
def add_wishlist():
    if "user" not in session:
        return jsonify({"error": "login required"})

    data = request.get_json(silent=True) or {}
    book_id = str(data.get("book_id") or "").strip()
    store_id = (data.get("store_id") or "").strip() or get_current_store_id()
    if not get_book_if_store_matches(book_id, store_id):
        return jsonify({"error": "book not found in selected store"}), 404

    set_current_store(store_id, persist=True)
    wishlist_items_ref(session["user"], store_id).document(book_id).set(
        {"store_id": store_id, "added_at": datetime.datetime.utcnow().isoformat()},
        merge=True,
    )
    return jsonify({"msg": "added"})


@app.route("/api/wishlist")
def view_wishlist():
    if "user" not in session:
        return jsonify([])

    store_id = get_current_store_id()
    data = []
    for item_doc in wishlist_items_ref(session["user"], store_id).stream():
        book = get_book_if_store_matches(item_doc.id, store_id)
        if not book:
            continue
        data.append(
            {
                "id": item_doc.id,
                "title": book.get("title"),
                "price": book.get("price"),
                "image": book.get("image"),
            }
        )
    return jsonify(data)


@app.route("/api/wishlist/delete", methods=["POST"])
def delete_wishlist():
    if "user" not in session:
        return jsonify({"error": "login required"})
    data = request.get_json(silent=True) or {}
    book_id = str(data.get("book_id") or "").strip()
    store_id = get_current_store_id()
    wishlist_items_ref(session["user"], store_id).document(book_id).delete()
    return jsonify({"msg": "removed"})


@app.route("/wishlist")
def wishlist_page():
    if "user" not in session:
        return redirect("/login")
    return render_template("wishlist.html")


# Register modular role-based extensions without removing legacy routes.
register_extended_routes(app)


if __name__ == "__main__":
    app.run(debug=True)
