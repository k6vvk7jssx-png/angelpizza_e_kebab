#!/usr/bin/env python3
"""
Angels Pizzeria & Kebab - Monthly Best Seller & Sales Telegram Reporter
-----------------------------------------------------------------------
This script runs monthly (or on demand) to calculate:
- The #1 Most-Selling Product of the month (Best Seller)
- Top 5 products ranking by quantity and revenue
- Total monthly revenue & order count (Domicilio vs Asporto)
- Automatically sends a clean formatted report to the Manager via Telegram!
"""

import json
import os
import sys
import urllib.request
from collections import defaultdict
from datetime import datetime, timedelta

# Enforce UTF-8 output on Windows terminals
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

def load_env_vars():
    """Dynamically load environment variables from .env or client-web/.env.local if present."""
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    env_paths = [
        os.path.join(base_dir, "client-web", ".env.local"),
        os.path.join(base_dir, ".env.local"),
        os.path.join(base_dir, ".env"),
    ]
    for env_path in env_paths:
        if os.path.exists(env_path):
            try:
                with open(env_path, "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith("#") and "=" in line:
                            k, v = line.split("=", 1)
                            os.environ.setdefault(k.strip(), v.strip().strip("'\""))
            except Exception:
                pass

load_env_vars()

# Credentials (read strictly from environment variables)
SUPABASE_URL = os.environ.get("NEXT_PUBLIC_SUPABASE_URL", "")
SUPABASE_KEY = os.environ.get("NEXT_PUBLIC_SUPABASE_ANON_KEY", "")
TELEGRAM_BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "")
TELEGRAM_CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID", "")

def get_monthly_report():
    """Query orders for the current month from Supabase."""
    now = datetime.now()
    first_of_month = datetime(now.year, now.month, 1).isoformat() + "Z"
    
    endpoint = f"{SUPABASE_URL.rstrip('/')}/rest/v1/orders?select=*&created_at=gte.{first_of_month}"
    req = urllib.request.Request(
        endpoint,
        headers={
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "Content-Type": "application/json",
        }
    )
    
    try:
        with urllib.request.urlopen(req) as resp:
            data = resp.read().decode('utf-8')
            return json.loads(data)
    except Exception as err:
        print(f"❌ Error querying Supabase: {err}")
        return []

def send_telegram_alert(text):
    """Send formatted Telegram message to the Manager."""
    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    payload = json.dumps({
        "chat_id": TELEGRAM_CHAT_ID,
        "text": text,
        "parse_mode": "Markdown"
    }).encode('utf-8')
    
    req = urllib.request.Request(
        url,
        data=payload,
        headers={"Content-Type": "application/json"}
    )
    try:
        with urllib.request.urlopen(req) as resp:
            print("✅ Monthly report sent successfully to Manager Telegram!")
    except Exception as err:
        print(f"⚠️ Error sending Telegram notification: {err}")

def process_monthly_stats():
    """Process monthly order data and output report."""
    orders = get_monthly_report()
    now = datetime.now()
    month_name = now.strftime("%B %Y")

    if not orders:
        print(f"ℹ️ No orders found for {month_name}.")
        msg = f"📊 *RAPPORTO MENSILE VENDITE - {month_name.upper()}*\n\nNessun ordine registrato in questo mese al momento."
        send_telegram_alert(msg)
        return

    product_qty = defaultdict(int)
    product_revenue = defaultdict(float)
    pickup_count = 0
    delivery_count = 0
    total_revenue = 0.0

    for order in orders:
        amount = float(order.get("total_amount", 0.0) or 0.0)
        total_revenue += amount

        addr = (order.get("delivery_address") or "").lower()
        if "asporto" in addr or "ritiro" in addr or "cassa" in addr:
            pickup_count += 1
        else:
            delivery_count += 1

        items = order.get("items") or []
        if isinstance(items, str):
            try:
                items = json.loads(items)
            except Exception:
                items = []

        for item in items:
            name = item.get("name", "Prodotto Sconosciuto")
            qty = int(item.get("qty", 1))
            price = float(item.get("price_at_order", 0.0) or 0.0)

            product_qty[name] += qty
            product_revenue[name] += qty * price

    sorted_products = sorted(product_qty.items(), key=lambda x: x[1], reverse=True)
    top_product = sorted_products[0] if sorted_products else None

    # CLI Output
    print("=" * 65)
    print(f" 🏆 RAPPORTO MENSILE BEST-SELLER - {month_name.upper()} 🏆")
    print("=" * 65)
    print(f"📦 Totale Ordini Mese : {len(orders)} ({delivery_count} Domicilio / {pickup_count} Asporto)")
    print(f"💰 Incasso Totale     : €{total_revenue:.2f}")

    if top_product:
        pname, pqty = top_product
        prev = product_revenue[pname]
        print(f"\n🔥 PRODOTTO PIÙ VENDUTO DEL MESE: **{pname}** ({pqty} unità - €{prev:.2f})")
    
    print("\n🔝 TOP 5 PRODOTTI DEL MESE:")
    for idx, (pname, pqty) in enumerate(sorted_products[:5], 1):
        prev = product_revenue[pname]
        print(f"  {idx}. {pname}: {pqty} venduti (€{prev:.2f})")

    # Build Telegram Message
    top_text = f"🏆 *PRODOTTO PIÙ VENDUTO DEL MESE:*\n🔥 *{top_product[0]}* ({top_product[1]} unità vendute - €{product_revenue[top_product[0]]:.2f})" if top_product else ""
    
    top5_str = "\n".join([f"{i+1}. *{p}*: {q} venduti (€{product_revenue[p]:.2f})" for i, (p, q) in enumerate(sorted_products[:5])])

    telegram_msg = (
        f"📊 *RAPPORTO MENSILE VENDITE - ANGELS LIVORNO*\n"
        f"📅 *Mese:* {month_name.upper()}\n\n"
        f"{top_text}\n\n"
        f"💰 *Incasso Totale Mese:* €{total_revenue:.2f}\n"
        f"📦 *Totale Ordini:* {len(orders)} ({delivery_count} Domicilio / {pickup_count} Asporto)\n\n"
        f"🔝 *TOP 5 PIATTI DEL MESE:*\n{top5_str}\n\n"
        f"📍 *Angels Pizzeria & Kebab Livorno*"
    )

    send_telegram_alert(telegram_msg)

if __name__ == "__main__":
    process_monthly_stats()
