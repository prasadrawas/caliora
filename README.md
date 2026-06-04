# BiteBloom

Your AI Nutrition Companion — snap a photo of any meal and instantly get detailed nutrition analysis.

**Website:** [bitebloom.prasadrawas.online](https://bitebloom.prasadrawas.online)

**Legal:**
[Privacy Policy](https://bitebloom.prasadrawas.online/privacy.html) · [Terms of Service](https://bitebloom.prasadrawas.online/terms.html) · [Disclaimer](https://bitebloom.prasadrawas.online/disclaimer.html)

## Features

- **AI Meal Analysis** — Take a photo and get per-item nutrition breakdown (16 nutrients) powered by Google Gemini, with a scanning UI overlay during analysis
- **Barcode Scanning** — Scan packaged food barcodes for instant nutrition lookup
- **Capture/Scan/Manual Toggle** — Switch between photo capture, barcode scan, and manual entry modes on the Snap tab
- **Food Diary** — Browse and review meals logged by date, with delete confirmation and undo
- **BMI & BMR Insights** — View your BMI and BMR on the home screen with an educational info page explaining how your nutrition targets are calculated
- **Progress Tracking** — Weekly and monthly charts for calories, macros, and nutrition trends
- **Meal Reminders** — Customizable daily notifications for breakfast, lunch, and dinner
- **Onboarding** — Interactive walkthrough on first home visit to guide new users
- **Email & Google Auth** — Sign up/sign in with email and password, or continue with Google. Includes forgot password and secure account deletion with re-authentication
- **Dark & Light Themes** — Material 3 dual-theme design
- **Offline Support** — Firestore offline persistence for uninterrupted tracking
- **Data Export** — Export meal history as CSV

## Tech Stack

- **Flutter** (SDK ^3.12.0) — Cross-platform UI
- **Firebase** — Auth (Email/Password + Google Sign-In), Firestore, Analytics
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
