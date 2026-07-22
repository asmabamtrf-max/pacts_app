# Pacts App

Pacts App is a Flutter-based mobile application designed to simplify contract creation, management, and sharing. The application enables users to create digital contracts, edit them, track their history, sign contracts, and securely share them with others.

## Features

- User authentication (Email & Phone)
- Create and edit contracts
- Digital contract signing
- Contract status tracking
- Contract history
- Contract templates
- Share contracts securely
- Firebase Authentication
- Cloud Firestore database
- Location support

## Technologies Used

- Flutter
- Dart
- Firebase Authentication
- Cloud Firestore
- Geolocator
- Shared Preferences
- FL Chart

## Project Structure

```
lib/
│
├── auth/          # Authentication صفحات
├── contracts/     # إدارة العقود
├── models/        # Data Models
├── services/      # Firebase Services
├── share/         # مشاركة العقود
├── home/          # الصفحة الرئيسية
├── pages/         # صفحات إضافية
└── main.dart
```

## Getting Started

### Prerequisites

- Flutter SDK
- Dart SDK
- Firebase Project
- Android Studio or VS Code

### Installation

1. Clone the repository

```bash
git clone https://github.com/your-username/pacts_app.git
```

2. Install dependencies

```bash
flutter pub get
```

3. Configure Firebase

- Add your `google-services.json` file.
- Enable Authentication and Firestore in Firebase Console.

4. Run the application

```bash
flutter run
```

## Dependencies

- firebase_core
- firebase_auth
- cloud_firestore
- geolocator
- shared_preferences
- fl_chart
- flutter_animate
- package_info_plus
- pinput

## Future Improvements

- PDF contract export
- Push notifications
- Cloud Storage for attachments
- Electronic signature enhancements
- Multi-language support

## Authors

Graduation Project

Developed using Flutter & Firebase.
## Project Overview

This project was developed as a graduation project to provide a digital solution for creating, managing, signing, and sharing contracts. The application aims to replace traditional paper-based agreements with a secure and user-friendly mobile platform.
