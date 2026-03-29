# PSI Book Store – Three Web Sites, One Backend

Admin, seller, and user web sites now live under `sites/` and share the same Firebase project plus common routes/services/templates.

## Folder map
- `sites/admin_app.py` – Admin Flask entrypoint (templates: `templates/admin/**`).
- `sites/shop_app.py` – Seller/shop-owner Flask entrypoint (templates: `templates/shop/**`).
- `sites/user_site.py` – User/customer Flask entrypoint (templates: `templates/user/**`).
- `routes/` – Modular blueprints; register subsets per site (`auth` + one of `admin|shop|user`).
- `services/`, `models/`, `utils/` – Shared backend logic.
- `templates/` & `static/` – Shared assets with per-role subfolders under `templates/`.
- `firebase_key.json` – Service account for Firestore access (used by all three Flask sites).
- `user_app/` – Flutter mobile app (unchanged).
- `app.py` – Legacy all-in-one server kept for reference only.

## Firebase
Single project: `psi-book-store-e75a3`
- Auth: email/password (admin, seller, and user login).
- Firestore collections: `users`, `books`, `orders`, `cart`, `store_owners`, `stores`.
- Storage: book cover images, receipts.

## Run commands
```bash
# Admin
cd c:/Users/prash/Downloads/pr
python sites/admin_app.py    # http://localhost:5000

# Seller / shop owner
cd c:/Users/prash/Downloads/pr
python sites/shop_app.py     # http://localhost:5001

# User / customer web
cd c:/Users/prash/Downloads/pr
python sites/user_site.py    # http://localhost:5002
```

## Data flow
- Users place orders from web (`sites/user_site.py`) or Flutter app (`user_app/`); orders and carts write to Firestore.
- Admin dashboards read/manage the same collections (books, stores, orders, users).
- Sellers see only their store data via shop routes; payouts are calculated from the shared orders collection.

## Notes
- Set `APP_SECRET_KEY` env var in each process for stronger session secrets.
- If you no longer need legacy user/shop/delivery templates or routes in `app.py`, archive them; the three new entrypoints do not use them.
