# BiteBloom

Your AI Nutrition Companion — snap a photo of any meal and instantly get detailed nutrition analysis.

**Website:** [bitebloom.prasadrawas.online](https://bitebloom.prasadrawas.online)

## Features

- **AI Meal Analysis** — Take a photo and get per-item nutrition breakdown (16 nutrients) powered by Google Gemini
- **Barcode Scanning** — Scan packaged food barcodes for instant nutrition lookup
- **Food Diary** — Browse and review meals logged by date
- **Progress Tracking** — Weekly and monthly charts for calories, macros, and nutrition trends
- **Meal Reminders** — Customizable daily notifications for breakfast, lunch, and dinner
- **Dark & Light Themes** — Material 3 dual-theme design
- **Offline Support** — Firestore offline persistence for uninterrupted tracking
- **Data Export** — Export meal history as CSV

## Tech Stack

- **Flutter** (SDK ^3.12.0) — Cross-platform UI
- **Firebase** — Auth (Google Sign-In), Firestore, Analytics
- **Google Gemini API** — AI food image analysis with automatic model fallback
- **Cloudinary** — Meal image storage
- **Riverpod** — State management
- **Local Notifications** — Scheduled meal reminders

## Getting Started

```bash
# Install dependencies
flutter pub get

# Create a .env file with your API keys (see .env.example)
cp .env.example .env

# Run the app
flutter run
```

## Build for Release

```bash
# Generate release APK
flutter build apk --release

# Generate App Bundle for Play Store
flutter build appbundle --release
```

## Project Structure

```
lib/
├── core/           # Config, constants, theme, utilities
├── data/           # Models and services (Firebase, Gemini, Cloudinary)
├── providers/      # Riverpod state management
└── presentation/   # Screens and widgets
```

## License

All rights reserved.
