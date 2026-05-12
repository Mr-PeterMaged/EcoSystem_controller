# EcoSystem Controller

**EcoSystem Controller** is a Flutter mobile application for monitoring and controlling a smart home IoT setup powered by ESP32 devices. The app provides a modern interface for checking sensor data, managing device states, receiving safety alerts, and switching between display themes.

Visit the project website: [smart-home-self-powered.vercel.app](https://smart-home-self-powered.vercel.app/)

---

## Latest Updates — v1.0.0

### New Features
- **Auto-login on reopen** — The app remembers the last logged-in user via a saved session. On relaunch, it skips the login screen and navigates directly to the dashboard. The session is cleared only on explicit logout or account switch.
- **User Profile page** — Each user can now tap their avatar in the drawer to open a dedicated profile screen with:
  - Circular profile photo (tap to pick from device gallery)
  - Edit full name
  - Change password (with current-password verification)
- **Theme-aware accent color** — All UI elements, including the About screen, now respond correctly to the user-selected accent color. The hardcoded green has been replaced throughout.
- **Dynamic logo on splash and About screens** — The splash/loading screen now uses `Logo/dark_mode.png` on a pure black background. The About screen switches between `Logo/dark_mode.png` and `Logo/light_mode.png` based on the active theme.
- **Team update** — Recardo Raafat (Assistant Leader) has been added to the project team in the About screen.
- **Website link** — The About screen now includes a button linking to the project website.
- **Door button** — A new Door button in the Full Control screen opens or locks the door remotely. The button reflects the real-time door state (`Open` / `Locked`) fetched from the ESP32. Tapping it sends a `door` command to the ESP32, which moves the servo and switches the green/red LEDs.
- **PIR motion detection** — The ESP32 now reads the HC-SR501 PIR sensor and reports `pirDetected: true/false` in every status response. Motion state is shown live in the Stats screen and triggers an in-app alert notification.

### Dependencies Added
| Package | Purpose |
|---|---|
| `image_picker ^1.1.2` | Profile photo selection from device gallery |
| `url_launcher ^6.3.0` | Opening the project website from the About screen |

---

## Features

- First-time sign-up flow for creating the initial admin account
- Session persistence — automatic login on relaunch, explicit logout only
- User Profile page with photo, name editing, and password change
- Admin dashboard for system overview and connection status
- Smart home system status monitoring
- Full control panel for connected components:
  - Main system, gas sensor, temperature sensor, PIR motion sensor
  - LEDs, buzzer, auto light mode
  - Door lock / unlock (moves servo via app or RFID card)
- System statistics: temperature, humidity, gas detection, motion, LED status
- Notifications and alerts for system updates, temperature, gas, and motion events
- In-app notification history with clear action
- Persistent settings saved locally on the device
- Theme switcher: system, light, and dark modes with custom accent colors
- Connection settings for saved ESP32/controller IP address
- Configurable sensor refresh interval and alert thresholds
- Modern UI with Material 3 and a green accent

---

## Screenshots

### Login
![Login Screen](mockup/output/login_page_phone_mockup.png)

### Dashboard
![Dashboard Screen](mockup/output/welcome_admin_phone_mockup.png)

### Control Panel
![Control Screen](mockup/output/full_control_phone_mockup.png)

### Statistics
![Statistics Screen](mockup/output/system_stats_phone_mockup.png)

### Notifications
![Notifications Screen](mockup/output/norifications_phone_mockup.png)

### Settings
![Settings Screen](mockup/output/display_phone_mockup.png)

---

## ESP32 Firmware

The app communicates with an ESP32 microcontroller running `sketch_may4a.ino`. The firmware supports two transport modes selected automatically at startup: **WiFi** (HTTP server on port 8080) when the network is reachable, or **Bluetooth Serial** as a fallback.

### Hardware Pin Map

| Pin | Label | Type | Purpose |
|-----|-------|------|---------|
| 4 | DHT_PIN | Digital | DHT11 temperature & humidity sensor |
| 14 | LDR_DO | Digital IN | LDR digital threshold output |
| 34 | LDR_AO | Analog IN | LDR analog level (input-only pin) |
| 26 | MQ2_DO | Digital IN | MQ-2 gas sensor digital threshold |
| 35 | MQ2_AO | Analog IN | MQ-2 gas sensor analog level (input-only pin) |
| 16 | BUZZER_PIN | Digital OUT | Piezo buzzer |
| 17 | LED1_PIN | Digital OUT | Gas alarm LED (red) |
| 25 | LED2_PIN | Digital OUT | LDR-controlled night light LED |
| 33 | BTN_PIN | Digital IN | Manual LED2 toggle button (pull-up) |
| 5 | RFID_SS | SPI CS | MFRC522 RFID reader chip-select |
| 27 | RFID_RST | Digital OUT | MFRC522 RFID reader reset |
| 32 | LED_GREEN | Digital OUT | Door unlocked indicator |
| 13 | LED_RED | Digital OUT | Door locked indicator |
| 15 | SERVO_PIN | PWM OUT | Servo motor (0° = locked, 90° = open) |
| 0 | MQ2_PWR | Digital OUT | MOSFET gate — MQ-2 power |
| 2 | LCD_PWR | Digital OUT | MOSFET gate — LCD power |
| 12 | PIR_PIN | Digital IN | HC-SR501 PIR motion sensor output |
| 21 | SDA | I²C | LCD via I²C (address 0x27) |
| 22 | SCL | I²C | LCD via I²C |
| 18/19/23 | SPI | SPI | MFRC522 RFID reader (CLK/MISO/MOSI) |

### HTTP API Reference

The ESP32 runs a web server on **port 8080** when connected to WiFi.

#### `GET /status`

Returns the current state of all devices and sensors as JSON.

**Response fields:**

| Field | Type | Description |
|-------|------|-------------|
| `system` | bool | Master system power |
| `gasSensor` | bool | Gas sensor enabled |
| `tempSensor` | bool | Temperature sensor enabled |
| `ledSensor` | bool | LED sensor enabled |
| `pirSensor` | bool | PIR sensor enabled |
| `ldrSensor` | bool | LDR sensor enabled |
| `buzzer` | bool | Buzzer enabled |
| `autoLight` | bool | Automatic night light enabled |
| `mq2Pwr` | bool | MQ-2 MOSFET power state |
| `lcdPwr` | bool | LCD MOSFET power state |
| `temperature` | float | Temperature reading in °C |
| `humidity` | float | Relative humidity reading in % |
| `gasDetected` | bool | `true` when gas level exceeds threshold |
| `gasPercent` | int | Gas level 0–100% |
| `led2` | bool | Night light LED state |
| `locked` | bool | `true` = door locked (servo at 0°) |
| `door` | bool | `true` = door open (servo at 90°) — inverse of `locked` |
| `pirDetected` | bool | `true` when PIR sensor detects motion |

#### `POST /control`

Send a JSON body with any subset of the fields below to change device state. Returns the updated `/status` JSON immediately.

**Accepted fields:**

| Field | Type | Effect |
|-------|------|--------|
| `system` | bool | Master on/off — turning off forces all other devices off |
| `gasSensor` | bool | Enable / disable gas monitoring |
| `tempSensor` | bool | Enable / disable DHT11 readings |
| `ledSensor` | bool | Enable / disable LED sensor logic |
| `pirSensor` | bool | Enable / disable PIR reading |
| `ldrSensor` | bool | Enable / disable LDR light detection |
| `buzzer` | bool | Enable / disable buzzer output |
| `autoLight` | bool | Enable / disable automatic LDR night light |
| `led2` | bool | Directly set the night light LED |
| `door` | bool | `true` = open door (servo 90°, green LED on); `false` = lock door (servo 0°, red LED on) |
| `mq2Pwr` | bool | Toggle MOSFET power to MQ-2 sensor |
| `lcdPwr` | bool | Toggle MOSFET power to LCD |

**Example — open the door:**
```json
POST http://<ESP32_IP>:8080/control
{"door": true}
```

**Example — turn off everything:**
```json
POST http://<ESP32_IP>:8080/control
{"system": false}
```

### Security & RFID

The RFID reader (MFRC522) is the primary door control. The allowed card UID is stored in the `ALLOWED_UID` constant. On a correct card scan, the servo rotates to 90° and the green LED turns on. On a wrong card, a beep is emitted and the wrong-attempt counter increments. After **3 wrong attempts** the system enters a **60-second lockout** — the LCD shows a countdown and no RFID scans are processed.

The app's Door button bypasses RFID authentication entirely and controls the servo directly via the `/control` endpoint. Keep the ESP32 on a trusted local network.

### Sensor Behavior

**Gas alarm (MQ-2):** When `gasPercent ≥ 20%`, the alarm LED (LED1) blinks at 200 ms intervals and the buzzer sounds. The LCD shows `GAS: XX% DANGER!`. The alarm clears automatically once gas drops below the threshold. If the MQ-2 appears disconnected (DO = LOW and analog < 200), an `ERROR!!! MQ2 IS OFF` message is shown instead.

**Night light (LDR):** When `autoLightOn` is true, the LDR digital output is polled. When darkness is detected (DO = HIGH), LED2 turns on automatically. The physical button on pin 33 also toggles LED2 manually, overriding auto mode until the next LDR state change.

**Motion (PIR):** The HC-SR501 output is read on pin 12. When the sensor goes HIGH (motion detected), `pirDetected: true` is included in the status response. The app uses this field to trigger an in-app motion alert notification.

---

## Tech Stack

- **Flutter / Dart** — Cross-platform mobile framework
- **Material 3** — UI components, theming, and visual structure
- **HTTP** — Communication with the ESP32 smart home controller
- **Flutter Local Notifications** — Local alert and notification handling
- **Permission Handler** — Runtime permission management
- **Shared Preferences** — Persistent local storage for settings, accounts, and session
- **Image Picker** — Gallery photo selection for user profiles
- **URL Launcher** — Opening external links from within the app

---

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/Mr-PeterMaged/EcoSystem_controller.git
cd EcoSystem_controller
```

### 2. Install Flutter dependencies

```bash
flutter pub get
```

### 3. Connect a device or start an emulator

```bash
flutter devices
```

### 4. Run the application

```bash
flutter run
```

### 5. Build a release APK

Use the included Python automation script to build, version, and upload the APK:

```bash
python build_apk.py
```

Or build only (no upload):

```bash
python build_only.py
```

The APK will be saved to `apk_builds/`.

### 6. Configure the IoT controller

Open **Settings → Connection** in the app and enter the IP address of your ESP32 controller. The app communicates over HTTP:

```
GET  /status
POST /control
```

---

## Python Automation Scripts

All scripts live in the project root and are run with `python <script>.py`. Install dependencies first:

```bash
pip install -r requirements.txt
```

---

### `github_repos.py` — Central repository constants

Shared configuration file imported by all other scripts. Defines:
- GitHub owner and repository names for both the source-code repo and the APK-only repo
- Repository URLs (`CODE_REPO_URL`, `APK_REPO_URL`)
- Default remote name (`origin`) and branch (`main`)
- App display name and public APK filename

No CLI — imported as a module.

---

### `build_apk.py` — Full build, upload, and source-push pipeline

The main automation entry point. Runs the entire release workflow in one command:

1. Copies the project logo into Android drawable resources and sets the launcher icon and app label.
2. Auto-increments the build number in `pubspec.yaml`.
3. Runs `flutter clean` to clear stale cache.
4. Runs `flutter pub get` to install dependencies.
5. Prepares the Gradle cache and stops stale daemons.
6. Builds the release APK with `flutter build apk --release`.
7. Copies the versioned APK to `apk_builds/`.
8. Calls `upload.py` to push the APK to the public APK repository and GitHub Releases.
9. Commits and pushes source-code changes to the source repository.

Shows a real-time progress bar with elapsed time and ETA throughout the build.

```bash
python build_apk.py
python build_apk.py --mode debug
python build_apk.py --skip-upload --skip-source-upload
python build_apk.py --no-version-bump
python build_apk.py --no-clean --skip-pub-get   # fastest rebuild
```

**Requires:** Windows (uses `gradlew.bat` and `taskkill`), Flutter in PATH, `secrets.env` with `GITHUB_TOKEN`.

---

### `build_only.py` — Lightweight APK build (no upload)

Minimal script that builds the APK without any upload, versioning, or Git steps. Useful for local testing.

1. Runs `flutter pub get`.
2. Runs `flutter build apk --release` (or `--debug`).
3. Copies the APK to `apk_builds/` with an auto-incremented sequential number.

```bash
python build_only.py           # release APK
python build_only.py --debug   # debug APK
```

---

### `upload.py` — Upload APK to the public APK repository

Pushes the latest APK to the dedicated APK-only GitHub repository (`EcoSystem_controller_APK`).

1. Calls `github.py` to clone or update the local APK repository mirror.
2. Removes any old APK files from the repo.
3. Copies the new APK under the public name (`EcoSystem_Controller.apk`).
4. Writes a `README.md` and `VERSION.txt` with the current version and timestamp.
5. Commits and pushes to the APK repository.
6. Optionally calls `APK_GIT.py` to also publish a GitHub Release with a QR code.

```bash
python upload.py
python upload.py --apk apk_builds/MyApp.apk --version 1.0.0+5
python upload.py --with-release   # also publish a GitHub Release + QR code
```

---

### `APK_GIT.py` — Publish APK to GitHub Releases and generate a QR code

Creates or updates a GitHub Release for the latest APK and generates a scannable QR code pointing to the direct download URL.

1. Loads `GITHUB_TOKEN` from `secrets.env` or the environment.
2. Reads the version from `pubspec.yaml`.
3. Finds the latest APK in `apk_builds/`.
4. Gets or creates a GitHub Release with the version tag (e.g. `v1.0.0-build.5`).
5. Deletes any old APK and QR assets from the release.
6. Uploads the new APK as a release asset.
7. Generates a QR code image (`apk_builds/EcoSystem_Controller_download_qr.png`) pointing to the APK download URL.
8. Saves the direct download URL to `apk_builds/EcoSystem_Controller_download_link.txt`.
9. Uploads the QR code image as a release asset.

```bash
python APK_GIT.py
python APK_GIT.py --apk apk_builds/MyApp.apk --version 1.0.0+5
python APK_GIT.py --no-upload-qr-asset   # generate QR locally, don't upload it
```

**Requires:** `GITHUB_TOKEN` in `secrets.env` or as an environment variable.

---

### `upload_code.py` — Push source code to GitHub

Commits and pushes all source-code changes to the source repository (`EcoSystem_controller`).

1. Initializes a Git repository if one does not exist.
2. Configures the `origin` remote to point to `CODE_REPO_URL`.
3. Syncs with the remote branch (fetches and rebases, or resets if histories are unrelated).
4. Stages all files (`git add --all`).
5. Creates a timestamped commit if there are any changes.
6. Pushes to the remote branch.

```bash
python upload_code.py
python upload_code.py --message "Add profile screen"
python upload_code.py --branch feature/new-ui
```

---

### `upload_all.py` — Commit and push all Git repositories in the project

Discovers every Git repository under the project root (including nested ones) and pushes each one. Handles large files automatically via Git LFS.

1. Walks the project tree to find all `.git` directories (skips the APK repo mirror).
2. For each discovered repository:
   - Ensures the correct remote is configured (reads `repo_url.txt` as a fallback).
   - Optionally tracks files ≥ 100 MB with Git LFS.
   - Stages all files and commits if there are changes.
   - Pushes to the remote branch.

```bash
python upload_all.py
python upload_all.py --message "Release 1.0.0"
python upload_all.py --no-recursive-repos   # root repo only
python upload_all.py --no-lfs              # skip Git LFS auto-tracking
```

---

### `github.py` — Prepare the public APK repository

Sets up and maintains the local clone of the APK-only GitHub repository used by `upload.py`.

1. Validates that the local APK repo directory is a proper Git repository.
2. If the directory does not exist, clones the APK repository.
3. If it exists, updates the `origin` remote URL if it has changed.
4. Checks out the correct branch, fetching from remote if it exists.

```bash
python github.py
python github.py --repo-url https://github.com/Owner/Repo.git
```

---

### `git_utils.py` — Shared Git helper library

Low-level Git operations used by other scripts. Not meant to be run directly.

Provides:
- `GitRunner` — wrapper around `subprocess` for running Git commands with consistent error handling
- `GitError` — exception raised on any Git failure
- Helper functions: `init_repository`, `stage_all`, `commit_if_needed`, `push_branch`, `remote_branch_exists`, `collect_staged_changes`, `configure_remote`, etc.
- `read_saved_repo_url` / `save_repo_url` — reads and writes the `repo_url.txt` file used to remember the remote URL across runs

---

### `mockup_gen.py` — Screenshot mockup generator (simple frame)

Wraps app screenshots in a stylized phone frame for use in documentation and the README.

- Draws a realistic phone body with rounded corners, metallic frame, punch-hole camera, side buttons, and home indicator.
- Composites the screenshot behind the frame with a gradient background and a subtle screen glare.
- Supports multiple phone frame colors (black, silver, blue, gold) and background styles (light, dark, white, black, blue, purple).
- Optionally captures a live screenshot from a connected Android device via ADB.

```bash
python mockup_gen.py
python mockup_gen.py --capture           # pull screenshot from connected device
python mockup_gen.py --bg dark --phone silver
python mockup_gen.py --scale 0.75        # shrink output to 75%
```

Input folder: `mockup/input/` — Output folder: `mockup/output/`

---

### `make_phone_mockups.py` — iPhone 14 Pro mockup generator (high-fidelity)

Generates high-resolution iPhone 14 Pro mockups at 1080×1920 px. The visual design matches the project website's mockup canvas exactly, including the Dynamic Island, titanium frame, gradient backgrounds, and green/blue ambient glows.

- Three background styles: `dark` (default), `green`, `light`
- Three phone frame colors: `black` (default), `silver`, `green`
- Two fit modes: `cover` (fills screen area) or `contain` (letterboxed)
- Output scale factor for resizing

```bash
python make_phone_mockups.py
python make_phone_mockups.py --background green --phone silver
python make_phone_mockups.py --fit contain --scale 0.5
python make_phone_mockups.py --input mockup/input --output mockup/output
```

---

### `capture_app_screens.py` — Automated screenshot capture from device

Launches the app on a connected Android device or emulator via ADB, navigates through the screens automatically, and captures a screenshot of each. After capturing, calls `make_phone_mockups.py` to generate the final mockups.

```bash
python capture_app_screens.py
```

---

### `capture_web.py` — Automated screenshot capture from browser

Captures screenshots of the project web app running in a browser (used for web mockup generation).

```bash
python capture_web.py
```

---

### `capture_common.py` — Shared capture utilities

Internal library used by `capture_app_screens.py` and `capture_web.py`. Provides shared constants, ADB helpers, device/browser dataclasses, and utility functions. Not meant to be run directly.

---

### `conftest.py` — pytest configuration

Adds the project root to `sys.path` so that all Python scripts can be imported by pytest regardless of the working directory. Required for the test suite to collect test modules correctly.

---

## GitHub Secrets Setup

Before running any upload or release script, create `secrets.env` in the project root:

```bash
# Copy the template
cp secrets.env.example secrets.env
```

Then edit `secrets.env` and add your personal GitHub token:

```
GITHUB_TOKEN=ghp_your_token_here
```

**Never commit `secrets.env`.** It is listed in `.gitignore`.

---

## Project Structure

```
lib/
├── main.dart                      # App entry point and root configuration
├── screens/
│   ├── loading_screen.dart        # Splash screen — auto-login or login/signup routing
│   ├── signup_screen.dart         # First-time account creation
│   ├── login_screen.dart          # Authentication screen
│   ├── home_screen.dart           # Dashboard and system overview
│   ├── profile_screen.dart        # User profile — photo, name, password
│   ├── control_screen.dart        # Full smart home control panel
│   ├── stats_screen.dart          # Sensor readings and statistics
│   ├── notifications_screen.dart  # In-app alerts and notification history
│   ├── display_screen.dart        # Theme, connection, and alert settings
│   └── about_screen.dart          # Team, project, and website information
├── services/
│   ├── app_settings_service.dart  # Persistent app settings storage
│   ├── user_storage_service.dart  # Account management, login, and session handling
│   ├── connection_service.dart    # HTTP communication with IoT controller
│   └── notification_service.dart  # Local notification setup and delivery
├── models/
│   └── app_user.dart              # User account model with profile image support
└── widgets/
    ├── control_button.dart        # Toggle-style control button
    └── green_button.dart          # Primary action button

data/
└── users.json                     # Development mirror for locally created users

apk_builds/                        # Built APKs (git-ignored)
build_logs/                        # Build log files (git-ignored)
mockup/
├── input/                         # Screenshot inputs for mockup scripts
└── output/                        # Generated phone mockup images
Logo/
├── dark_mode.png                  # Logo for dark backgrounds
└── light_mode.png                 # Logo for light backgrounds
```

---

## Running the Tests

```bash
pip install -r requirements.txt
python -m pytest tests/ -v
```

---

## Team

| Name | Role |
|---|---|
| Peter Maged | Project Leader |
| Recardo Raafat | Assistant Leader |

---

## Contributing

1. Fork the repository.
2. Create a new branch for your feature or fix.
3. Make your changes with clear, readable code.
4. Test the app before submitting.
5. Open a pull request with a short description of your changes.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
