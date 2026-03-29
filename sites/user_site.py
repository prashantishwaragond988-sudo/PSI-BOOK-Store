"""Customer-facing Flask entrypoint (web user website) sharing the common backend."""

from __future__ import annotations

import os
import sys

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from flask import Flask, redirect

import firebase_admin
from firebase_admin import credentials, firestore
import pyrebase

from models.constants import ROLE_CUSTOMER
from routes import register_routes

# Shared Firebase project (same as admin and seller sites).
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

cred = credentials.Certificate(os.path.join(BASE_DIR, "firebase_key.json"))
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()

app = Flask(
    __name__,
    template_folder=os.path.join(BASE_DIR, "templates"),
    static_folder=os.path.join(BASE_DIR, "static"),
)
app.secret_key = os.getenv("APP_SECRET_KEY", "secret123")
app.config["UPLOAD_FOLDER"] = os.path.join(BASE_DIR, "static")
app.config["FIRESTORE_DB"] = db
app.config["FIREBASE_AUTH_CLIENT"] = auth_client
app.config["ALLOWED_ROLES"] = {ROLE_CUSTOMER}

register_routes(app, include=("auth", "user"))


@app.route("/")
def root():
    return redirect("/user/login")


@app.after_request
def add_cors_headers(response):
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type,Authorization"
    response.headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS"
    return response


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5002)
