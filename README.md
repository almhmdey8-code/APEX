APEX Backend
Secure server-side payment and order foundation for the Flutter app.
Setup
Install Node.js 20+ and PostgreSQL.
Create a database and run schema.sql.
Copy .env.example to .env and add production credentials.
Run npm install then npm start.
Put the backend behind HTTPS and a reverse proxy before production.
Payment providers
Tabby KSA: TABBY_API_BASE=https://api.tabby.sa
Tamara KSA: TAMARA_API_BASE=https://api.tamara.co
PayPal Live: https://api-m.paypal.com
Secrets stay on the server. Never put provider secret keys in Flutter.
Production requirements
Configure real merchant credentials and complete provider QA/approval.
Configure HTTPS webhook URLs in each provider dashboard.
Add rate limiting/WAF, centralized logs, backups, monitoring, email/SMS notifications, and a real product/inventory service.
Google Pay should be connected through a supported processor/gateway; do not process raw card data directly in the Flutter client.
