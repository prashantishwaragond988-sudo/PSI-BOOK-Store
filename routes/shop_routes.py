"""Shop owner dashboard and inventory/order management routes."""

from __future__ import annotations

import os
from pathlib import Path

from flask import Blueprint, current_app, jsonify, redirect, render_template, request, url_for
from werkzeug.utils import secure_filename

from models.constants import ROLE_ADMIN, ROLE_SHOP_OWNER
from services.book_service import create_book, delete_book, list_books, update_book
from services.order_service import list_orders, update_order_status
from services.payout_service import list_payouts
from services.store_service import get_store_by_owner, register_store, update_store
from utils.http import request_data, to_float, utc_now_iso
from utils.role_auth import current_user_id, role_required


shop_bp = Blueprint("shop_routes", __name__)
ALLOWED_IMAGE_EXTS = {"jpg", "jpeg", "png", "webp", "gif"}


def _categories_ref():
    return current_app.config["FIRESTORE_DB"].collection("categories")


def _list_categories():
    cats = []
    for doc in _categories_ref().stream():
        data = doc.to_dict() or {}
        name = (data.get("name") or "").strip()
        if not name:
            continue
        cats.append({"id": doc.id, "name": name, "store_id": data.get("store_id", "")})
    cats.sort(key=lambda c: c["name"].lower())
    return cats


def _save_image(file_storage):
    if not file_storage or not file_storage.filename:
        return ""
    ext = Path(file_storage.filename).suffix.lower().lstrip(".")
    if ext not in ALLOWED_IMAGE_EXTS:
        raise ValueError("Invalid image type. Use jpg, jpeg, png, webp, gif.")

    uploads_dir = Path(current_app.static_folder or "static") / "uploads"
    uploads_dir.mkdir(parents=True, exist_ok=True)
    filename = secure_filename(file_storage.filename)
    dest = uploads_dir / filename
    file_storage.save(dest)
    # Return relative URL usable by frontend
    rel_path = dest.relative_to(Path(current_app.static_folder))
    return url_for("static", filename=str(rel_path).replace("\\", "/"))


@shop_bp.route("/shop/dashboard")
@role_required(ROLE_SHOP_OWNER)
def shop_dashboard():
    owner_id = current_user_id()
    store = get_store_by_owner(owner_id)
    store_id = (store or {}).get("store_id", "")

    books = list_books(store_id=store_id) if store_id else []
    orders = list_orders(store_id=store_id) if store_id else []
    payouts = list_payouts(shop_owner_id=owner_id)
    earnings = round(sum(to_float(order.get("shop_owner_amount"), 0.0) for order in orders), 2)
    categories = _list_categories()

    return render_template(
        "shop/dashboard.html",
        shop=store,
        books=books,
        orders=orders,
        payouts=payouts,
        earnings=earnings,
        categories=categories,
    )


@shop_bp.route("/shop/register-shop", methods=["POST"])
@role_required(ROLE_SHOP_OWNER)
def shop_register():
    payload = request_data(request)
    owner_id = current_user_id()
    try:
        shop = register_store(owner_id=owner_id, payload=payload)
        if request.is_json:
            return jsonify({"success": True, "shop": shop})
        return redirect("/shop/dashboard")
    except Exception as exc:
        if request.is_json:
            return jsonify({"success": False, "error": str(exc)}), 400
        return redirect("/shop/dashboard?error=register-shop")


@shop_bp.route("/shop/update-shop", methods=["POST"])
@role_required(ROLE_SHOP_OWNER)
def shop_update():
    payload = request_data(request)
    owner_id = current_user_id()
    store = get_store_by_owner(owner_id)
    if not store:
        return jsonify({"success": False, "error": "store not found"}), 404

    try:
        updated = update_store(store_id=store["store_id"], payload=payload)
        if request.is_json:
            return jsonify({"success": True, "shop": updated})
        return redirect("/shop/dashboard")
    except Exception as exc:
        if request.is_json:
            return jsonify({"success": False, "error": str(exc)}), 400
        return redirect("/shop/dashboard?error=update-shop")


@shop_bp.route("/shop/add-book", methods=["POST"])
@role_required(ROLE_SHOP_OWNER)
def shop_add_book():
    payload = request_data(request)
    if "image_file" in request.files:
        img_url = _save_image(request.files["image_file"])
        if img_url:
            payload["image_url"] = img_url

    owner_id = current_user_id()
    store = get_store_by_owner(owner_id)
    if not store:
        return jsonify({"success": False, "error": "store not found"}), 404

    try:
        if "category" in payload:
            payload["category"] = str(payload.get("category") or "").strip()
        book = create_book(payload, shop_id=store["store_id"])
        return jsonify({"success": True, "book": book})
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 400


@shop_bp.route("/shop/edit-book/<book_id>", methods=["POST"])
@role_required(ROLE_SHOP_OWNER)
def shop_edit_book(book_id: str):
    payload = request_data(request)
    if "image_file" in request.files:
        img_url = _save_image(request.files["image_file"])
        if img_url:
            payload["image_url"] = img_url
    try:
        book = update_book(book_id=book_id, data=payload)
        return jsonify({"success": True, "book": book})
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 400


@shop_bp.route("/shop/delete-book/<book_id>", methods=["POST"])
@role_required(ROLE_SHOP_OWNER)
def shop_delete_book(book_id: str):
    try:
        delete_book(book_id)
        return jsonify({"success": True})
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 400


@shop_bp.route("/shop/categories", methods=["GET"])
@role_required(ROLE_SHOP_OWNER)
def shop_list_categories():
    return jsonify(_list_categories())


@shop_bp.route("/shop/categories", methods=["POST"])
@role_required(ROLE_SHOP_OWNER)
def shop_add_category():
    payload = request_data(request)
    name = str(payload.get("name") or "").strip()
    if not name:
        return jsonify({"success": False, "error": "category name required"}), 400

    store = get_store_by_owner(current_user_id())
    if not store:
        return jsonify({"success": False, "error": "store not found"}), 404

    _categories_ref().add({"name": name, "store_id": store["store_id"], "created_at": utc_now_iso()})
    return jsonify({"success": True})


@shop_bp.route("/update-order-status", methods=["POST"])
@role_required(ROLE_SHOP_OWNER, ROLE_ADMIN)
def api_update_order_status():
    payload = request_data(request)
    order_id = str(payload.get("order_id") or "").strip()
    order_status = str(payload.get("order_status") or payload.get("status") or "").strip().upper()

    try:
        order = update_order_status(order_id=order_id, status=order_status)
        return jsonify({"success": True, "order": order})
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 400


@shop_bp.route("/shop/orders")
@role_required(ROLE_SHOP_OWNER)
def shop_orders_api():
    store = get_store_by_owner(current_user_id())
    if not store:
        return jsonify([])
    return jsonify(list_orders(store_id=store["store_id"]))


@shop_bp.route("/shop/earnings")
@role_required(ROLE_SHOP_OWNER)
def shop_earnings_api():
    store = get_store_by_owner(current_user_id())
    if not store:
        return jsonify({"earnings": 0, "orders": 0})

    orders = list_orders(store_id=store["store_id"])
    earnings = round(sum(to_float(row.get("shop_owner_amount"), 0.0) for row in orders), 2)
    return jsonify({"earnings": earnings, "orders": len(orders)})


@shop_bp.route("/shop/payout-history")
@role_required(ROLE_SHOP_OWNER)
def shop_payout_history():
    rows = list_payouts(shop_owner_id=current_user_id())
    return jsonify(rows)
