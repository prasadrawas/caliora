# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run on connected device/emulator
flutter analyze          # Lint check (uses flutter_lints)
flutter test             # Run all tests
flutter test test/widget_test.dart  # Run a single test file
```

Uses FVM for Flutter version management. SDK constraint: ^3.12.0. Android-only (no iOS/Web Firebase config).

## Architecture

Layered architecture with four layers:

- **`lib/core/`** — Config (`AppConfig` reads `.env` via flutter_dotenv), constants (colors, strings, Gemini prompt), theme (Material3 dark/light), and utilities (logging, date formatting, nutrition calc)
- **`lib/data/`** — Models with Firestore serialization (`fromFirestore`/`toFirestore`/`copyWith`) and services (Firebase Auth, Firestore CRUD, Gemini REST API, Cloudinary uploads, barcode scanning, scan limits)
- **`lib/providers/`** — Riverpod state management. `StreamProvider` for real-time Firestore data (meals, profile, daily summary). `StateProvider` for UI state (selected date). `StateNotifierProvider` for persisted state (theme mode via SharedPreferences)
- **`lib/presentation/`** — Screens and widgets. `HomeShell` is the 5-tab bottom navigation hub

## State Management (Riverpod)

Service singletons are created as Riverpod `Provider`s (e.g., `authServiceProvider`, `firestoreServiceProvider`). Data providers watch both auth state and UI state, rebuilding reactively:

```dart
// Example pattern — watches user + selected date, streams from Firestore
final mealsForDateProvider = StreamProvider<List<MealEntry>>((ref) {
  final user = ref.watch(currentUserProvider);
  final date = ref.watch(selectedDateProvider);
  return ref.watch(firestoreServiceProvider).streamMealsForDate(user.uid, date);
});
```

## Key Data Flows

**Meal analysis**: Image → compress → base64 → Gemini REST API → JSON parsed to `AnalyzedItem` list → user edits → saved as `MealEntry` to Firestore → image uploaded to Cloudinary → daily summary recalculated

**Auth**: Google Sign-In → Firebase Auth → `authStateProvider` (StreamProvider on `authStateChanges`) → gates all data providers

## Routing

Named routes in `main.dart`: `/` (splash), `/login`, `/onboarding`, `/profile-setup`, `/home`. Custom page transitions with fade + slide (400ms).

## Theming

Dual Material3 themes (dark default). Key colors in `AppColors`: `accentGreen` (#00E676) is the primary accent. Per-macro color coding: protein=blue, carbs=orange, fat=red, fiber=green, water=light blue. Fonts: Poppins (headings), Inter (body). Theme-aware colors accessed via `C.of(context)`.

## Configuration

All runtime config lives in `.env` (loaded by flutter_dotenv): Cloudinary credentials, Gemini API key/model, image compression settings, default nutrition targets, daily scan limit. Accessed via `AppConfig` static getters.

## Firestore Structure

User-scoped collections under `users/{uid}/`: `meals`, `daily_summaries`, `weight_logs`, `scan_history`, `scan_usage`. Security rules enforce authentication and required fields per document type.

## Rules

- After every change, update `README.md` and `CHANGELOG.md` to reflect what was added, changed, or fixed.
- Never include Claude or AI co-author details in commit messages or anywhere in the git history.

## App Name Styling

"BiteBloom" is styled with dual colors in all UI occurrences: "Bite" in white/default text color, "Bloom" in `AppColors.accentGreen`. Use `Text.rich` with `TextSpan` children when displaying the app name.
