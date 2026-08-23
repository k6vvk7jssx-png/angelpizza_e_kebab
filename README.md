# Angel Pizza & Kebab - Omni-Channel Food Delivery Platform

[![Next.js](https://img.shields.io/badge/Next.js-15-black.svg)](https://nextjs.org/)
[![Flutter](https://img.shields.io/badge/Flutter-Web%2FApp-02569B.svg)](https://flutter.dev/)
[![Supabase](https://img.shields.io/badge/Supabase-Realtime-3ECF8E.svg)](https://supabase.com/)
[![Telegram Bot API](https://img.shields.io/badge/Telegram-Bot%20API-2CA5E0.svg)](https://core.telegram.org/bots/api)

An end-to-end food delivery and restaurant management ecosystem integrating a customer-facing web catalog, real-time Telegram courier dispatching, and a Flutter back-office app.

---

## 🏗️ Architecture Overview

```
                      ┌───────────────────────────┐
                      │    Customer Web App       │
                      │  (Next.js App Router)     │
                      └─────────────┬─────────────┘
                                    │ Places Order
                                    ▼
                      ┌───────────────────────────┐
                      │   Supabase Realtime DB    │
                      └──────┬─────────────┬──────┘
                             │             │
              Order Event    │             │ Sync State
                             ▼             ▼
       ┌───────────────────────────┐ ┌───────────────────────────┐
       │   Telegram Dispatch Bot   │ │   Kitchen Manager App     │
       │ (Instant Rider Webhooks)  │ │   (Flutter / CanvasKit)   │
       └───────────────────────────┘ └───────────────────────────┘
```

---

## ✨ Key Features

* **Customer Web App (`client-web`):** Responsive digital menu, interactive cart, checkout, and address geolocation.
* **Telegram Rider Dispatching (`telegram-notify` / `telegram-riders`):** Instant notifications sent to rider channels with interactive accept/complete order buttons.
* **Manager & Kitchen Dashboard (`manager_web` / `manager_app`):** Flutter-based order queue with audio chime notifications (`test_bell.wav`).
* **Sales Analytics Engine:** Python reporting scripts (`analytics_best_sellers.py`, `monthly_report.py`) for automated monthly revenue aggregation.

---

## 🛠️ Tech Stack

* **Web Frontend:** Next.js 15, React, TypeScript, Tailwind CSS, Jest.
* **Backoffice App:** Flutter (Web & Mobile CanvasKit).
* **Database & Auth:** Supabase PostgreSQL with Realtime subscriptions.
* **Messaging & Bot:** Telegram Bot API Webhooks.
* **Analytics:** Python 3.

---

## 🧪 Testing

```bash
cd client-web
npm test
```

---

## 📄 License
MIT License.
