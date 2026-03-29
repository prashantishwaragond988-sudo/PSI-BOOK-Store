"""Shared accessors for Firestore and Firebase auth clients."""

from __future__ import annotations

from firebase_admin import firestore
from flask import current_app


def get_db():
    db = current_app.config.get("FIRESTORE_DB")
    if db is None:
        db = firestore.client()
        current_app.config["FIRESTORE_DB"] = db
    return db


def get_auth_client():
    return current_app.config.get("FIREBASE_AUTH_CLIENT")
