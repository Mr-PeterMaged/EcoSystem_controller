# Smart Home Control System

Smart Home Control System is a Flutter mobile application for monitoring and controlling a connected home automation setup. The app provides a modern interface for checking sensor data, managing device states, receiving safety alerts, and switching between display modes.

The project is designed for smart home and IoT use cases where users need a simple mobile dashboard to interact with sensors and actuators such as gas sensors, temperature sensors, PIR motion sensors, LEDs, buzzers, and automatic lighting.

## 📱 Overview

This application allows users to sign in, view the current system status, control connected home components, monitor environmental readings, and review important alerts from the smart home system. It is built with Flutter and can be connected to a backend service or IoT controller such as an ESP32 through HTTP endpoints.

## Features

- User authentication through a login screen
- Admin dashboard for system overview and connection status
- Smart home system status monitoring
- Full control panel for connected components
- Toggle controls for:
  - Main system
  - Gas sensor
  - Temperature sensor
  - PIR motion sensor
  - LEDs
  - Buzzer
  - Auto light mode
- System statistics screen for:
  - Temperature
  - Humidity
  - Gas detection status
  - Motion detection
  - LED status
- Notifications and alerts for:
  - System updates
  - Temperature warnings
  - Gas detection
  - Motion detection
- Display settings for light mode and dark mode
- Modern UI with a dark theme and green accent color
- IoT-ready architecture for smart device communication

## Screenshots

Add app screenshots to a `screenshots/` folder and update the paths below.

### Login

![Login Screen](screenshots/login.png)

### Dashboard

![Dashboard Screen](screenshots/dashboard.png)

### Control Panel

![Control Screen](screenshots/control.png)

### Statistics

![Statistics Screen](screenshots/stats.png)

### Notifications

![Notifications Screen](screenshots/notifications.png)

### Settings

![Settings Screen](screenshots/settings.png)

## Tech Stack

- **Flutter** - Cross-platform mobile app framework
- **Dart** - Programming language used by Flutter
- **Material Design** - UI components and visual structure
- **HTTP** - Communication with smart home backend or IoT controller
- **Flutter Local Notifications** - Local alert and notification handling
- **Permission Handler** - Runtime permission management
- **State Management** - Built-in Flutter state management with `StatefulWidget` and `setState`
- **Backend / IoT Layer** - Generic REST API or ESP32-based smart home controller

## Installation

Follow these steps to run the project locally.

### 1. Clone the repository

```bash
git clone <repository-url>
cd app1
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

### 5. Configure the IoT controller

On the login screen, enter the IP address of your smart home controller or backend server. The app is prepared to communicate with endpoints such as:

```text
GET  /status
POST /control
```

## Usage

1. Open the app on a mobile device or emulator.
2. Log in with valid user credentials.
3. Enter the smart home controller IP address if required.
4. View the dashboard to check system status and sensor availability.
5. Use the full control screen to turn sensors and devices on or off.
6. Open the statistics screen to monitor temperature, humidity, gas status, and motion state.
7. Review notifications for important alerts and safety warnings.
8. Change display settings to switch between light mode and dark mode.

## Project Structure

```text
lib/
+-- main.dart                      # App entry point and root configuration
+-- screens/                       # Main application screens
|   +-- login_screen.dart          # Authentication and controller IP input
|   +-- home_screen.dart           # Dashboard and system overview
|   +-- control_screen.dart        # Full smart home control panel
|   +-- stats_screen.dart          # Sensor readings and system statistics
+-- services/                      # App services and integrations
|   +-- connection_service.dart    # HTTP communication with IoT controller
|   +-- notification_service.dart  # Local notification setup and alerts
+-- widgets/                       # Reusable UI components
|   +-- control_button.dart        # Toggle-style control button
+-- assets/                        # Images and static assets

android/                           # Android platform files
ios/                               # iOS platform files
web/                               # Web platform files
test/                              # Flutter widget and unit tests
pubspec.yaml                       # Project dependencies and assets
```

## Future Improvements

- Add real-time sensor updates using WebSockets or MQTT
- Integrate with Firebase, Supabase, or a custom backend
- Add push notifications for critical alerts
- Improve role-based access for admin and regular users
- Add historical charts for temperature, humidity, gas, and motion events
- Store user preferences such as theme mode and default controller IP
- Add device discovery for local IoT controllers
- Improve offline mode and connection recovery
- Add automated tests for authentication, controls, and services

## Contributing

Contributions are welcome. To contribute:

1. Fork the repository.
2. Create a new branch for your feature or fix.
3. Make your changes with clear, readable code.
4. Test the app before submitting.
5. Open a pull request with a short description of your changes.

Please keep contributions focused, documented, and consistent with the existing Flutter project structure.

## License

This project is licensed under the MIT License.

See the [LICENSE](LICENSE) file for details.
