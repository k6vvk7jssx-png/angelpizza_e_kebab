# Angels Livorno Manager App - Flutter Implementation Plan

This plan outlines the steps to build the restaurant manager app using Flutter. The app will target Windows Desktop and Android Tablet platforms, supporting realtime order ingestion from Supabase, audible alarm looping, and operating system notifications.

---

### Task 1: Initialize Flutter Project & Assets

**Files:**
- Create: `manager_app/pubspec.yaml`
- Create: `manager_app/assets/sounds/alert.mp3`
- Create: `manager_app/lib/main.dart`

- [ ] **Step 1: Initialize Flutter Project**
  Run: `& "C:\Users\Utente\flutter_sdk\flutter\bin\flutter.bat" create --org com.angels.livorno --platforms=windows,android manager_app` in `c:\Users\Utente\Desktop\Angels website`
  Expected: Flutter project scaffolded under `manager_app`.

- [ ] **Step 2: Configure pubspec.yaml Dependencies**
  Add dependencies to `manager_app/pubspec.yaml`:
  - `supabase_flutter: ^2.8.0`
  - `audioplayers: ^6.0.0`
  - `local_notifier: ^0.1.7`
  - `window_manager: ^0.4.3`
  - Add assets path `assets/sounds/`
  Expected: dependencies configured.

- [ ] **Step 3: Download dependencies**
  Run: `& "C:\Users\Utente\flutter_sdk\flutter\bin\flutter.bat" pub get` in `manager_app`
  Expected: Packages downloaded successfully.

- [ ] **Step 4: Create alert sound placeholder**
  Create an empty placeholder file at `manager_app/assets/sounds/alert.mp3` (we will replace this with a real audio file or sound clip).

---

### Task 2: Supabase Realtime Order Service (TDD)

**Files:**
- Create: `manager_app/lib/models/order_model.dart`
- Create: `manager_app/lib/services/order_service.dart`
- Create: `manager_app/test/order_service_test.dart`

- [ ] **Step 1: Write Order Model**
  Implement the order data class in `manager_app/lib/models/order_model.dart` matching the Postgres `orders` schema:
  `id`, `guest_name`, `guest_phone`, `guest_address`, `delivery_type`, `status`, `requested_time`, `total_price`, `notes`, `created_at`.

- [ ] **Step 2: Write Order Service Interface & Mock Test**
  Write integration tests in `manager_app/test/order_service_test.dart` to verify that order parsed data yields correct properties and mock data inserts trigger callbacks.

- [ ] **Step 3: Implement Realtime Order Service**
  Implement `manager_app/lib/services/order_service.dart` using `SupabaseClient` streams/channels to listen to Postgres changes on the `orders` table.

---

### Task 3: Alarm & Notification Manager

**Files:**
- Create: `manager_app/lib/services/notification_manager.dart`
- Create: `manager_app/test/notification_manager_test.dart`

- [ ] **Step 1: Implement Local Notifications**
  Configure `local_notifier` inside `NotificationManager` to register a customized notifier and trigger OS-level notification popups when a new order arrives.

- [ ] **Step 2: Implement Loop Alert Sound**
  Configure `audioplayers` to play `assets/sounds/alert.mp3` in a loop when a new order arrives, and expose a stop function when the order is opened/accepted.

- [ ] **Step 3: Implement Window Focus**
  Configure `window_manager` to bring the window to the foreground when an order arrives to catch the cashier's attention.

---

### Task 4: Kitchen Dashboard UI

**Files:**
- Create: `manager_app/lib/screens/dashboard_screen.dart`
- Create: `manager_app/lib/components/order_card.dart`

- [ ] **Step 1: Build Order Card Component**
  Create `OrderCard` exhibiting the status color badge (red for pending, yellow for accepted, green for delivering) and order details.

- [ ] **Step 2: Build Order Detail Pane & Status Actions**
  Create a detailed side panel where the restaurateur can change order states by calling Supabase updates:
  - Cliccando su "Accetta" -> updates to `accepted`
  - Cliccando su "In Consegna" -> updates to `delivering`
  - Cliccando su "Completato" -> updates to `completed`

- [ ] **Step 3: Run Flutter Web / Desktop app to verify visually**
  Build and verify compile works cleanly.
