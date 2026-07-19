# 🦅 Angels Pizza & Kebab — Digital Ecosystem

> Piazza Mazzini 82/83, Livorno | Tel. 0586 99 65 24

Sito di ordinazione online, gestionale cucina in tempo reale e database cloud per **Angels Pizza & Kebab** — Livorno.

---

## 📦 Struttura del Progetto

```
Angels website/
├── client-web/          # Sito clienti (Next.js) — ordinazione online
├── manager_app/         # App gestionale cucina (Flutter Web + Android)
└── supabase/            # Migrazioni database (PostgreSQL + Realtime)
```

---

## 🌐 Sito Clienti (`client-web/`)

Applicazione web **Next.js 16** per l'ordinazione online.

### Funzionalità
- 🍕 Menu completo con categorie (Pizze Rosse/Bianche, Fast Food, Bibite, ecc.)
- 🛒 Carrello interattivo con aggiunta/rimozione prodotti
- 📍 Scelta tra Consegna a domicilio e Asporto
- 📡 Tracking ordine in **tempo reale** (Supabase Realtime)
- 📱 Design responsive (PC, tablet, telefono)

### Avvio in locale
```bash
cd client-web
npm install
npm run dev
# → http://localhost:3000
```

### Deploy
Il sito si aggiorna automaticamente su **Vercel** ad ogni `git push` sul ramo `main`.

---

## 📱 Gestionale Cucina (`manager_app/`)

Applicazione **Flutter** per la gestione degli ordini in cucina.

### Funzionalità
- 🔐 Login sicuro con email e password (solo admin autorizzati)
- 🔔 Notifiche in tempo reale per nuovi ordini
- ✅ Avanzamento stato ordine (Ricevuto → In preparazione → Pronto → Consegnato)
- 🌐 Accessibile da browser, telefono e tablet

### Avvio in locale (browser)
```bash
cd manager_app
flutter run -d chrome
```

### Build Android (APK per telefono)
```bash
cd manager_app
flutter build apk --release
# File: build/app/outputs/flutter-apk/app-release.apk
```

---

## 🗄️ Database (`supabase/`)

Database **PostgreSQL** cloud su Supabase con:
- Tabella `menu_items` — catalogo prodotti con categorie e prezzi
- Tabella `orders` — ordini con stato e dati cliente
- **Row-Level Security (RLS)** attiva — solo admin e proprietario ordine possono accedervi
- **Realtime** abilitato — aggiornamenti istantanei senza polling

### Applica migrazioni
```bash
npx supabase db push
```

---

## 🔧 Sviluppo

### Prerequisiti
- Node.js 18+
- Flutter SDK 3.x
- Supabase CLI (`npm install -g supabase`)

### Variabili d'ambiente
Crea il file `client-web/.env.local`:
```
NEXT_PUBLIC_SUPABASE_URL=<il tuo url supabase>
NEXT_PUBLIC_SUPABASE_ANON_KEY=<la tua anon key>
```

> ⚠️ **Non committare mai il file `.env.local` su GitHub.** È già incluso nel `.gitignore`.

---

## 🛣️ Roadmap Futura
- [ ] Integrazione pagamenti **Stripe**
- [ ] Login clienti con **Clerk**
- [ ] Storico ordini per cliente
- [ ] Pannello statistiche vendite
- [ ] App iOS (Manager)

---

## 📄 Licenza
Progetto privato — tutti i diritti riservati © Angels Livorno
