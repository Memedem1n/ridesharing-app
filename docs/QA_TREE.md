# QA Tree (Ridesharing SuperApp)

Date: 2026-02-07
Scope: Web + Android (Android blocked: no emulator available)
Environment:
- Backend: http://localhost:3000/v1
- Web: http://localhost:5000

Legend:
- PASS: Çalışıyor
- FAIL: Çalışmıyor
- PLACEHOLDER: UI var ama placeholder/demo içerik
- DEMO: Statik/demo veri
- MISSING_UI: API var, UI yok
- MISSING_API: UI var, API yok
- BLOCKED: Akış var ama başka eksik yüzünden ilerleyemiyor
- UNTESTED: Bu turda test edilmedi

Flows

A1 Auth
Steps:
1. Register (email/phone)
2. Login (identifier + password)
3. /auth/me
4. Logout

B1 Home
Steps:
1. Home yüklenme (map + header)
2. Search card -> /search
3. Popular routes list
4. Recent trips list -> /reservations

C1 Search + Results (Passenger)
Steps:
1. /search form doldur
2. /search-results list
3. Trip detail -> /trip/:id
4. Rezerve Et -> /bookings
5. /reservations (Upcoming/Past)

C2 Booking Actions (Passenger)
Steps:
1. Booking list
2. QR göster (confirmed)
3. Mesaj (confirmed)
4. İptal

D1 Driver Flow
Steps:
1. Create trip -> /create-trip
2. Driver requests -> /driver-reservations
3. My trips list -> /trip-history (driver listings)
3. QR scanner -> /qr-scanner/:tripId
4. Check-in -> /bookings/check-in

E1 Messaging
Steps:
1. Conversations list -> /messages
2. Chat -> /chat/:bookingId
3. Send message
4. Unread count

F1 Verification Center
Steps:
1. /verification status
2. Upload identity
3. Upload license (front/back)
4. Upload criminal record (pdf/img)

G1 Vehicles
Steps:
1. /my-vehicles list
2. Add vehicle (UI)
3. Vehicle verification -> /vehicle-verification (upload registration)

H1 Profile
Steps:
1. Profile header
2. Profile details -> /profile-details
3. Settings -> /settings
4. Trip history -> /trip-history (placeholder)
5. Payment methods -> /payment-methods (placeholder)
6. Help -> /help (placeholder)
7. Wallet / Security / About (placeholder)

I1 Misc
Steps:
1. Live location in trip detail
2. OCR scoring/verification (backend)
