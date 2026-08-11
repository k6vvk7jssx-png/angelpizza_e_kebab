#!/usr/bin/env python3
"""
Angels Pizzeria & Kebab - Sales Analytics & Best-Sellers Identifier
------------------------------------------------------------------
This script fetches orders from Supabase REST API and analyzes:
1. Top-selling products by quantity sold.
2. Top products by total revenue generated.
3. Breakdown between Asporto (Pickup) vs Domicilio (Delivery) orders.
4. Summary statistics (Total Orders, Total Revenue, Average Order Value).
"""

import json
import os
import sys
import urllib.request
from collections import defaultdict
from datetime import datetime

# Enforce UTF-8 output on Windows terminals
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

# Supabase Credentials (from .env.local)
SUPABASE_URL = os.environ.get("NEXT_PUBLIC_SUPABASE_URL", "https://cavxvkwixbxbdvaasxpa.supabase.co")
SUPABASE_KEY = os.environ.get(
    "NEXT_PUBLIC_SUPABASE_ANON_KEY",
    "sb_publishable_Sz5cqHM7sIpKGxOcgCWkTQ_8deGQEGt"
)

def fetch_orders():
    """Fetch all orders from Supabase REST API."""
    endpoint = f"{SUPABASE_URL.rstrip('/')}/rest/v1/orders?select=*"
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
        print(f"❌ Error fetching orders from Supabase: {err}")
        return []

def analyze_sales(orders):
    """Analyze sales data to identify best sellers and revenue statistics."""
    if not orders:
        print("\nℹ️ No order data found in Supabase.")
        return

    product_qty = defaultdict(int)
    product_revenue = defaultdict(float)
    order_type_count = defaultdict(int)
    total_revenue = 0.0
    total_orders = len(orders)

    for order in orders:
        amount = float(order.get("total_amount", 0.0) or 0.0)
        total_revenue += amount

        # Determine order type (Asporto vs Domicilio)
        address = (order.get("delivery_address") or "").lower()
        if "asporto" in address or "ritiro" in address or "cassa" in address:
            order_type_count["🛍️ Asporto (Pickup)"] += 1
        else:
            order_type_count["🛵 Domicilio (Delivery)"] += 1

        # Process item list
        items = order.get("items") or []
        if isinstance(items, str):
            try:
                items = json.loads(items)
            except Exception:
                items = []

        for item in items:
            name = item.get("name", "Prodotto sconosciuto")
            qty = int(item.get("qty", 1))
            price = float(item.get("price_at_order", 0.0) or 0.0)

            product_qty[name] += qty
            product_revenue[name] += qty * price

    avg_order_value = total_revenue / total_orders if total_orders > 0 else 0.0

    print("=" * 65)
    print(" 🍕 ANGELS PIZZERIA & KEBAB - SALES & BEST-SELLERS REPORT 🍕")
    print("=" * 65)
    print(f"📊 Totale Ordini Registrati : {total_orders}")
    print(f"💰 Incasso Totale           : €{total_revenue:.2f}")
    print(f"🏷️ Valore Medio Ordine      : €{avg_order_value:.2f}")
    print("-" * 65)

    print("\n📦 Ripartizione Modalità d'Ordine:")
    for otype, count in order_type_count.items():
        pct = (count / total_orders * 100) if total_orders > 0 else 0
        print(f"   • {otype:25s}: {count:3d} ordini ({pct:.1f}%)")

    # Sort products by quantity sold
    sorted_by_qty = sorted(product_qty.items(), key=lambda x: x[1], reverse=True)

    print("\n🏆 CLASSIFICA PRODOTTI PIÙ VENDUTI (Per Quantità):")
    print("-" * 65)
    print(f"{'Pos.':<5} {'Prodotto':<32} {'Quantità Venduta':<18} {'Fatturato Totale':<12}")
    print("-" * 65)

    for rank, (name, qty) in enumerate(sorted_by_qty, 1):
        rev = product_revenue[name]
        star = "⭐" if rank <= 3 else "  "
        print(f"{star}{rank:<3} {name[:30]:<32} {qty:<18} €{rev:.2f}")

    print("-" * 65)
    if sorted_by_qty:
        print(f"🔥 Il prodotto BEST-SELLER assoluto è: **{sorted_by_qty[0][0]}** ({sorted_by_qty[0][1]} unità vendute)")
    print("=" * 65)

if __name__ == "__main__":
    print("📡 Collegamento a Supabase ed estrazione ordini in corso...")
    orders_data = fetch_orders()
    analyze_sales(orders_data)
