# Firebase sync — setup & verification

This firmware now mirrors its status into Firebase Realtime Database (in
addition to, not instead of, the existing local `/status` and `/control`
HTTP endpoints), so the website and phone app stay in sync from anywhere,
not just this Wi-Fi network. See the website repo's `README.md` for the
full architecture.

## Before flashing

1. **Install the library**: Arduino IDE → Tools → Manage Libraries → search
   **"Firebase Arduino Client Library for ESP8266 and ESP32"** by **mobizt**
   → Install. If the code below doesn't compile against whatever version
   Library Manager installs, this is the first thing to check — mobizt's
   library had a major API rewrite (v4+) that uses a different, fully-async
   API than the classic `FirebaseData`/`Firebase.RTDB.setJSON(...)` calls
   used here. If you land on v4+, either pin to a 4.4.x release in Library
   Manager, or ask me to port these calls to the new API — I wrote this
   against the classic API from documentation/memory and could not compile
   it myself (no ESP32 toolchain in this environment), so treat it as a
   first draft to verify, not guaranteed-correct code.

2. **Anonymous Auth + Rules** must already be set up in the Firebase
   console (Authentication → Sign-in method → Anonymous; Realtime Database
   → Rules) — same project as the website and app. If those aren't done,
   `Firebase.signUp(...)` in `initFirebase()` will fail and
   `firebaseReady` stays `false` (the device keeps working locally over
   HTTP, it just won't sync through Firebase).

## After flashing — what to check on Serial Monitor (115200 baud)

- `Firebase anonymous sign-in failed: ...` → Anonymous sign-in isn't
  enabled, or the API key/database URL is wrong.
- `Firebase beginStream failed: ...` / `Firebase stream error: ...` →
  usually a Rules problem (check `.read`/`.write` on `/devices`) or a
  transient network hiccup — the stream should recover on its own via
  `firebaseStreamTimeoutCallback`.
- No errors, and toggling something from the website or app shows up on
  this device (LCD/serial) within ~1-2s → it's working end to end.

## Data shape

```
/devices/esp32-01/state/reported   ← this firmware writes every ~2s and after every change
/devices/esp32-01/state/desired    ← website/app write control commands here; this firmware applies them
```

`esp32-01` is `FIREBASE_DEVICE_ID` near the top of the `.ino` — must match
`VITE_FIREBASE_DEVICE_ID` in the website's `.env` and `kFirebaseDeviceId` in
the Flutter app's `lib/app_constants.dart`.
