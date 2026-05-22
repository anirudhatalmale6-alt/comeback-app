# Come Back - Employee Paging System

A mobile app for nail salons that lets owners page employees when they're needed back at work. Built with Flutter and Firebase.

## Features

- **Owner & Employee accounts** with photo upload
- **Connect via ID code or QR scan** (like adding friends on Zalo)
- **Page/Alarm system** - Owner taps a button, employee's phone plays a loud alarm
- **Employee confirms with OK** - Owner sees acknowledgement
- **Owner can Stop** the alarm remotely
- **Background notifications** - Works even when app is closed
- **Private chat** between owner and employee
- **Group chat** for all team members
- **Disconnect/reconnect** when employees change salons

## Tech Stack

- **Frontend**: Flutter (Android + iOS from single codebase)
- **Auth**: Firebase Authentication (email/password)
- **Database**: Cloud Firestore
- **Push Notifications**: Firebase Cloud Messaging
- **Cloud Functions**: Node.js (sends FCM notifications)
- **Storage**: Firebase Storage (profile photos)

## Setup Instructions

### 1. Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/) and create a new project
2. Enable **Authentication** > Email/Password sign-in
3. Create a **Firestore Database** (start in test mode, deploy rules later)
4. Enable **Firebase Storage**
5. Register Android app with package name `com.comeback.app`
6. Register iOS app with bundle ID `com.comeback.app`
7. Download `google-services.json` → place in `android/app/`
8. Download `GoogleService-Info.plist` → place in `ios/Runner/`

### 2. Flutter App

```bash
flutter pub get
flutter run
```

### 3. Cloud Functions

```bash
cd firebase/functions
npm install
firebase deploy --only functions
```

### 4. Firestore Rules & Indexes

```bash
cd firebase
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

### 5. Alarm Sound

Place an alarm sound file at `assets/sounds/alarm.mp3`. Any short, attention-grabbing alarm sound will work.

## Architecture

```
lib/
├── main.dart              # App entry point, providers setup
├── models/                # Data models (User, PageAlert, ChatMessage, etc.)
├── services/              # Firebase service layer
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   ├── notification_service.dart
│   └── storage_service.dart
├── screens/
│   ├── auth/              # Login, register, role selection
│   ├── owner/             # Owner dashboard, add employee, profile
│   ├── employee/          # Employee dashboard, alarm overlay, profile
│   ├── chat/              # Private & group chat
│   └── connection/        # QR code display widget
├── widgets/               # Reusable widgets (message bubble)
└── utils/                 # Theme configuration

firebase/
├── functions/             # Cloud Functions for FCM push notifications
├── firestore.rules        # Security rules
└── firestore.indexes.json # Required composite indexes
```
