# QA Results (Ridesharing SuperApp)

Date: 2026-02-07
Scope: Web + Android
Environment:
- Backend: http://localhost:3000/v1
- Web: http://localhost:5000
- Android: BLOCKED (no AVD/emulator configured)

Legend:
PASS | FAIL | PLACEHOLDER | DEMO | MISSING_UI | MISSING_API | BLOCKED | UNTESTED

High-level Findings (P0/P1)
1) P1: Messaging list is gated by booking status `confirmed/checked_in/completed`. With payment off, conversations stay empty (BLOCKED).

Auth (A1)
Step | Status | Evidence/Notes
Register | PASS | POST /auth/register created `qa_20260207032732@demo.local`
Login | PASS | POST /auth/login (identifier + password)
/me | PASS | GET /auth/me
Logout | UNTESTED | UI only
Forgot password | PLACEHOLDER | Login screen has onPressed: () {}

Home (B1)
Step | Status | Evidence/Notes
Home load | UNTESTED | UI not exercised; map now shows neutral base map (no demo route)
Search card | UNTESTED | Updated to real inputs + search params; needs retest
Popular routes | UNTESTED | Now computed from `/trips`; needs retest
Recent trips | UNTESTED | Now computed from `/bookings/my`; needs retest

Search + Trip Detail (C1)
Step | Status | Evidence/Notes
Search API | PASS | GET /trips?from=Istanbul&to=Ankara&date=2026-02-08 => 1 trip
Search screen | UNTESTED | UI not exercised; form uses provider
Search results | UNTESTED | UI not exercised; uses provider + API
Trip detail API | PASS | GET /trips/:id OK
Trip detail UI | UNTESTED | “Mesaj” artık rezervasyon varsa chat açıyor; ihtiyaç: retest

Booking (Passenger) (C2)
Step | Status | Evidence/Notes
Create booking API | PASS | POST /bookings with seats=1
Booking list API | PASS | GET /bookings/my
Cancel booking | PASS | DELETE /bookings/:id
Show QR | BLOCKED | Requires confirmed booking (payment)
Open chat from booking | UNTESTED | Chat button now routes to /chat; needs retest

Driver Flow (D1)
Step | Status | Evidence/Notes
Create trip API | PASS | POST /trips works without `description`
Create trip UI | UNTESTED | UI updated to accept description; needs retest
Driver bookings API | PASS | GET /bookings/trip/:tripId
Driver approve/reject | MISSING_API+UI | Backend has no approve/reject endpoints; UI does not include
My trips API | PASS | GET /trips/my returns driver listings
My trips UI | UNTESTED | New /trip-history screen added; needs retest
QR check-in | BLOCKED | Requires confirmed booking/payment

Messaging (E1)
Step | Status | Evidence/Notes
Conversations list | BLOCKED | Backend only returns confirmed/checked_in/completed bookings
Chat send | UNTESTED | Requires confirmed booking
Unread count | UNTESTED | Requires messages
Search in chat | PLACEHOLDER | SnackBar “yakında”

Verification (F1)
Step | Status | Evidence/Notes
Status API | PASS | GET /verification/status
Upload identity | UNTESTED | Requires image file
Upload license front/back | UNTESTED | Requires image files
Upload criminal record | UNTESTED | Requires pdf/img
UI capture guide | PASS | Implemented; camera overlay present

Vehicles (G1)
Step | Status | Evidence/Notes
List vehicles | PASS | GET /vehicles for driver
Add vehicle UI | UNTESTED | UI exists; API POST /vehicles works (QA run created vehicle)
Vehicle verification upload | UNTESTED | Requires image file

Profile / Settings (H1)
Step | Status | Evidence/Notes
Profile header | UNTESTED | Bound to current user; needs retest
Profile details | UNTESTED | Editable profile form exists; needs retest
Profile edit | UNTESTED | PUT /users/me wired; needs retest
Settings (language) | PASS | Locale switcher present
Trip history | UNTESTED | Replaced with “My Trips” screen
Payment methods | PLACEHOLDER | Placeholder screen
Help | PLACEHOLDER | Placeholder screen
Wallet/Security/About | PLACEHOLDER | onTap empty

Build / Ops
Step | Status | Evidence/Notes
flutter build web | FAIL | file_picker web plugin missing
Android test | BLOCKED | No emulator configured

Notes
- Messaging and QR flows depend on payment confirmation; currently payment is mocked but UI flow does not expose it.
- There are duplicate/unused screens: `trip_details_screen.dart` (demo) and `booking_screen.dart` (demo) reachable only via unused route.
- Many Turkish strings still show mojibake in several screens.

---

## Quick Update (2026-02-12)
Scope: Regression sanity after ongoing route/search/context work.

Checks executed
- Backend: `npm run type-check` -> PASS
- Backend: `npm test -- --runInBand src/application/services/trips/trips.service.spec.ts` -> PASS
- Backend: `npm test -- --runInBand src/application/services/bookings/bookings.service.spec.ts` -> PASS
- Mobile: `flutter analyze` -> PASS
- Mobile: `flutter build apk --debug` -> PASS

Fixes validated
- `mobile/lib/core/services/location_service.dart`: compile fix (`late final` assignment issue removed).
- `mobile/lib/features/trips/presentation/create_trip_screen.dart`: UTF-8 text recovered + route card readability improved.
- `mobile/lib/features/home/presentation/home_screen.dart`: UTF-8 text recovered.
- `mobile/pubspec.yaml`: web SVG illustration assets registered to remove runtime 404s.

Open issue
- Flutter web log still reports invalid UTF-8 in `/v1/trips` response body (`Bad UTF-8 encoding (U+FFFD)`), indicating existing DB/seed text corruption. Needs data-level cleanup before final smoke sign-off.
