# Runbooks

## Local Development
1. Start dependencies:
   - `docker-compose up -d`
2. Backend:
   - `cd backend`
   - `cp .env.example .env`
   - `npm install`
   - `npm run db:generate`
   - `npm run dev`
3. Mobile:
   - `cd mobile`
   - `flutter pub get`
   - `flutter run`

## Health Checks
- API: `GET /v1/health`
- Readiness: `GET /v1/ready`

## Notes
- Integrations are mocked by default. Set `USE_MOCK_INTEGRATIONS=false` to enable real providers.

