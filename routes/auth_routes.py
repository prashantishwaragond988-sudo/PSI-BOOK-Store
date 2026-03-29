"""Role-based login selection and role-specific login pages."""

from __future__ import annotations

from flask import Blueprint, jsonify, redirect, render_template, request, session, current_app, flash

from models.constants import ROLE_ADMIN, ROLE_CUSTOMER, ROLE_DELIVERY_AGENT, ROLE_SHOP_OWNER
from services.user_role_service import authenticate_user, get_user_by_phone, register_user
from utils.http import normalize_phone, request_data, wants_json
from utils.role_auth import clear_role_session, set_role_session


auth_bp = Blueprint("role_auth_routes", __name__)


ROLE_LOGIN_CONFIG = {
    ROLE_ADMIN: {
        "title": "Admin Login",
        "path": "/admin/login",
        "next": "/admin/dashboard",
    },
    ROLE_SHOP_OWNER: {
        "title": "Shop Owner Login",
        "path": "/shop/login",
        "next": "/shop/dashboard",
    },
    ROLE_CUSTOMER: {
        "title": "User Login",
        "path": "/user/login",
        "next": "/user/home",
    },
}


def _allowed_roles():
    allowed = current_app.config.get("ALLOWED_ROLES")
    if not allowed:
        return ROLE_LOGIN_CONFIG
    allowed_set = {str(role or "").strip().upper() for role in allowed}
    return {k: v for k, v in ROLE_LOGIN_CONFIG.items() if k in allowed_set}


def _resolve_email(identifier: str) -> str:
    identifier = str(identifier or "").strip()
    phone = normalize_phone(identifier)
    email = identifier.lower()
    if phone.isdigit():
        phone_user = get_user_by_phone(phone)
        if phone_user and phone_user.get("email"):
            email = str(phone_user.get("email")).strip().lower()
    return email


def _role_redirect(role: str) -> str:
    role = str(role or "").strip().upper()
    conf = _allowed_roles().get(role, ROLE_LOGIN_CONFIG.get(role, {}))
    if conf.get("next"):
        return str(conf["next"])
    return "/login-selection"


def _auto_login():
    payload = request_data(request)
    identifier = str(payload.get("email") or payload.get("value") or payload.get("identifier") or "").strip()
    email = _resolve_email(identifier)
    password = str(payload.get("password") or "")

    user, err = authenticate_user(email=email, password=password, expected_role="")
    if err:
        if wants_json(request):
            return jsonify({"success": False, "error": err}), 401
        return render_template(
            "login_selection.html",
            error=err,
            identifier=identifier,
            roles=_allowed_roles(),
        )

    if user.get("role") not in _allowed_roles():
        msg = "Use the correct portal for your role."
        if wants_json(request):
            return jsonify({"success": False, "error": msg}), 403
        return render_template(
            "login_selection.html",
            error=msg,
            identifier=identifier,
            roles=_allowed_roles(),
        )

    if user.get("role") == ROLE_DELIVERY_AGENT:
        msg = "Delivery Agent should login from delivery app."
        if wants_json(request):
            return jsonify({"success": False, "error": msg}), 403
        return render_template(
            "login_selection.html",
            error=msg,
            identifier=identifier,
        )

    set_role_session(user_id=user["user_id"], role=user["role"])
    session["user"] = user.get("email", "")

    redirect_to = _role_redirect(user.get("role"))
    if wants_json(request):
        return jsonify({"success": True, "redirect": redirect_to, "user": user})
    return redirect(redirect_to)


@auth_bp.route("/login-selection", methods=["GET", "POST"])
def login_selection():
    if request.method == "POST":
        return _auto_login()
    return render_template("login_selection.html", roles=_allowed_roles())


@auth_bp.route("/role/logout")
def role_logout():
    clear_role_session()
    session.pop("user", None)
    return redirect("/login-selection")


def _role_login(role: str):
    roles = _allowed_roles()
    if role not in roles:
        return redirect("/login-selection")

    conf = roles[role]

    if request.method == "GET":
        return render_template(
            "role_login.html",
            role=role,
            title=conf["title"],
            post_url=conf["path"],
            next_url=conf["next"],
        )

    payload = request_data(request)
    identifier = str(payload.get("email") or payload.get("value") or "").strip()
    email = _resolve_email(identifier)
    password = str(payload.get("password") or "")

    user, err = authenticate_user(email=email, password=password, expected_role=role)
    if err:
        if wants_json(request):
            return jsonify({"success": False, "error": err}), 401
        return render_template(
            "role_login.html",
            role=role,
            title=conf["title"],
            post_url=conf["path"],
            next_url=conf["next"],
            error=err,
            email=email,
        )

    set_role_session(user_id=user["user_id"], role=user["role"])
    session["user"] = user.get("email", "")  # Backward compatibility with legacy pages.

    if wants_json(request):
        return jsonify({"success": True, "redirect": conf["next"], "user": user})

    return redirect(conf["next"])


@auth_bp.route("/admin/login", methods=["GET", "POST"])
def admin_login():
    return _role_login(ROLE_ADMIN)


@auth_bp.route("/shop/login", methods=["GET", "POST"])
def shop_login():
    return _role_login(ROLE_SHOP_OWNER)


@auth_bp.route("/user/login", methods=["GET", "POST"])
def user_login():
    return _role_login(ROLE_CUSTOMER)


@auth_bp.route("/user/register", methods=["GET", "POST"])
def user_register():
    # Only available when customer role is allowed for this site.
    if ROLE_CUSTOMER not in _allowed_roles():
        return redirect("/login-selection")

    if request.method == "GET":
        return render_template("register.html")

    payload = request_data(request)
    name = str(payload.get("name") or payload.get("full_name") or "").strip()
    email = str(payload.get("email") or "").strip().lower()
    phone = normalize_phone(payload.get("mobile") or payload.get("phone") or "")
    password = str(payload.get("password") or "").strip()

    try:
        user = register_user(name=name, email=email, phone=phone, password=password, role=ROLE_CUSTOMER)
    except Exception as exc:
        msg = str(exc)
        if wants_json(request):
            return jsonify({"success": False, "error": msg}), 400
        flash(msg, "error")
        return render_template("register.html", name=name, email=email, phone=phone), 400

    set_role_session(user_id=user["user_id"], role=user["role"])
    session["user"] = user.get("email", "")

    redirect_to = _role_redirect(user.get("role"))
    if wants_json(request):
        return jsonify({"success": True, "redirect": redirect_to, "user": user})
    flash("Account created. You are now signed in.", "success")
    return redirect(redirect_to)
