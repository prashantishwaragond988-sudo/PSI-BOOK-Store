"""Book CRUD and listing helpers."""

from __future__ import annotations

import uuid
from typing import Dict, List, Optional

from services.firestore_ctx import get_db
from utils.http import to_float, to_int, utc_now_iso


def _books_ref():
    return get_db().collection("books")


def _doc_to_book(doc) -> Dict:
    row = doc.to_dict() or {}
    row.setdefault("book_id", doc.id)
    row["book_id"] = str(row.get("book_id") or doc.id)
    row["title"] = str(row.get("title") or "")
    row["author"] = str(row.get("author") or "")
    row["description"] = str(row.get("description") or "")
    row["price"] = to_float(row.get("price"), 0.0)
    row["stock"] = to_int(row.get("stock"), 0)
    row["image_url"] = str(row.get("image_url") or row.get("image") or "")
    row["store_id"] = str(row.get("store_id") or row.get("shop_id") or "")
    row["shop_id"] = row["store_id"]  # legacy alias
    row["category"] = str(row.get("category") or "")
    row["discount"] = to_float(row.get("discount"), 0.0)
    row["rating"] = to_float(row.get("rating"), 0.0)
    row["language"] = str(row.get("language") or "")
    row["publication_year"] = str(row.get("publication_year") or "")
    row["order_count"] = to_int(row.get("order_count"), 0)
    row.setdefault("created_at", utc_now_iso())
    return row


def list_books(search: str = "", shop_id: str = "", store_id: str = "") -> List[Dict]:
    search = str(search or "").strip().lower()
    store_id = str(store_id or shop_id or "").strip()

    books: List[Dict] = []
    for doc in _books_ref().stream():
        book = _doc_to_book(doc)
        if store_id and book.get("store_id") != store_id:
            continue
        if search:
            haystack = " ".join(
                [
                    str(book.get("title") or ""),
                    str(book.get("author") or ""),
                    str(book.get("description") or ""),
                ]
            ).lower()
            if search not in haystack:
                continue
        books.append(book)

    books.sort(key=lambda row: (row.get("title") or "").lower())
    return books


def get_book(book_id: str) -> Optional[Dict]:
    book_id = str(book_id or "").strip()
    if not book_id:
        return None
    snap = _books_ref().document(book_id).get()
    if not snap.exists:
        return None
    return _doc_to_book(snap)


def create_book(data: Dict, shop_id: str) -> Dict:
    title = str(data.get("title") or "").strip()
    author = str(data.get("author") or "").strip()
    description = str(data.get("description") or "").strip()
    image_url = str(data.get("image_url") or data.get("image") or "").strip()
    stock = to_int(data.get("stock"), 0)
    price = to_float(data.get("price"), 0.0)
    category = str(data.get("category") or "").strip()
    discount = to_float(data.get("discount"), 0.0)
    rating = to_float(data.get("rating"), 0.0)
    language = str(data.get("language") or "").strip()
    publication_year = str(data.get("publication_year") or "").strip()
    store_id = str(shop_id or data.get("store_id") or data.get("shop_id") or "").strip()

    if not title:
        raise ValueError("title is required")
    if price < 0:
        raise ValueError("price must be >= 0")
    if stock < 0:
        raise ValueError("stock must be >= 0")
    if not store_id:
        raise ValueError("store_id is required")

    book_id = str(data.get("book_id") or "").strip() or uuid.uuid4().hex
    payload = {
        "book_id": book_id,
        "title": title,
        "author": author,
        "description": description,
        "price": price,
        "stock": stock,
        "image_url": image_url,
        "image": image_url,
        "store_id": store_id,
        "shop_id": store_id,
        "category": category,
        "discount": discount,
        "rating": rating,
        "language": language,
        "publication_year": publication_year,
        "order_count": to_int(data.get("order_count"), 0),
        "created_at": utc_now_iso(),
    }
    _books_ref().document(book_id).set(payload, merge=True)
    return payload


def update_book(book_id: str, data: Dict) -> Dict:
    existing = get_book(book_id)
    if not existing:
        raise ValueError("book not found")

    updates = {}
    if "title" in data:
        updates["title"] = str(data.get("title") or "").strip()
    if "author" in data:
        updates["author"] = str(data.get("author") or "").strip()
    if "description" in data:
        updates["description"] = str(data.get("description") or "").strip()
    if "price" in data:
        price = to_float(data.get("price"), -1)
        if price < 0:
            raise ValueError("price must be >= 0")
        updates["price"] = price
    if "stock" in data:
        stock = to_int(data.get("stock"), -1)
        if stock < 0:
            raise ValueError("stock must be >= 0")
        updates["stock"] = stock
    if "image_url" in data or "image" in data:
        image_url = str(data.get("image_url") or data.get("image") or "").strip()
        updates["image_url"] = image_url
        updates["image"] = image_url
    for key in ["category", "language", "publication_year"]:
        if key in data:
            updates[key] = str(data.get(key) or "").strip()
    if "discount" in data:
        updates["discount"] = to_float(data.get("discount"), 0.0)
    if "rating" in data:
        updates["rating"] = to_float(data.get("rating"), 0.0)
    if "order_count" in data:
        updates["order_count"] = to_int(data.get("order_count"), 0)

    if updates:
        _books_ref().document(existing["book_id"]).set(updates, merge=True)

    refreshed = get_book(existing["book_id"])
    return refreshed or existing


def delete_book(book_id: str) -> None:
    book_id = str(book_id or "").strip()
    if not book_id:
        raise ValueError("book_id required")
    _books_ref().document(book_id).delete()


def adjust_stock(book_id: str, quantity_delta: int) -> None:
    book = get_book(book_id)
    if not book:
        raise ValueError(f"book not found: {book_id}")

    new_stock = to_int(book.get("stock"), 0) + to_int(quantity_delta)
    if new_stock < 0:
        raise ValueError(f"insufficient stock for book: {book_id}")

    _books_ref().document(book_id).set({"stock": new_stock}, merge=True)
