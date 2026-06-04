# Changelog

## 1.0.1 (2026-06-04)

### Bug Fixes
- Fixed Google Sign-In failing in release builds (added Play App Signing SHA-1)
- Fixed camera and barcode scanner crash in release mode (ProGuard rules for CameraX/ML Kit)
- Fixed oval-shaped loading spinner on login button

### New Features
- BMI & BMR display card on home screen with color-coded BMI category
- BMI & BMR info screen — explains BMI categories, BMR formula, how calorie/macro targets are calculated
- Capture/Scan/Manual mode toggle on the Snap tab
- Scanning UI overlay during AI meal analysis with animated scan line and corner brackets
- Barcode 404 handled gracefully (product not found instead of error)
- Keyboard now dismisses on submit across all screens

### Improvements
- Moved onboarding screen to first home visit instead of after registration
- New users now go directly to profile setup after sign-up for a smoother flow
- Added tappable Terms of Service and Privacy Policy links on login screen
- Added "Created by Prasad Rawas" to splash and settings screens
- Changed FAB icon from plus to camera
- Hidden FAB on Snap screen to avoid redundancy
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