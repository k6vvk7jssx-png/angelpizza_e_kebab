# ANGELS LIVORNO - PROJECT SPECIFICATION & ARCHITECTURE DOCUMENT

## 📜 Overview
Angels Livorno is a full-stack digital ecosystem for a restaurant/pizzeria & kebab shop in Livorno.
It consists of two main web applications:
1. **Client Website (`client-web`)**: Next.js 16 app hosted on Vercel for customer orders, real-time tracking, news, and Google reviews.
2. **Manager App (`manager_app` / `manager_web`)**: Flutter Web app hosted on Vercel for kitchen order management, historical shifts, and revenue charts.

---

## 🛒 Client Website Requirements & Checkout Contract

### Core Features (PERMANENT & IMMUTABLE)
1. **Full Cart & Checkout System**:
   - **Order Mode**: Guest Order / OTP Phone Authentication.
   - **Reception Mode**: Domicilio (Delivery) or Asporto (Pickup).
   - **Time Slot Selector**: Dropdown menu allowing customers to choose their preferred delivery/pickup time slot at 15-minute intervals starting from 30 minutes in the future up to closing time (23:45).
   - **Payment Method**: Cash on Delivery (`cod`) & Card placeholders.
   - **Real-Time Order Tracking**: Real-time Supabase subscription updating order status (`pending` ➔ `accepted` ➔ `delivering` ➔ `completed`).

2. **Telegram Instant Logistics**:
   - Every placed order triggers an HTTP POST request to `/api/telegram-notify`.
   - Sends a formatted Markdown message to the restaurant's Telegram Chat/Group.
   - Includes an inline keyboard button `[ 🛵 PRENDI IN CARICO (PRENOTA CONSEGNA) ]`.
   - Incoming button taps are handled by `/api/telegram-webhook` which updates Supabase status to `delivering`, notifies the driver with a popup toast, and locks the Telegram message to show `🔒 PRENOTATO DA [NOME FATTORINO]`.

3. **Page Navigation & External Links**:
   - Dedicated page routes: `/` (Home), `/menu` (Menu Catalog), `/notizie` (News & Promos), `/contatti` (Location & Contacts).
   - External links (phone numbers `tel:`, Google Maps, Google Reviews) MUST use `target="_blank" rel="noopener noreferrer"`.
   - Hero banner and Footer feature direct *"⭐ Valuta il Locale su Google"* links.

4. **Mobile UX**:
   - Glovo/Deliveroo inspired design: `#FFFFFF` cards, `16px` border-radius, soft elevation shadows `box-shadow: 0 4px 20px rgba(0,0,0,0.05)`.
   - Sticky category tabs with icons (🍕, 🧀, 🥖, 🍔, 🍟, 🥤, 🍹).
   - Card quantity stepper pill (`− 1 +`) when an item is in the cart.
   - Floating bottom cart pill (`999px` radius) opening a bottom sheet drawer.

---

## 🍳 Manager App Requirements

1. **Daily Shift Reset**:
   - Kitchen orders automatically reset for the active day.
   - Business shift cycle runs from 12:00 PM (noon) to 12:00 PM the following day.
2. **Historical Shifts Journal (Rubrica Giornate)**:
   - Groups all historical orders by business day.
   - Displays total order count and total revenue per day.
   - Clicking a day displays the full order history and dish details.
3. **Revenue Analytics Chart (Bilancio & Andamento)**:
   - Performance metrics: Total Revenue, Completed Orders Count, Average Order Value, Best Shift Record.
   - Interactive line chart built with `fl_chart` plotting revenue over the last 7 business days.

---

## 🔒 Security & Database
- Supabase RLS (Row Level Security) enabled on `public.orders` and `public.menu_items`.
- Realtime Postgres Change Listeners enabled on `public.orders`.
