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

## Admin Verification Operations
Manual verification decisions are handled via the backend admin API (`/v1/admin`) and can be connected to a low-code operations panel.

### Minimum secure setup
1. Keep `x-admin-key` outside source control (secret store only).
2. Restrict panel/API access by office VPN or allowlisted IP ranges.
3. Record who approved/rejected and why (reason field in panel workflow).
4. Use the same status taxonomy: `pending`, `verified`, `rejected`.

### Core endpoints
- `GET /v1/admin/verifications?status=pending`
- `POST /v1/admin/verifications/:userId/identity`
- `POST /v1/admin/verifications/:userId/license`
- `POST /v1/admin/verifications/:userId/criminal-record`

### Suggested low-code workflow
1. List pending users from `GET /verifications`.
2. Show document URLs for identity/license/criminal record.
3. Submit approve/reject decisions to the matching endpoint.
4. Enforce reason entry for rejections in panel logic.

