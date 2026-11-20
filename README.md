# WhatsApp Timetable & Activity Reminder App

A flexible mobile reminder and timetable app built with **Flutter** (Android & iOS) and a lightweight **Node.js + Baileys** backend for **100% automated WhatsApp messaging** — with **no credit card required**.

---

## Features

- **Timetable & One-Time Schedules:** Create weekly recurring schedules (Mon–Sun, Weekdays, Weekends, Daily) or one-time dated activities.
- **Dynamic Alert Selection (per activity + global defaults):**
  - **Alarm** *(Offline)* — High-priority ringing alarm with full-screen Snooze (5m) & Dismiss screen.
  - **Push Notification** *(Offline)* — Standard local banner notification.
  - **Automated WhatsApp Message** *(Internet)* — Automatically sends a WhatsApp message at the scheduled time using either your pre-saved WhatsApp number or any specific contact number.
- **Built-in Web QR Dashboard:** Scan the QR code once in your browser (`http://localhost:3000`) to link WhatsApp, view synced schedules, and send instant test messages.
- **Timezone-Aware Scheduling:** Cloud-safe scheduling using IANA timezones (e.g., `Asia/Karachi`, `UTC`).

---

## Project Structure

```text
.
├── backend/         # Lightweight Node.js + Baileys WhatsApp dispatcher & scheduler
│   ├── src/
│   │   ├── index.js         # Express REST API + Web Dashboard
│   │   ├── whatsapp.js      # Baileys QR pairing, reconnect & message sender
│   │   ├── scheduler.js     # Timezone-aware one-time & weekly scheduler
│   │   ├── store.js         # Local JSON storage (auto-upgrades to MongoDB if MONGO_URI set)
│   │   ├── mongoAuth.js     # Optional MongoDB WhatsApp session persistence
│   │   └── dashboard.html   # Browser QR scanner, test sender & logs UI
│   ├── Dockerfile           # Free Hugging Face Spaces / Docker deploy
│   └── render.yaml          # Free Render.com deploy blueprint
│
└── mobile_app/      # Flutter Android & iOS Mobile App
    ├── lib/
    │   ├── main.dart
    │   ├── models/          # ReminderItem & AppSettings
    │   ├── services/        # Storage, Offline Notifications/Alarms, WhatsApp API
    │   ├── screens/         # Home/Timetable, Add/Edit Schedule, Settings, Alarm Ring
    │   └── widgets/         # Dynamic AlertOptionTile & ReminderCard
    ├── android/             # AndroidManifest with exact alarm & boot permissions
    └── ios/                 # iOS notification permissions
```

---

## 1. Run the WhatsApp Backend Locally

```bash
cd backend
cp .env.example .env
npm install
npm start
```

1. Open **`http://localhost:3000`** in your browser (or check the terminal).
2. On your phone, open **WhatsApp → Linked Devices → Link a Device** and scan the QR code.
3. Once status shows **Connected**, try the **"Send Test Message"** card on the page!

Run backend unit tests anytime:
```bash
cd backend
npm test
```

---

## 2. Run the Flutter Mobile App

1. Make sure the [Flutter SDK](https://docs.flutter.dev/get-started/install) is installed.
2. Generate standard platform build files (Gradle wrapper, launcher icons, iOS Runner project) without overwriting `lib/` or `AndroidManifest.xml`:
   ```bash
   cd mobile_app
   flutter create . --org com.example --project-name whatsapp_reminder_app
   flutter pub get
   ```
3. **Android Note (`flutter_local_notifications`):** In `mobile_app/android/app/build.gradle` (or `build.gradle.kts`), enable core library desugaring inside `compileOptions` and `dependencies`:
   ```gradle
   compileOptions {
       coreLibraryDesugaringEnabled true
       sourceCompatibility JavaVersion.VERSION_1_8
       targetCompatibility JavaVersion.VERSION_1_8
   }
   dependencies {
       coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'
   }
   ```
4. Launch the app on an Android emulator or physical phone:
   ```bash
   flutter run
   ```
5. Inside the app, open the **Settings** tab:
   - Enter your **Default WhatsApp Number** (with country code, e.g., `923001234567`).
   - Enter your **Backend Server URL**:
     - Android Emulator: `http://10.0.2.2:3000`
     - Physical phone on same Wi-Fi: `http://<YOUR_PC_LOCAL_IP>:3000`
     - Cloud deployment: `https://your-app.onrender.com`
   - Tap **Save Settings** and **Send Test WhatsApp**.

---

## 3. Free 24/7 Cloud Hosting (Zero Credit Card Required)

To keep automated WhatsApp reminders working even when your PC is turned off:

1. **Free Session Database (MongoDB Atlas — No Card):**
   - Create a free M0 cluster at [mongodb.com](https://www.mongodb.com/atlas), allow network access (`0.0.0.0/0`), and copy your `MONGO_URI`.
   - This keeps your WhatsApp QR login and schedules saved permanently across server restarts.
2. **Free Node.js Hosting (Render.com — No Card):**
   - Push `backend/` to a GitHub repo.
   - On [render.com](https://render.com), create a **Free Web Service** pointing to `backend/` (or import `render.yaml`).
   - Add environment variable `MONGO_URI` (and optional `API_SECRET`).
   - Open your Render URL in a browser and scan the QR code once.
3. **Keep-Alive Pinger (cron-job.org — No Card):**
   - Create a free cron job at [cron-job.org](https://cron-job.org) to GET `https://your-app.onrender.com/health` every **10 minutes** so the free server stays awake 24/7.

