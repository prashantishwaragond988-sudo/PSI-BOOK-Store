"""Admin dashboard and management endpoints."""

from __future__ import annotations

import os
import uuid
from datetime import datetime, timedelta, timezone
from typing import Dict, List

from flask import Blueprint, jsonify, redirect, render_template, request

from models.constants import ROLE_ADMIN, ROLE_CUSTOMER, ROLE_DELIVERY_AGENT, ROLE_SHOP_OWNER
from services.analytics_service import commission_report, dashboard_analytics, sales_report
from services.book_service import list_books
from services.delivery_service import confirm_cash_received, list_cash_handovers
from services.firestore_ctx import get_db
from services.order_service import assign_delivery_agent, list_orders, order_totals_snapshot
from services.payout_service import create_weekly_payout, list_payouts, mark_payout_paid, weekly_reports
from services.store_service import approve_store, list_stores, search_stores
from services.user_role_service import (
    get_user_by_id,
    get_user_by_email,
    list_users,
    register_user,
    set_user_role,
    update_password,
    update_user_status,
)
from utils.http import request_data, utc_now_iso, wants_json
from utils.role_auth import current_user_id, role_required


admin_bp = Blueprint("admin_routes", __name__)


CONTROL_PAGE_REDIRECT = {
    "users": "/admin/users",
    "approve-stores": "/admin/stores",
    "stores": "/admin/stores",
    "books": "/admin/books",
    "add-store": "/admin/stores#add-store",
    "remove-store": "/admin/stores#stores-list",
    "add-owner": "/admin/stores#owners",
    "remove-owner": "/admin/stores#owners",
    "add-delivery": "/admin/delivery#add-agent",
    "assign-delivery": "/admin/orders#assign",
    "orders": "/admin/orders",
    "payouts": "/admin/payouts",
    "analytics": "/admin/analytics",
    "agents": "/admin/delivery",
    "delivery-cash": "/admin/delivery#cash",
}


def _admin_profile() -> Dict[str, str]:
    """Static admin profile info for sidebar."""
    return {
        "name": os.getenv("ADMIN_DISPLAY_NAME", "Platform Admin"),
        "email": os.getenv("ADMIN_DISPLAY_EMAIL", "admin@psi-book-store.com"),
        "photo": os.getenv(
            "ADMIN_DISPLAY_PHOTO",
            "https://ui-avatars.com/api/?name=Admin&background=1f5fe0&color=fff",
        ),
    }


def _parse_date(value: str):
    text = (value or "").strip()
    if not text:
        return None
    try:
        dt = datetime.fromisoformat(text.replace("Z", "+00:00"))
    except Exception:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _user_counts(users: List[Dict]) -> Dict[str, int]:
    counts = {"total": len(users), "sellers": 0, "delivery": 0, "customers": 0, "admins": 0}
    for user in users:
        role = str(user.get("role") or "").upper()
        if role == ROLE_SHOP_OWNER:
            counts["sellers"] += 1
        elif role == ROLE_DELIVERY_AGENT:
            counts["delivery"] += 1
        elif role == ROLE_ADMIN:
            counts["admins"] += 1
        else:
            counts["customers"] += 1
    return counts


def _weekly_orders_chart(orders: List[Dict], days: int = 7) -> List[Dict]:
    today = datetime.now(timezone.utc).date()
    buckets = []
    for idx in range(days):
        day = today - timedelta(days=days - idx - 1)
        buckets.append({"date": day.isoformat(), "label": day.strftime("%a"), "count": 0})

    by_date = {bucket["date"]: bucket for bucket in buckets}
    for order in orders:
        dt = _parse_date(order.get("created_at") or order.get("time") or "")
        if not dt:
            continue
        date_key = dt.date().isoformat()
        if date_key in by_date:
            by_date[date_key]["count"] += 1
    return buckets


def _revenue_chart(orders: List[Dict], days: int = 7) -> List[Dict]:
    today = datetime.now(timezone.utc).date()
    buckets = []
    for idx in range(days):
        day = today - timedelta(days=days - idx - 1)
        buckets.append(
            {
                "date": day.isoformat(),
                "label": day.strftime("%a"),
                "admin_commission": 0.0,
                "seller_payout": 0.0,
            }
        )
    by_date = {bucket["date"]: bucket for bucket in buckets}
    for order in orders:
        dt = _parse_date(order.get("created_at") or order.get("time") or "")
        if not dt:
            continue
        key = dt.date().isoformat()
        bucket = by_date.get(key)
        if not bucket:
            continue
        bucket["admin_commission"] += float(order.get("admin_commission") or 0.0)
        bucket["seller_payout"] += float(order.get("shop_owner_amount") or 0.0)
    for bucket in buckets:
        bucket["admin_commission"] = round(bucket["admin_commission"], 2)
        bucket["seller_payout"] = round(bucket["seller_payout"], 2)
    return buckets


def _profile_cards(users: List[Dict]) -> List[Dict]:
    cards: List[Dict] = []
    for user in users:
        cards.append(
            {
                "user_id": user.get("user_id"),
                "name": user.get("name") or "User",
                "email": user.get("email") or "",
                "role": user.get("role") or "CUSTOMER",
                "photo": user.get("photo") or user.get("avatar") or "",
            }
        )
    return cards


def _dashboard_context():
    analytics = dashboard_analytics()
    stores = list_stores()
    users = list_users()
    owners = [row for row in users if row.get("role") == ROLE_SHOP_OWNER]
    books = list_books()
    orders = list_orders()
    payouts = list_payouts()
    weekly = weekly_reports()
    delivery_agents = [row for row in users if row.get("role") == ROLE_DELIVERY_AGENT]
    handovers = list_cash_handovers()
    return {
        "analytics": analytics,
        "admin_profile": _admin_profile(),
        "users": users,
        "shop_owners": owners,
        "delivery_agents": delivery_agents,
        "stores": stores,
        "books": books,
        "orders": orders,
        "payouts": payouts,
        "weekly_reports": weekly,
        "cash_handovers": handovers,
        "user_counts": _user_counts(users),
        "weekly_orders_chart": _weekly_orders_chart(orders),
        "revenue_chart": _revenue_chart(orders),
        "profile_cards": _profile_cards(users),
    }


@admin_bp.route("/admin/dashboard")
@role_required(ROLE_ADMIN)
def admin_dashboard():
    return render_template("admin/dashboard.html", active_page="dashboard", **_dashboard_context())


@admin_bp.route("/admin/control/<page_key>")
@role_required(ROLE_ADMIN)
def admin_control_page(page_key: str):
    target = str(page_key or "").strip().lower()
    target_url = CONTROL_PAGE_REDIRECT.get(target, "/admin/dashboard")
    return redirect(target_url)


@admin_bp.route("/admin/users")
@role_required(ROLE_ADMIN)
def admin_users():
    role = request.args.get("role", "")
    status = request.args.get("status", "")
    rows = list_users(role=role, status=status)
    if wants_json(request):
        return jsonify(rows)

    ctx = _dashboard_context()
    ctx.update({"users": rows, "active_page": "users", "filter_role": role, "filter_status": status})
    return render_template("admin/users.html", **ctx)


@admin_bp.route("/admin/update-user-status", methods=["POST"])
@role_required(ROLE_ADMIN)
def admin_update_user_status():
    payload = request_data(request)
    user_id = str(payload.get("user_id") or "").strip()
    status = str(payload.get("status") or "").strip().upper()

    try:
        updated = update_user_status(user_id=user_id, status=status)
        return jsonify({"success": True, "user": updated})
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 400


@admin_bp.route("/admin/approve-store", methods=["POST"])
@admin_bp.route("/admin/approve-shop", methods=["POST"])  # legacy alias
@role_required(ROLE_ADMIN)
def admin_approve_store():
    payload = request_data(request)
    store_id = str(payload.get("store_id") or payload.get("shop_id") or "").strip()
    status = str(payload.get("status") or "APPROVED").strip().upper()

    if not store_id:
        return jsonify({"success": False, "error": "store_id is required"}), 400

    allowed_status = {"APPROVED", "REJECTED", "PENDING"}
    if status not in allowed_status:
        return jsonify({"success": False, "error": "invalid status"}), 400

    try:
        store = approve_store(store_id=store_id, status=status)
        if wants_json(request):
            return jsonify({"success": True, "store": store})
        return redirect("/admin/dashboard")
    except Exception as exc:
        if wants_json(request):
            return jsonify({"success": False, "error": str(exc)}), 400
        return redirect("/admin/dashboard?error=store")


@admin_bp.route("/admin/stores")
@role_required(ROLE_ADMIN)
def admin_stores():
    ctx = _dashboard_context()
    query = str(request.args.get("q") or "").strip()
    stores = search_stores(query) if query else ctx["stores"]
    ctx.update({"active_page": "stores", "stores": stores, "store_query": query})
    return render_template("admin/stores.html", **ctx)


@admin_bp.route("/admin/stores/search")
@role_required(ROLE_ADMIN)
def admin_store_search_api():
    q = request.args.get("q", "")
    return jsonify(search_stores(q))


@admin_bp.route("/assign-delivery", methods=["POST"])
@role_required(ROLE_ADMIN)
def api_assign_delivery():
    payload = request_data(request)
    order_id = str(payload.get("order_id") or "").strip()
    delivery_agent_id = str(payload.get("delivery_agent_id") or "").strip()

    try:
        order = assign_delivery_agent(order_id=order_id, delivery_agent_id=delivery_agent_id)
        return jsonify({"success": True, "order": order})
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 400


@admin_bp.route("/weekly-payout", methods=["POST"])
@role_required(ROLE_ADMIN)
def api_weekly_payout():
    payload = request_data(request)

    payout_id = str(payload.get("payout_id") or "").strip()
    if payout_id:
        try:
            paid = mark_payout_paid(payout_id)
            return jsonify({"success": True, "payout": paid})
        except Exception as exc:
            return jsonify({"success": False, "error": str(exc)}), 400

    shop_owner_id = str(payload.get("shop_owner_id") or "").strip()
    week_start = str(payload.get("week_start") or "").strip()
    week_end = str(payload.get("week_end") or "").strip()

    try:
        payouts = create_weekly_payout(
            shop_owner_id=shop_owner_id,
            week_start=week_start,
            week_end=week_end,
        )
        return jsonify({"success": True, "payouts": payouts})
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 400


@admin_bp.route("/admin/weekly-report")
@role_required(ROLE_ADMIN)
def admin_weekly_report():
    week_start = request.args.get("week_start", "")
    week_end = request.args.get("week_end", "")
    return jsonify(weekly_reports(week_start=week_start, week_end=week_end))


@admin_bp.route("/admin/analytics")
@role_required(ROLE_ADMIN)
def admin_analytics_api():
    days = int(request.args.get("days", "30") or 30)
    payload = {
        "summary": order_totals_snapshot(),
        "sales_report": sales_report(days=days),
        "commission_report": commission_report(days=days),
    }
    if wants_json(request):
        return jsonify(payload)
    ctx = _dashboard_context()
    ctx.update({"active_page": "analytics", "analytics_api": payload, "analytics_days": days})
    return render_template("admin/analytics.html", **ctx)


@admin_bp.route("/admin/cash-handovers")
@role_required(ROLE_ADMIN)
def admin_cash_handovers():
    status = str(request.args.get("status") or "").strip().upper()
    rows = list_cash_handovers(status=status)
    if wants_json(request):
        return jsonify(rows)
    ctx = _dashboard_context()
    ctx.update({"cash_handovers": rows, "active_page": "delivery"})
    return render_template("admin/delivery.html", **ctx)


@admin_bp.route("/admin/confirm-cash-received", methods=["POST"])
@role_required(ROLE_ADMIN)
def admin_confirm_cash_received():
    payload = request_data(request)
    order_id = str(payload.get("order_id") or "").strip()
    if not order_id:
        return jsonify({"success": False, "error": "order_id is required"}), 400

    try:
        handover = confirm_cash_received(order_id=order_id, admin_user_id=current_user_id())
        return jsonify({"success": True, "handover": handover})
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 400


@admin_bp.route("/admin/add-delivery-agent", methods=["POST"])
@role_required(ROLE_ADMIN)
def admin_add_delivery_agent():
    payload = request_data(request)
    name = str(payload.get("name") or "").strip()
    email = str(payload.get("email") or "").strip().lower()
    phone = str(payload.get("phone") or "").strip()
    password = str(payload.get("password") or "")

    if not email:
        return jsonify({"success": False, "error": "email is required"}), 400

    if not name:
        name = email.split("@", 1)[0]

    try:
        existing = get_user_by_email(email)
        if existing:
            user = set_user_role(existing["user_id"], ROLE_DELIVERY_AGENT, name=name, phone=phone)
            if password:
                update_password(user["user_id"], password)
            return jsonify({"success": True, "user": user, "mode": "updated"})

        if not password:
            return jsonify({"success": False, "error": "password is required for new delivery agent"}), 400

        user = register_user(
            name=name,
            email=email,
            phone=phone,
            password=password,
            role=ROLE_DELIVERY_AGENT,
        )
        return jsonify({"success": True, "user": user, "mode": "created"}), 201
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 400


@admin_bp.route("/admin/orders")
@role_required(ROLE_ADMIN)
def admin_orders_page():
    ctx = _dashboard_context()
    ctx.update({"active_page": "orders"})
    return render_template("admin/orders.html", **ctx)


@admin_bp.route("/admin/books")
@role_required(ROLE_ADMIN)
def admin_books_page():
    ctx = _dashboard_context()
    ctx.update({"active_page": "books"})
    return render_template("admin/books.html", **ctx)


@admin_bp.route("/admin/delivery")
@role_required(ROLE_ADMIN)
def admin_delivery_page():
    ctx = _dashboard_context()
    ctx.update({"active_page": "delivery"})
    return render_template("admin/delivery.html", **ctx)


@admin_bp.route("/admin/payouts")
@role_required(ROLE_ADMIN)
def admin_payouts_page():
    ctx = _dashboard_context()
    ctx.update({"active_page": "payouts"})
    return render_template("admin/payouts.html", **ctx)


@admin_bp.route("/admin/profiles")
@role_required(ROLE_ADMIN)
def admin_profiles_page():
    ctx = _dashboard_context()
    ctx.update({"active_page": "profiles"})
    return render_template("admin/profiles.html", **ctx)


@admin_bp.route("/admin/add-store", methods=["POST"])
@admin_bp.route("/admin/add-shop", methods=["POST"])  # legacy alias
@role_required(ROLE_ADMIN)
def admin_add_store():
    payload = request_data(request)
    name = str(payload.get("name") or payload.get("shop_name") or "").strip()
    owner_id = str(payload.get("owner_id") or "").strip()
    description = str(payload.get("description") or "").strip()
    address = str(payload.get("address") or "").strip()
    phone = str(payload.get("phone") or "").strip()
    store_id = str(payload.get("store_id") or payload.get("shop_id") or "").strip() or f"store-{uuid.uuid4().hex[:10]}"

    if not name:
        return jsonify({"success": False, "error": "store name is required"}), 400

    db = get_db()
    store = {
        "store_id": store_id,
        "name": name,
        "owner_id": owner_id,
        "description": description,
        "address": address,
        "phone": phone,
        "status": "APPROVED",
        "created_at": utc_now_iso(),
    }
    db.collection("stores").document(store_id).set(store, merge=True)
    return jsonify({"success": True, "store": store}), 201


@admin_bp.route("/admin/remove-store", methods=["POST"])
@admin_bp.route("/admin/remove-shop", methods=["POST"])  # legacy alias
@role_required(ROLE_ADMIN)
def admin_remove_store():
    payload = request_data(request)
    store_id = str(payload.get("store_id") or payload.get("shop_id") or "").strip()
    if not store_id:
        return jsonify({"success": False, "error": "store_id is required"}), 400

    db = get_db()
    ref = db.collection("stores").document(store_id)
    snap = ref.get()
    if not snap.exists:
        return jsonify({"success": False, "error": "store not found"}), 404

    ref.delete()
    return jsonify({"success": True, "store_id": store_id})


@admin_bp.route("/admin/add-shop-owner", methods=["POST"])
@role_required(ROLE_ADMIN)
def admin_add_shop_owner():
    payload = request_data(request)
    name = str(payload.get("name") or "").strip()
    email = str(payload.get("email") or "").strip().lower()
    phone = str(payload.get("phone") or "").strip()
    password = str(payload.get("password") or "")
    store_id = str(payload.get("store_id") or payload.get("shop_id") or "").strip()

    if not email:
        return jsonify({"success": False, "error": "email is required"}), 400

    if not name:
        name = email.split("@", 1)[0]

    try:
        existing = get_user_by_email(email)
        if existing:
            user = set_user_role(existing["user_id"], ROLE_SHOP_OWNER, name=name, phone=phone)
            if password:
                update_password(user["user_id"], password)
            mode = "updated"
        else:
            if not password:
                return jsonify({"success": False, "error": "password is required for new shop owner"}), 400
            user = register_user(
                name=name,
                email=email,
                phone=phone,
                password=password,
                role=ROLE_SHOP_OWNER,
            )
            mode = "created"

        if store_id:
            db = get_db()
            db.collection("stores").document(store_id).set(
                {
                    "owner_id": user["user_id"],
                    "owner_email": user.get("email", ""),
                    "updated_at": utc_now_iso(),
                },
                merge=True,
            )

        return jsonify({"success": True, "mode": mode, "user": user})
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 400


@admin_bp.route("/admin/remove-shop-owner", methods=["POST"])
@role_required(ROLE_ADMIN)
def admin_remove_shop_owner():
    payload = request_data(request)
    user_id = str(payload.get("user_id") or "").strip()
    email = str(payload.get("email") or "").strip().lower()

    target = None
    if user_id:
        target = get_user_by_id(user_id)
    if not target and email:
        target = get_user_by_email(email)
    if not target:
        return jsonify({"success": False, "error": "shop owner not found"}), 404

    try:
        updated_user = set_user_role(
            user_id=target["user_id"],
            role=ROLE_CUSTOMER,
            name=target.get("name", ""),
            phone=target.get("phone", ""),
        )

        db = get_db()
        cleared = 0
        for doc in db.collection("stores").where("owner_id", "==", target["user_id"]).stream():
            doc.reference.set(
                {
                    "owner_id": "",
                    "owner_email": "",
                    "updated_at": utc_now_iso(),
                },
                merge=True,
            )
            cleared += 1

        return jsonify({"success": True, "user": updated_user, "stores_unassigned": cleared})
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 400
