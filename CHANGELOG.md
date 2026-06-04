# Changelog

## 1.0.1 (2026-06-04)

### Bug Fixes
- Fixed Google Sign-In failing in release builds (added Play App Signing SHA-1)
- Fixed camera and barcode scanner crash in release mode (ProGuard rules for CameraX/ML Kit)
- Fixed oval-shaped loading spinner on login button
- Removed scan limit from barcode lookup (uses free Open Food Facts API, not Gemini)
- Fixed delete snackbar text not visible and not auto-dismissing
- Disabled Log Meal button when AI detects no food items
- Pinned Log Meal button at bottom of result sheet (no more scrolling to find it)
- Fixed manual entry starting with empty untitled item
- Fixed dismissed item editor still adding empty item to list
- Fixed Analyse with AI and Re-Analyse not calling Gemini for manual/edited items
- Log Meal now requires meal name and at least one named item
- Meal score hidden in manual mode until AI analysis is done
- Clamped BMI/BMR inputs to realistic ranges (prevents nonsensical values)
- Network errors in auth now show user-friendly message
- Google sign-in cancellation no longer shows error
- Improved email validation with proper regex
- Rejected whitespace-only passwords
- Splash screen no longer hangs on Firestore error
- Forgot password validates email format before sending
- Fixed diary delete/undo using wrong date for recalculation
- Added error handling to undo callback (shows error on failure instead of silent loss)
- Meals with non-standard meal types no longer silently hidden in diary
- Pull-to-refresh now awaits actual data instead of fake delay
- Prevented confetti stacking on rapid meal logging

### New Features
- BMI & BMR display card on home screen with color-coded BMI category
- BMI & BMR info screen — explains BMI categories, BMR formula, how calorie/macro targets are calculated
- Capture/Scan/Manual mode toggle on the Snap tab
- Scanning UI overlay during AI meal analysis with animated scan line and corner brackets
- Barcode 404 handled gracefully (product not found instead of error)
- "Analyse with AI" button for manual items to get Gemini nutrition analysis
- "Re-Analyse" button shown after editing previously analysed items
- Per-item meal storage — individual food items now saved to Firestore for detailed breakdown
- Redesigned diary meal details to match snap result sheet UI (meal score, items, macros, vitamins)
- Meal photo displayed at the top of diary details bottom sheet
- Meal delete button with confirmation dialog on diary screen
- Double-tap back to exit with navigate-to-home-first behavior
- Keyboard now dismisses on submit across all screens

### Improvements
- Snackbar message shown when daily calorie goal is achieved
- Motivational "Start your streak today!" message when streak is 0
- Tooltip on meal card to reveal full name on long press
- Visible green-tinted placeholder for meal card images
- Shimmer loading for minerals/vitamins and streak sections
- Keyboard actions on login form (Next/Done with auto-submit)
- PopScope on login and profile setup screens
- Forgot password dismisses keyboard
- Password visibility toggle has accessibility tooltip
- Moved onboarding screen to first home visit instead of after registration
- New users now go directly to profile setup after sign-up for a smoother flow
- Added tappable Terms of Service and Privacy Policy links on login screen
- Added "Created by Prasad Rawas" to splash and settings screens
- FAB actions (Camera/Gallery/Barcode/Manual) now route through the Snap tab instead of pushing separate screens
- Mode toggle always visible on Snap tab with correct mode pre-selected from FAB
- Switching mode toggle clears previous state for a fresh start
- Changed FAB icon from plus to camera
- Hidden FAB on Snap screen to avoid redundancy
- AppBar now shown on Snap tab
- Fixed Expanded inside Wrap crash on profile edit screen

## 1.0.0 (2026-06-03)

### Features
- AI-powered meal analysis using Google Gemini with automatic model fallback across 5 models (~580 RPD combined)
- Barcode scanning for packaged food nutrition lookup
- Food diary with date-based meal browsing
- Weekly and monthly progress charts (calories, macros, nutrition trends)
- Meal reminder notifications — customizable daily reminders for breakfast (10AM), lunch (2PM), dinner (8PM)
- Pre-permission prompt shown after first meal log for a natural opt-in flow
- Dark and light theme with Material 3 design
- Email/password authentication with registration, sign-in, and forgot password
- Google Sign-In authentication
- Secure account deletion with automatic re-authentication (Google re-auth or password prompt)
- Firestore offline persistence
- CSV data export with date range selection
- Cloudinary image upload for meal photos
- Daily scan limit enforcement
- In-app legal pages (privacy policy, terms, disclaimer) via webview

### Branding
- Dual-color "BiteBloom" styling — "Bite" in white, "Bloom" in accent green (#00E676)
- Applied consistently across app (splash, login, home, settings) and website (nav, footer, hero)
- OG image (1200x630) and Play Store feature graphic (1024x500)

### Website
- Landing page at bitebloom.prasadrawas.online
- Privacy policy, terms of service, and disclaimer pages
- SEO: structured data, sitemap, robots.txt, canonical URLs, OG/Twitter meta tags
- Google Search Console verification

### Infrastructure
- Release signing with keystore and ProGuard/R8 obfuscation
- minSdk set to 24 for Play Store compliance
- Adaptive icons with round variant
- Debug logging gated behind kDebugMode