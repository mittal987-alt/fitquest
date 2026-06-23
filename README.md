# 🏃‍♂️ FitQuest

FitQuest is a real-world fitness game built with Flutter and Firebase where players capture territories by walking in the real world.

The app combines GPS tracking, territory conquest, anti-cheat protection, team gameplay, and fitness progression into a gamified outdoor experience.

---

## 🚀 Features

### 🌍 Territory Capture

* Capture hexagonal territories by physically walking.
* Real-time territory ownership updates using Firebase Firestore.
* Solo and Team territory modes.

### 🛡️ Territory System

* Attack enemy territories.
* Defend your own territories.
* Territory power system (0–100).
* Automatic territory regeneration.

### 👥 Team Battles

* Create and join teams.
* Team-based territory ownership.
* Shared land statistics.

### 🏆 Progression System

* Earn XP by:

  * Capturing territories
  * Attacking territories
  * Defending territories
* Player rankings and leaderboards.

### 📍 Live GPS Tracking

* Real-time location updates.
* Google Maps integration.
* Dynamic territory rendering.

### 🔒 Anti-Cheat Protection

* Vehicle detection.
* Teleport detection.
* Trust score system.
* Capture blocking for suspicious movement.

### 🔔 Notifications

* Firebase Cloud Messaging (FCM).
* Local notifications.
* Territory event alerts.

---

## 🛠 Tech Stack

### Frontend

* Flutter
* Dart

### Backend

* Firebase Authentication
* Cloud Firestore
* Firebase Cloud Messaging

### Maps & Location

* Google Maps Flutter
* Geolocator

### State Management

* Provider

---

## 📂 Project Structure

```text
lib/
│
├── models/
│   ├── player_model.dart
│   ├── team_model.dart
│   └── hex_tile_model.dart
│
├── screens/
│   ├── login_screen.dart
│   ├── map_screen.dart
│   ├── leaderboard_screen.dart
│   └── profile_screen.dart
│
├── services/
│   ├── firebase_service.dart
│   ├── location_service.dart
│   ├── territory_service.dart
│   ├── anti_cheat_service.dart
│   ├── notification_service.dart
│   └── pedometer_service.dart
│
└── widgets/
```

## 📸 Screenshots

Add screenshots here:

* Login Screen
* Territory Map
* Team System
* Leaderboard
* Profile

---

## ⚙️ Installation

### Clone Repository

```bash
git clone https://github.com/yourusername/fitquest.git
cd fitquest
```

### Install Dependencies

```bash
flutter pub get
```

### Firebase Setup

1. Create a Firebase Project.
2. Enable:

   * Authentication
   * Firestore Database
   * Cloud Messaging
3. Add:

```text
android/app/google-services.json
```

4. Configure Firebase:

```bash
flutterfire configure
```

### Run App

```bash
flutter run
```

---

## 🎯 Future Plans

* Territory Shields
* Radar Powerups
* Weekly Events
* Team Wars
* Achievement System
* Global Leaderboards
* Territory Heatmaps
* Seasonal Rewards

---

## 👨‍💻 Author

Aayush Mittal

Built using Flutter, Firebase, Google Maps, and a passion for fitness gaming.
