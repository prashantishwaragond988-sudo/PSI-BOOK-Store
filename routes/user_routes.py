"""Customer-facing APIs and pages (browse, order, tracking, invoice)."""

from __future__ import annotations

from flask import Blueprint, Response, jsonify, render_template, request, session

from models.constants import ROLE_CUSTOMER
from services.book_service import get_book, list_books
from services.delivery_service import latest_location
from services.invoice_service import invoice_data, invoice_pdf_bytes
from services.order_service import create_order, list_orders, track_order
from services.user_role_service import get_user_by_id
from services.firestore_ctx import get_db
from utils.http import request_data, wants_json, utc_now_iso
from utils.role_auth import current_user_id, role_required


user_bp = Blueprint("user_routes", __name__)


@user_bp.route("/user/home")
def user_home():
    return render_template("user/home.html")


@user_bp.route("/user/profile")
@role_required(ROLE_CUSTOMER)
def user_profile():
    user = get_user_by_id(current_user_id()) or {}
    return render_template("profile.html", user=user)


@user_bp.route("/user/help")
def user_help():
    return render_template("help.html")


@user_bp.route("/user/about")
def user_about():
    return render_template("about.html")


@user_bp.route("/user/orders-page")
@role_required(ROLE_CUSTOMER)
def user_orders_page():
    orders = list_orders(user_id=current_user_id())
    return render_template("orders.html", orders=orders)


@user_bp.route("/user/checkout")
@role_required(ROLE_CUSTOMER)
def user_checkout():
    return render_template("checkout.html")


@user_bp.route("/user/payment")
@role_required(ROLE_CUSTOMER)
def user_payment():
    uid = current_user_id()
    user = get_user_by_id(uid) or {}
    selected_id = user.get("selected_address_id", "")
    selected = {}
    for doc in _addr_ref(uid).stream():
        if doc.id == selected_id:
            selected = doc.to_dict() or {}
            selected.setdefault("id", doc.id)
            break
    if not selected:
        return redirect("/user/checkout")
    return render_template("payment.html", selected_address=selected)


@user_bp.route("/user/wishlist-page")
@role_required(ROLE_CUSTOMER)
def user_wishlist_page():
    return render_template("wishlist.html")


@user_bp.route("/user/store")
def user_store_landing():
    return render_template("store.html")


@user_bp.route("/user/location", methods=["POST"])
@role_required(ROLE_CUSTOMER)
def user_save_location():
    payload = request_data(request)
    address = payload.get("address") or {}
    db = get_db()
    db.collection("users").document(current_user_id()).set(
        {"address": address}, merge=True
    )
    return jsonify({"success": True, "address": address})


# Address book APIs ----------------------------------------------------

def _addr_ref(user_id):
    return get_db().collection("users").document(user_id).collection("addresses")


def _cart_ref(user_id):
    return get_db().collection("carts").document(user_id)


@user_bp.route("/api/address", methods=["GET"])
@role_required(ROLE_CUSTOMER)
def list_addresses():
    uid = current_user_id()
    selected = (get_user_by_id(uid) or {}).get("selected_address_id", "")
    rows = []
    for doc in _addr_ref(uid).stream():
        row = doc.to_dict() or {}
        row.setdefault("id", doc.id)
        rows.append(row)
    rows.sort(key=lambda r: r.get("created_at", ""))
    return jsonify({"addresses": rows, "selected_address_id": selected})


@user_bp.route("/api/address", methods=["POST"])
@role_required(ROLE_CUSTOMER)
def create_address():
    uid = current_user_id()
    data = request_data(request)
    required = ["fullname", "mobile", "city", "pincode", "street"]
    for key in required:
        if not str(data.get(key) or "").strip():
            return jsonify({"error": f"{key} required"}), 400

    addr = {
        "address_type": str(data.get("address_type") or "Home"),
        "fullname": str(data.get("fullname") or "").strip(),
        "mobile": str(data.get("mobile") or "").strip(),
        "city": str(data.get("city") or "").strip(),
        "pincode": str(data.get("pincode") or "").strip(),
        "street": str(data.get("street") or "").strip(),
        "landmark": str(data.get("landmark") or "").strip(),
        "created_at": utc_now_iso(),
    }
    doc = _addr_ref(uid).document()
    doc.set(addr | {"id": doc.id})

    # Optionally set default
    if data.get("is_default"):
        get_db().collection("users").document(uid).set(
            {"selected_address_id": doc.id}, merge=True
        )

    return jsonify({"success": True, "address_id": doc.id})


@user_bp.route("/api/address/select", methods=["POST"])
@role_required(ROLE_CUSTOMER)
def select_address():
    uid = current_user_id()
    data = request_data(request)
    addr_id = str(data.get("address_id") or "").strip()
    if not addr_id:
        return jsonify({"error": "address_id required"}), 400

    if not _addr_ref(uid).document(addr_id).get().exists:
        return jsonify({"error": "address not found"}), 404

    get_db().collection("users").document(uid).set(
        {"selected_address_id": addr_id}, merge=True
    )
    return jsonify({"success": True, "address_id": addr_id})


# Cart persistence -----------------------------------------------------
@user_bp.route("/api/cart", methods=["GET"])
@role_required(ROLE_CUSTOMER)
def get_cart():
    uid = current_user_id()
    doc = _cart_ref(uid).get()
    if not doc.exists:
        return jsonify({"items": []})
    data = doc.to_dict() or {}
    return jsonify({"items": data.get("items", [])})


@user_bp.route("/api/cart", methods=["POST"])
@role_required(ROLE_CUSTOMER)
def save_cart():
    uid = current_user_id()
    payload = request_data(request)
    items = payload.get("items")
    if not isinstance(items, list):
        return jsonify({"error": "items must be a list"}), 400
    _cart_ref(uid).set(
        {"items": items, "updated_at": utc_now_iso()},
        merge=True,
    )
    return jsonify({"success": True})


@user_bp.route("/api/order", methods=["POST"])
@role_required(ROLE_CUSTOMER)
def place_order_from_cart():
    uid = current_user_id()
    payload = request_data(request)
    payment_method = str(payload.get("payment_method") or "COD").upper()
    payment_status = "PAID" if payment_method != "COD" else "PENDING"
    address_id = str(payload.get("address_id") or "").strip()

    cart_doc = _cart_ref(uid).get()
    cart_items = (cart_doc.to_dict() or {}).get("items", []) if cart_doc.exists else []
    if not cart_items:
        return jsonify({"error": "Cart is empty"}), 400

    store_ids = {str(it.get("store_id") or it.get("shop_id") or "").strip() for it in cart_items if (it.get("store_id") or it.get("shop_id"))}
    if len(store_ids) != 1:
        return jsonify({"error": "Order must contain items from a single store"}), 400
    store_id = store_ids.pop()

    items = []
    for it in cart_items:
        if not it.get("book_id"):
            continue
        items.append(
            {
                "book_id": it.get("book_id"),
                "quantity": int(it.get("qty") or it.get("quantity") or 1),
                "price": float(it.get("price") or 0),
            }
        )

    if not items:
        return jsonify({"error": "No valid items in cart"}), 400

    order_payload = {
        "store_id": store_id,
        "items": items,
        "delivery_type": "LOCAL",
        "payment_method": payment_method,
        "payment_status": payment_status,
    }

    try:
        order = create_order(user_id=uid, payload=order_payload)
        _cart_ref(uid).delete()
        # Optionally tag address used
        if address_id:
            get_db().collection("users").document(uid).set(
                {"last_address_id": address_id}, merge=True
            )
        return jsonify({"success": True, "order_id": order["order_id"], "redirect": f"/order/{order['order_id']}/invoice"})
    except Exception as exc:
        return jsonify({"error": str(exc)}), 400


@user_bp.route("/user/theme", methods=["POST"])
def set_theme():
    data = request_data(request)
    theme = (data.get("theme") or "light").lower()
    session["theme"] = "dark" if theme == "dark" else "light"
    return jsonify({"success": True, "theme": session["theme"]})


@user_bp.route("/user/theme")
def get_theme():
    return jsonify({"theme": session.get("theme", "light")})


@user_bp.route("/books")
def api_books():
    search = str(request.args.get("search") or "").strip()
    store_id = str(request.args.get("store_id") or request.args.get("shop_id") or "").strip()
    books = list_books(search=search, store_id=store_id)
    return jsonify(books)


@user_bp.route("/book/<book_id>")
def book_details(book_id: str):
    book = get_book(book_id)
    if not book:
        return jsonify({"error": "book not found"}), 404

    if wants_json(request):
        return jsonify(book)
    return render_template("user/book_details.html", book=book)


@user_bp.route("/create-order", methods=["POST"])
@role_required(ROLE_CUSTOMER)
def api_create_order():
    payload = request_data(request)
    user_id = current_user_id()

    try:
        order = create_order(user_id=user_id, payload=payload)
        return jsonify({"success": True, "order": order})
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 400


@user_bp.route("/user/orders")
@role_required(ROLE_CUSTOMER)
def user_orders():
    return jsonify(list_orders(user_id=current_user_id()))


@user_bp.route("/track-order")
def api_track_order():
    order_id = str(request.args.get("order_id") or "").strip()
    if not order_id:
        return jsonify({"error": "order_id required"}), 400

    try:
        tracking = track_order(order_id)
        tracking["latest_location"] = latest_location(order_id)
        return jsonify(tracking)
    except Exception as exc:
        return jsonify({"error": str(exc)}), 404


@user_bp.route("/user/track-order")
@role_required(ROLE_CUSTOMER)
def user_track_order_page():
    order_id = str(request.args.get("order_id") or "").strip()
    return render_template("user/track_order.html", order_id=order_id)


@user_bp.route("/order/<order_id>/invoice")
def order_invoice_page(order_id: str):
    try:
        data = invoice_data(order_id)
    except Exception as exc:
        return jsonify({"error": str(exc)}), 404

    format_type = str(request.args.get("format") or "").strip().lower()
    if format_type == "pdf":
        try:
            content = invoice_pdf_bytes(data)
            return Response(
                content,
                mimetype="application/pdf",
                headers={
                    "Content-Disposition": f"attachment; filename=invoice-{order_id}.pdf",
                },
            )
        except Exception as exc:
            return jsonify({"error": str(exc)}), 500

    return render_template("invoice.html", invoice=data, invoice_items=data.get("items", []))


@user_bp.route("/invoice")
def api_invoice():
    order_id = str(request.args.get("order_id") or "").strip()
    if not order_id:
        return jsonify({"error": "order_id required"}), 400

    try:
        data = invoice_data(order_id)
    except Exception as exc:
        return jsonify({"error": str(exc)}), 404

    format_type = str(request.args.get("format") or "").strip().lower()
    if format_type == "pdf":
        try:
            content = invoice_pdf_bytes(data)
            return Response(
                content,
                mimetype="application/pdf",
                headers={
                    "Content-Disposition": f"attachment; filename=invoice-{order_id}.pdf",
                },
            )
        except Exception as exc:
            return jsonify({"error": str(exc)}), 500

    return jsonify(data)
