"""Invoice view-model and optional PDF renderer."""

from __future__ import annotations

from io import BytesIO
from typing import Dict, List

from services.book_service import get_book
from services.order_service import get_order
from services.store_service import get_store
from services.user_role_service import get_user_by_id
from utils.http import to_float


def invoice_data(order_id: str) -> Dict:
    order = get_order(order_id)
    if not order:
        raise ValueError("order not found")

    store = get_store(order.get("store_id") or order.get("shop_id") or "") or {}
    owner = get_user_by_id(store.get("owner_id") or "") or {}
    customer = get_user_by_id(order.get("user_id") or "") or {}

    items: List[Dict] = []
    for raw in order.get("items") or []:
        if not isinstance(raw, dict):
            continue

        book_id = str(raw.get("book_id") or raw.get("book") or "")
        qty = int(raw.get("quantity") or raw.get("qty") or 0)
        title = str(raw.get("title") or "")
        unit_price = to_float(raw.get("unit_price"), -1)

        if not title or unit_price < 0:
            book = get_book(book_id)
            if book:
                if not title:
                    title = str(book.get("title") or book_id)
                if unit_price < 0:
                    unit_price = to_float(book.get("price"), 0.0)

        if unit_price < 0:
            unit_price = 0.0

        line_total = round(unit_price * qty, 2)
        items.append(
            {
                "book_id": book_id,
                "title": title or book_id,
                "price": unit_price,
                "quantity": qty,
                "line_total": line_total,
            }
        )

    delivery_charge = to_float(order.get("delivery_charge"), 0.0)
    total_amount = to_float(order.get("total_price"), 0.0)
    grand_total = round(total_amount + delivery_charge, 2)

    return {
        "order_id": order.get("order_id"),
        "order_date": order.get("created_at"),
        "store_name": store.get("name") or order.get("store_id") or "-",
        "shop_owner_name": owner.get("name") or "-",
        "customer_name": customer.get("name") or order.get("user_id") or "-",
        "items": items,
        "total_amount": round(total_amount, 2),
        "admin_commission": round(to_float(order.get("admin_commission"), 0.0), 2),
        "shop_owner_amount": round(to_float(order.get("shop_owner_amount"), 0.0), 2),
        "delivery_charge": round(delivery_charge, 2),
        "grand_total": grand_total,
    }


def invoice_pdf_bytes(data: Dict) -> bytes:
    """Generate a lightweight invoice PDF (requires reportlab)."""
    try:
        from reportlab.lib.pagesizes import A4
        from reportlab.lib.units import mm
        from reportlab.pdfgen import canvas
    except Exception as exc:
        raise RuntimeError("reportlab is required for PDF download") from exc

    buf = BytesIO()
    pdf = canvas.Canvas(buf, pagesize=A4)
    width, height = A4

    y = height - 20 * mm
    pdf.setFont("Helvetica-Bold", 14)
    pdf.drawString(20 * mm, y, "Invoice")
    y -= 8 * mm

    pdf.setFont("Helvetica", 10)
    lines = [
        f"Order ID: {data.get('order_id', '-')}",
        f"Order Date: {data.get('order_date', '-')}",
        f"Store Name: {data.get('store_name', '-')}",
        f"Shop Owner: {data.get('shop_owner_name', '-')}",
        f"Customer: {data.get('customer_name', '-')}",
    ]
    for line in lines:
        pdf.drawString(20 * mm, y, line)
        y -= 6 * mm

    y -= 2 * mm
    pdf.setFont("Helvetica-Bold", 10)
    pdf.drawString(20 * mm, y, "Book")
    pdf.drawString(110 * mm, y, "Qty")
    pdf.drawString(130 * mm, y, "Price")
    pdf.drawString(160 * mm, y, "Total")
    y -= 5 * mm
    pdf.line(20 * mm, y, 190 * mm, y)
    y -= 5 * mm

    pdf.setFont("Helvetica", 9)
    for item in data.get("items") or []:
        if y < 35 * mm:
            pdf.showPage()
            y = height - 20 * mm
            pdf.setFont("Helvetica", 9)
        pdf.drawString(20 * mm, y, str(item.get("title") or "-")[:50])
        pdf.drawRightString(123 * mm, y, str(item.get("quantity") or 0))
        pdf.drawRightString(152 * mm, y, f"{float(item.get('price') or 0):.2f}")
        pdf.drawRightString(188 * mm, y, f"{float(item.get('line_total') or 0):.2f}")
        y -= 5 * mm

    y -= 2 * mm
    pdf.line(20 * mm, y, 190 * mm, y)
    y -= 7 * mm

    summary = [
        ("Total Amount", data.get("total_amount", 0)),
        ("Admin Commission", data.get("admin_commission", 0)),
        ("Shop Owner Amount", data.get("shop_owner_amount", 0)),
        ("Delivery Charge", data.get("delivery_charge", 0)),
        ("Grand Total", data.get("grand_total", 0)),
    ]

    pdf.setFont("Helvetica", 10)
    for label, value in summary:
        pdf.drawString(120 * mm, y, f"{label}:")
        pdf.drawRightString(188 * mm, y, f"{float(value or 0):.2f}")
        y -= 6 * mm

    pdf.showPage()
    pdf.save()
    return buf.getvalue()
