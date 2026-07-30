# ANGELS LIVORNO - SYSTEM RULES & CRITICAL REQUIREMENTS

## ⚠️ MANDATORY ARCHITECTURAL RULES (DO NOT REMOVE OR SIMPLIFY)

### 1. FULL CART & CHECKOUT FLOW
Under NO CIRCUMSTANCES should the cart or checkout system be simplified or removed from any client page (`page.tsx`, `/menu/page.tsx`, etc.).
The checkout flow MUST ALWAYS include ALL of the following features:
- **Order Mode Tabs**: Guest Order / OTP Login (`checkoutMode`).
- **Delivery Type Tabs**: Domicilio (Delivery) / Asporto (Pickup) (`deliveryType`).
- **Required Customer Fields**: Full Name, Phone Number, Delivery Address (when delivery is selected).
- **Delivery Time Selection (`selectedTime`)**: 15-minute slot selector generated dynamically via `getTimeSlots()`.
- **Payment Method Selection (`paymentMethod`)**: Cash on Delivery (`cod`) & Card placeholders.
- **Telegram Notification Trigger**: Every successful order MUST invoke `/api/telegram-notify` to send an instant alert to Telegram with order details and an inline claim button.
- **Real-Time Order Tracking**: Postgres change listener on Supabase `orders` table displaying real-time status (`pending`, `accepted`, `delivering`, `completed`).

### 2. MOBILE UX & DESIGN SYSTEM
- **Modern Glovo / Deliveroo Style Layout**: Soft white cards (`16px` border-radius), `box-shadow: 0 4px 20px rgba(0,0,0,0.05)`, hairline borders `1px solid rgba(0,0,0,0.06)`. NO heavy 3px black lines or harsh retro borders!
- **Category Tabs Sticky Bar**: Sticky positioning below header with category icons (🍕, 🧀, 🥖, 🍔, 🍟, 🥤, 🍹) and pill styling.
- **Quantity Steppers**: Dish cards MUST feature quantity steppers (`− 1 +`) when an item is already added to the cart.
- **Floating Cart Pill on Mobile**: Fixed bottom pill (`999px` radius) with item count badge, total price, and arrow opening the bottom sheet drawer.

### 3. NAVIGATION & LINKS
- **Separate Routes**: Main navigation items (`Il Menu`, `Notizie & Novità`, `Contatti`) MUST point to dedicated Next.js page routes (`/menu`, `/notizie`, `/contatti`).
- **External Links**: Phone numbers, Google Maps location, and Google Reviews MUST open in a new browser tab using `target="_blank" rel="noopener noreferrer"`.
- **Google Reviews Integration**: The hero banner card and footer MUST include direct buttons to *"⭐ Valuta il Locale su Google"* opening the Google Maps review URL in a new tab.

### 4. MANAGER APP & TELEGRAM LOGISTICS
- **Daily Shift Reset**: Kitchen dashboard in the Flutter manager app resets every day at 12:00 PM (noon).
- **Telegram Claim Button**: Telegram order messages contain inline callback buttons `[ 🛵 PRENDI IN CARICO ]` handled by `/api/telegram-webhook` to lock the order for the first claiming driver.
