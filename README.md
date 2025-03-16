# Mingle - Professional Networking & Dating App

Mingle is a modern Flutter application that combines professional networking with dating features, designed specifically for working professionals who want to connect with like-minded individuals for both professional and personal relationships.

## Features

- User authentication with email/password and Google Sign-in
- Professional profile creation and management
- Browse and discover other professionals
- Real-time messaging (coming soon)
- Location-based matching
- Interest-based connections
- Modern and intuitive UI design

## Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Firebase account and project
- Android Studio / VS Code with Flutter extensions

### Setup

1. Clone the repository:
```bash
git clone https://github.com/yourusername/mingle.git
cd mingle
```

2. Install dependencies:
```bash
flutter pub get
```

3. Firebase Setup:
    - Create a new Firebase project
    - Add Android and iOS apps to your Firebase project
    - Download and add the configuration files:
        - Android: `google-services.json` to `android/app/`
        - iOS: `GoogleService-Info.plist` to `ios/Runner/`

4. Enable Firebase services:
    - Authentication (Email/Password and Google Sign-in)
    - Cloud Firestore
    - Storage

5. Run the app:
```bash
flutter run
```

## Project Structure

```
lib/
  ├── models/         # Data models
  ├── screens/        # UI screens
  ├── services/       # Business logic and services
  ├── utils/          # Utility functions and constants
  ├── widgets/        # Reusable widgets
  └── main.dart       # App entry point
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Flutter team for the amazing framework
- Firebase for the backend services
- All contributors who help to make Mingle better
