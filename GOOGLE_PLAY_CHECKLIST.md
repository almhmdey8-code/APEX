# APEX — Google Play release checklist

## Project identity
- App name: APEX | أبيكس
- Application ID: com.apex.store
- Version name: 1.0.0
- Version code: 6
- Target SDK: 36
- Compile SDK: 36

## Before building
1. Install a current stable Flutter SDK and Android SDK Platform 36.
2. Run `flutter pub get`.
3. Run `flutter analyze`.
4. Test login, product browsing, cart, checkout, COD, Tabby/Tamara/PayPal return flows and orders against the production backend.
5. Set `API_BASE_URL` to the production HTTPS API.
6. Configure production payment credentials only on the backend.

## Signing
1. Create a private upload keystore locally.
2. Copy `android/key.properties.example` to `android/key.properties`.
3. Put the real values in `android/key.properties`.
4. Update `android/app/build.gradle` to use the release signing config and keep the keystore out of source control.

## Build
`flutter build appbundle --release --dart-define=API_BASE_URL=https://YOUR_API_DOMAIN`

Expected output:
`build/app/outputs/bundle/release/app-release.aab`

## Play Console
- Create app: APEX | أبيكس
- Upload the AAB to internal testing first.
- Complete App content, Data safety, content rating, target audience, store listing and privacy policy URL.
- Verify payments and order fulfillment in production.
- Promote to closed/open testing, then production after review requirements are satisfied.
