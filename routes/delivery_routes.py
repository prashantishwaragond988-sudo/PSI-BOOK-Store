"""Delivery agent APIs and pages for duty, status, cash collection, and GPS tracking."""

from __future__ import annotations

from flask import Blueprint, jsonify, redirect, render_template, request, session

from models.constants import ROLE_DELIVERY_AGENT
from services.delivery_service import (
    collect_payment,
    create_or_update_delivery,
    get_delivery,
    list_agent_deliveries,
    submit_cash_to_admin,
    update_delivery_status,
    update_location,
)
from services.user_role_service import authenticate_user, get_user_by_id
from utils.http import request_data, wants_json
from utils.role_auth import current_role, current_user_id, set_role_session


delivery_bp = Blueprint("delivery_routes", __name__)


def _resolve_delivery_agent_id(payload: dict | None = None) -> str:
    payload = payload or {}

    if current_role() == ROLE_DELIVERY_AGENT and current_user_id():
        return current_user_id()

    candidate = str(
        payload.get("delivery_agent_id")
        or request.args.get("delivery_agent_id")
        or ""
    ).strip()
    if not candidate:
        return ""

    user = get_user_by_id(candidate)
    if not user:
        return ""
    if str(user.get("role") or "").strip().upper() != ROLE_DELIVERY_AGENT:
        return ""
    return candidate


def _delivery_auth_failed():
    if wants_json(request):
        return jsonify({"success": False, "error": "delivery authentication required"}), 401
    return redirect("/delivery/login")


@delivery_bp.route("/delivery/login", methods=["GET", "POST"])
def delivery_login():
    if request.method == "GET":
        return render_template("delivery/login.html")

    payload = request_data(request)
    email = str(payload.get("email") or "").strip().lower()
    password = str(payload.get("password") or "")

    user, err = authenticate_user(email=email, password=password, expected_role=ROLE_DELIVERY_AGENT)
    if err:
        if wants_json(request):
            return jsonify({"success": False, "error": err}), 401
        return render_template("delivery/login.html", error=err, email=email), 401

    set_role_session(user_id=user["user_id"], role=user["role"])
    session["user"] = user.get("email", "")

    if wants_json(request):
        return jsonify(
            {
                "success": True,
                "delivery_agent_id": user["user_id"],
                "name": user.get("name", ""),
                "role": user.get("role", ""),
                "redirect": "/delivery/dashboard",
            }
        )

    return redirect("/delivery/dashboard")


@delivery_bp.route("/delivery/logout")
def delivery_logout():
    session.clear()
    return redirect("/delivery/login")


@delivery_bp.route("/delivery/dashboard")
def delivery_dashboard():
    agent_id = _resolve_delivery_agent_id({})
    if not agent_id:
        return _delivery_auth_failed()

    agent = get_user_by_id(agent_id) or {"user_id": agent_id, "name": ""}
    rows = list_agent_deliveries(agent_id)
    return render_template("delivery/dashboard.html", deliveries=rows, agent=agent)


@delivery_bp.route("/delivery/assigned")
def delivery_assigned():
    payload = request_data(request)
    agent_id = _resolve_delivery_agent_id(payload)
    if not agent_id:
        return _delivery_auth_failed()

    rows = list_agent_deliveries(agent_id)
    return jsonify(rows)


@delivery_bp.route("/delivery/accept", methods=["POST"])
def delivery_accept():
    payload = request_data(request)
    order_id = str(payload.get("order_id") or "").strip()
    agent_id = _resolve_delivery_agent_id(payload)
    if not agent_id:
        return _delivery_auth_failed()

    try:
        row = create_or_update_delivery(order_id=order_id, delivery_agent_id=agent_id, status="ASSIGNED")
        return jsonify({"success": True, "delivery": row})
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 400


@delivery_bp.route("/delivery/update-status", methods=["POST"])
def delivery_update_status():
    payload = request_data(request)
    delivery_id = str(payload.get("delivery_id") or payload.get("order_id") or "").strip()
    status = str(payload.get("status") or "").strip().upper()
    agent_id = _resolve_delivery_agent_id(payload)
    if not agent_id:
        return _delivery_auth_failed()

    try:
        delivery = get_delivery(delivery_id)
        if delivery and str(delivery.get("delivery_agent_id") or "") not in {"", agent_id}:
            return jsonify({"success": False, "error": "delivery assigned to another agent"}), 403

        if not delivery:
            row = create_or_update_delivery(order_id=delivery_id, delivery_agent_id=agent_id, status=status)
        else:
            row = update_delivery_status(delivery_id=delivery_id, status=status)

        return jsonify({"success": True, "delivery": row})
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 400


@delivery_bp.route("/delivery/collect-payment", methods=["POST"])
def delivery_collect_payment():
    payload = request_data(request)
    order_id = str(payload.get("order_id") or "").strip()
    amount = payload.get("amount")
    note = str(payload.get("note") or "").strip()
    agent_id = _resolve_delivery_agent_id(payload)
    if not agent_id:
        return _delivery_auth_failed()

    try:
        handover = collect_payment(
            order_id=order_id,
            delivery_agent_id=agent_id,
            amount=amount,
            note=note,
        )
        return jsonify({"success": True, "handover": handover})
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 400


@delivery_bp.route("/delivery/submit-cash", methods=["POST"])
def delivery_submit_cash():
    payload = request_data(request)
    order_id = str(payload.get("order_id") or "").strip()
    agent_id = _resolve_delivery_agent_id(payload)
    if not agent_id:
        return _delivery_auth_failed()

    try:
        handover = submit_cash_to_admin(order_id=order_id, delivery_agent_id=agent_id)
        return jsonify({"success": True, "handover": handover})
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 400


@delivery_bp.route("/update-location", methods=["POST"])
def api_update_location():
    payload = request_data(request)

    delivery_agent_id = str(payload.get("delivery_agent_id") or _resolve_delivery_agent_id(payload) or "").strip()
    order_id = str(payload.get("order_id") or "").strip()
    latitude = payload.get("latitude")
    longitude = payload.get("longitude")
    timestamp = str(payload.get("timestamp") or "").strip()

    try:
        saved = update_location(
            delivery_agent_id=delivery_agent_id,
            order_id=order_id,
            latitude=latitude,
            longitude=longitude,
            timestamp=timestamp,
        )
        return jsonify({"success": True, "location": saved})
    except Exception as exc:
        return jsonify({"success": False, "error": str(exc)}), 400
