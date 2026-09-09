# APEX — Production launch checklist

## 1) Flutter
- Install Flutter 3.x and run `flutter pub get`.
- Run `flutter analyze` and `flutter test`.
- Set the backend base URL in the app configuration.
- Create Android/iOS signing credentials and release builds.

## 2) Backend
- PostgreSQL database + backups.
- HTTPS reverse proxy.
- Set all secrets in the server environment, never in source control.
- Run `npm install` inside `backend/` then `npm start`.

## 3) Payments
- Tabby: obtain KSA merchant secret key + merchant code, complete QA, and configure webhook.
- Tamara: obtain API token + notification token, complete sandbox/testing and production approval, then configure webhook.
- PayPal: create a Business account and live app credentials.
- Google Pay: use a supported payment gateway/processor and complete Google Pay production onboarding.
- COD: confirm delivery/cash collection policy and cancellation limits.

## 4) Business data still required
- Real product catalog, SKU/stock, prices, VAT/tax rules, shipping zones/rates.
- Store legal name, commercial registration/tax details, privacy policy, terms, return/refund policy.
- Customer support contact and delivery SLA.

## 5) Security
- Do not store card numbers, CVV, PayPal passwords, or provider secret keys in Flutter.
- Validate prices and stock on the server; never trust totals from the client.
- Verify every provider webhook and make payment/order updates idempotent.
