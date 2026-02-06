# Ekip Görev Dağılımı Planı

## 🎯 Roller ve Sorumluluklar

### Roller

1. **Mobile Developer** (2 kişi)
   - Flutter development
   - UI implementation
   - Platform-specific features
   - Mobile testing

2. **Backend Developer** (2 kişi)
   - NestJS API development
   - Database design
   - Business logic
   - Performance optimization

3. **DevOps Engineer** (1 kişi)
   - CI/CD setup
   - Infrastructure
   - Monitoring
   - Deployment

4. **QA Engineer** (1 kişi)
   - Test strategy
   - Manual testing
   - Automation tests
   - Bug tracking

5. **UI/UX Designer** (1 kişi)
   - Wireframes
   - User flows
   - Design system
   - Prototypes

**Toplam:** 7 kişi

---

## 📅 Sprint-Bazlı Görev Dağılımı

### Sprint 1: Infrastructure & Setup (H1-2)

#### Mobile Team (2 devs)

**Developer 1: Project Setup**
- [ ] Flutter 3.x projesini initialize et
- [ ] Package.yaml dependencies ekle (riverpod, dio, socket_io_client, vb.)
- [ ] Klasör yapısını oluştur (`core/`, `features/`)
- [ ] Theme setup (Material 3, dark/light mode)
- [ ] Navigation setup (go_router)
- **Skills:** `flutter-expert`, `mobile-development`
- **Tahmin:** 12 saat

**Developer 2: Core Utils & Widgets**
- [ ] API client setup (Dio interceptors)
- [ ] Error handling utilities
- [ ] Loading/Error widgets
- [ ] Custom button components
- [ ] Form validators
- **Skills:** `flutter-expert`, `ui-ux-pro-max`
- **Tahmin:** 10 saat

#### Backend Team (2 devs)

**Developer 1: NestJS Setup**
- [ ] NestJS projesi initialize et
- [ ] TypeScript config (strict mode)
- [ ] Clean architecture klasör yapısı
- [ ] Environment config setup
- [ ] JWT authentication module
- **Skills:** `backend-architect`, `nestjs-expert`, `clean-code`
- **Tahmin:** 14 saat

**Developer 2: Database Setup**
- [ ] Prisma schema.prisma yazımı
- [ ] Initial migration oluştur
- [ ] Seed data hazırlama
- [ ] PostgreSQL connection setup
- [ ] Redis connection setup
- **Skills:** `database-architect`, `prisma-expert`, `postgresql`
- **Tahmin:** 12 saat

#### DevOps (1 dev)

- [ ] GitHub repository setup
- [ ] Branch protection rules
- [ ] GitHub Actions CI pipeline (lint, test)
- [ ] Docker Compose setup (PostgreSQL + Redis)
- [ ] Railway/Render deployment config
- [ ] Secret management (environment variables)
- **Skills:** `deployment-engineer`, `docker-expert`, `github-actions-templates`
- **Tahmin:** 16 saat

#### QA (1 tester)

- [ ] Test plan document yazımı
- [ ] Test case şablonları hazırlama
- [ ] Bug tracking sistemi kurulumu (GitHub Issues)
- [ ] Testing environment checklist
- **Skills:** `test-automator`, `test-driven-development`
- **Tahmin:** 8 saat

#### UI/UX Designer (1)

- [ ] User persona tanımları
- [ ] User journey maps
- [ ] Low-fidelity wireframes (15+ ekran)
- [ ] Design system başlangıcı (colors, typography)
- **Skills:** `ui-ux-designer`, `frontend-design`
- **Tahmin:** 20 saat

---

### Sprint 2: Authentication & User Management (H3-4)

#### Mobile Team

**Developer 1: Auth UI**
- [ ] Login screen
- [ ] Register screen (multi-step form)
- [ ] OTP verification screen
- [ ] Profile screen
- [ ] Profile edit screen
- **Skills:** `flutter-expert`, `auth-implementation-patterns`
- **Tahmin:** 16 saat

**Developer 2: Auth Logic**
- [ ] Riverpod auth provider
- [ ] Token storage (secure storage)
- [ ] Auth state management
- [ ] Auto-login logic
- [ ] Logout functionality
- **Skills:** `flutter-expert`, `riverpod`
- **Tahmin:** 12 saat

#### Backend Team

**Developer 1: Auth API**
- [ ] POST /auth/register endpoint
- [ ] POST /auth/login endpoint
- [ ] POST /auth/verify-otp endpoint
- [ ] POST /auth/refresh-token endpoint
- [ ] JWT generation/validation
- [ ] Password hashing (bcrypt)
- **Skills:** `backend-architect`, `auth-implementation-patterns`, `security-auditor`
- **Tahmin:** 14 saat

**Developer 2: User Management**
- [ ] GET /users/me endpoint
- [ ] PUT /users/me endpoint
- [ ] User preferences CRUD
- [ ] File upload (profile photo → Cloudflare R2)
- [ ] SMS OTP integration (Netgsm)
- **Skills:** `backend-architect`, `file-uploads`, `api-security-best-practices`
- **Tahmin:** 14 saat

#### DevOps

- [ ] Cloudflare R2 setup
- [ ] Netgsm API integration test
- [ ] Staging deployment
- **Skills:** `cloud-architect`
- **Tahmin:** 6 saat

#### QA

- [ ] Auth flow test cases
- [ ] Manual testing (registration, login)
- [ ] OTP verification testing
- [ ] Security testing (SQL injection, XSS)
- **Skills:** `test-automator`, `security-auditor`
- **Tahmin:** 10 saat

#### UI/UX Designer

- [ ] High-fidelity mockups (auth screens)
- [ ] Glassmorphism components
- [ ] Interaction animations
- **Skills:** `ui-ux-designer`, `frontend-design`
- **Tahmin:** 12 saat

---

### Sprint 3: Core Trip Features (H5-6)

#### Mobile Team

**Developer 1: Trip UI**
- [ ] Trip search screen (filters)
- [ ] Trip list screen (cards)
- [ ] Trip detail screen
- [ ] Trip creation screen (multi-step)
- **Skills:** `flutter-expert`, `ui-ux-pro-max`
- **Tahmin:** 18 saat

**Developer 2 Map Integration**
- [ ] Yandex Maps integration
- [ ] Route display
- [ ] Location picker
- [ ] Distance calculation
- **Skills:** `flutter-expert`, `maps`
- **Tahmin:** 14 saat

#### Backend Team

**Developer 1: Trip API**
- [ ] GET /trips (search + filters)
- [ ] POST /trips (create trip)
- [ ] GET /trips/:id (trip details)
- [ ] PUT /trips/:id (update trip)
- [ ] DELETE /trips/:id
- **Skills:** `backend-architect`, `database-optimizer`
- **Tahmin:** 16 saat

**Developer 2: Bus Price Scraper**
- [ ] Playwright scraper setup
- [ ] Obilet scraper
- [ ] Enuygun scraper
- [ ] Busbud scraper
- [ ] Cron job setup (daily 02:00)
- [ ] Cache to Redis
- [ ] Fallback logic
- **Skills:** `browser-automation`, `playwright-skill`, `workflow-automation`
- **Tahmin:** 18 saat

#### DevOps

- [ ] Background worker deployment
- [ ] Cron job setup (cron-job.org or Railway)
- [ ] Scraper monitoring setup
- **Skills:** `deployment-engineer`, `observability-engineer`
- **Tahmin:** 8 saat

#### QA

- [ ] Trip creation test cases
- [ ] Search functionality testing
- [ ] Map integration testing
- [ ] Scraper output validation
- **Skills:** `test-automator`, `e2e-testing-patterns`
- **Tahmin:** 12 saat

#### UI/UX Designer

- [ ] Trip screens mockups
- [ ] Map UI design
- [ ] Filter panel design
- **Skills:** `ui-ux-designer`
- **Tahmin:** 10 saat

---

### Sprint 4: Booking & Payment (H7-8)

#### Mobile Team

**Developer 1: Booking UI**
- [ ] Booking screen
- [ ] QR code generation screen
- [ ] QR code scanner screen
- [ ] Booking history screen
- **Skills:** `flutter-expert`, `qr-flutter`, `mobile_scanner`
- **Tahmin:** 14 saat

**Developer 2: Payment Integration**
- [ ] İyzico SDK integration
- [ ] Checkout flow
- [ ] 3D Secure WebView
- [ ] Payment status handling
- [ ] Wallet UI
- **Skills:** `flutter-expert`, `payment-integration`
- **Tahmin:** 16 saat

#### Backend Team

**Developer 1: Booking API**
- [ ] POST /bookings (create booking)
- [ ] GET /bookings (list bookings)
- [ ] POST /bookings/:id/checkin (QR verification)
- [ ] PUT /bookings/:id/cancel
- [ ] Transaction logic (ACID)
- **Skills:** `backend-architect`, `database-architect`
- **Tahmin:** 16 saat

**Developer 2: Payment API**
- [ ] POST /payments/initiate (İyzico integration)
- [ ] POST /payments/webhook (İyzico callback)
- [ ] Wallet balance management
- [ ] Refund logic
- [ ] Commission calculation
- **Skills:** `backend-architect`, `payment-integration`, `stripe-integration`
- **Tahmin:** 18 saat

#### DevOps

- [ ] İyzico webhook setup
- [ ] Payment transaction monitoring
- [ ] Sentry error tracking setup
- **Skills:** `deployment-engineer`, `observability-engineer`
- **Tahmin:** 6 saat

#### QA

- [ ] Booking flow testing
- [ ] Payment testing (sandbox)
- [ ] QR code testing
- [ ] Refund testing
- [ ] Security testing (payment data)
- **Skills:** `test-automator`, `security-auditor`, `pci-compliance`
- **Tahmin:** 14 saat

#### UI/UX Designer

- [ ] Booking screens mockups
- [ ] Payment flow design
- [ ] QR code screens
- **Skills:** `ui-ux-designer`
- **Tahmin:** 8 saat

---

### Sprint 5: Real-Time Features (H9-10)

#### Mobile Team

**Developer 1: Messages UI**
- [ ] Conversation list screen
- [ ] Chat screen
- [ ] Message input widget
- [ ] Unread badge
- **Skills:** `flutter-expert`
- **Tahmin:** 12 saat

**Developer 2: Real-time Logic**
- [ ] Socket.io client setup
- [ ] Message send/receive
- [ ] Typing indicator
- [ ] Read receipts
- [ ] FCM integration
- **Skills:** `flutter-expert`, `socket_io_client`, `firebase_messaging`
- **Tahmin:** 14 saat

#### Backend Team

**Developer 1: WebSocket Gateway**
- [ ] Socket.io setup
- [ ] Message event handlers
- [ ] Room management (per booking)
- [ ] Redis pub/sub
- [ ] Online status tracking
- **Skills:** `backend-architect`, `inngest`, `bullmq-specialist`
- **Tahmin:** 16 saat

**Developer 2: Notification System**
- [ ] FCM integration
- [ ] SMS queue (BullMQ)
- [ ] Push notification queue
- [ ] Notification templates
- [ ] Automated pet waiver SMS
- **Skills:** `backend-architect`, `workflow-automation`, `bullmq-specialist`
- **Tahmin:** 14 saat

#### DevOps

- [ ] Redis scaling (Upstash)
- [ ] FCM setup
- [ ] WebSocket load testing
- **Skills:** `deployment-engineer`
- **Tahmin:** 6 saat

#### QA

- [ ] Real-time message testing
- [ ] Push notification testing
- [ ] SMS testing
- [ ] Load testing (concurrent users)
- **Skills:** `test-automator`, `performance-engineer`
- **Tahmin:** 10 saat

#### UI/UX Designer

- [ ] Chat UI design
- [ ] Notification design
- **Skills:** `ui-ux-designer`
- **Tahmin:** 6 saat

---

### Sprint 6: Automation & Background Jobs (H11-12)

#### Mobile Team

**Developer 1: Profile Features**
- [ ] Achievements screen
- [ ] Statistics screen (savings, CO2)
- [ ] Referral screen
- [ ] Badge display
- **Skills:** `flutter-expert`, `gamification`
- **Tahmin:** 10 saat

**Developer 2: Settings & Support**
- [ ] Settings screen
- [ ] Support ticket screen
- [ ] FAQ screen
- [ ] Women-only mode toggle
- **Skills:** `flutter-expert`
- **Tahmin:** 8 saat

#### Backend Team

**Developer 1: Automation Workers**
- [ ] Daily scraper job (bus prices)
- [ ] Automatic waiver SMS job
- [ ] Achievement calculation job
- [ ] Review reminder job
- **Skills:** `backend-architect`, `workflow-automation`, `inngest`
- **Tahmin:** 14 saat

**Developer 2: Gamification API**
- [ ] POST /achievements (earn achievement)
- [ ] GET /achievements (user achievements)
- [ ] GET /stats (user statistics)
- [ ] POST /referrals (referral code validation)
- **Skills:** `backend-architect`
- **Tahmin:** 10 saat

#### DevOps

- [ ] Background job monitoring
- [ ] Cron health checks
- [ ] Grafana dashboards
- **Skills:** `observability-engineer`, `grafana-dashboards`
- **Tahmin:** 8 saat

#### QA

- [ ] Automation testing
- [ ] Scraper validation
- [ ] Waiver SMS testing
- [ ] Gamification testing
- **Skills:** `test-automator`
- **Tahmin:** 8 saat

#### UI/UX Designer

- [ ] Gamification UI
- [ ] Support screens
- **Skills:** `ui-ux-designer`
- **Tahmin:** 6 saat

---

### Sprint 7: Testing & Quality (H13-14)

#### Mobile Team

- [ ] Unit tests (Riverpod providers)
- [ ] Widget tests (UI components)
- [ ] Integration tests (E2E flows)
- [ ] Bug fixes
- **Skills:** `flutter-expert`, `test-driven-development`, `testing-patterns`
- **Tahmin:** 20 saat (per dev)

#### Backend Team

- [ ] Unit tests (services, repositories)
- [ ] Integration tests (API endpoints)
- [ ] E2E tests (full user flows)
- [ ] Performance optimization
- [ ] Bug fixes
- **Skills:** `backend-architect`, `test-driven-development`, `testing-patterns`
- **Tahmin:** 20 saat (per dev)

#### DevOps

- [ ] Load testing (k6)
- [ ] Security audit (OWASP ZAP)
- [ ] Penetration testing
- [ ] Performance monitoring
- **Skills:** `security-auditor`, `performance-engineer`
- **Tahmin:** 16 saat

#### QA

- [ ] Regression testing (full app)
- [ ] Cross-device testing (iOS + Android)
- [ ] Usability testing
- [ ] Security testing
- [ ] Bug report triage
- **Skills:** `test-automator`, `e2e-testing-patterns`
- **Tahmin:** 30 saat

#### UI/UX Designer

- [ ] UI polish
- [ ] Accessibility review
- [ ] Animation refinement
- **Skills:** `ui-ux-designer`, `accessibility-compliance-accessibility-audit`
- **Tahmin:** 10 saat

---

### Sprint 8: Beta Launch (H15-16)

#### Mobile Team

- [ ] App Store assets (screenshots, description)
- [ ] iOS build (TestFlight)
- [ ] Android build (Google Play Beta)
- [ ] Bug fixes from beta feedback
- **Skills:** `flutter-expert`, `ios-developer`, `app-store-optimization`
- **Tahmin:** 16 saat (per dev)

#### Backend Team

- [ ] Production database migration
- [ ] API documentation (OpenAPI)
- [ ] Rate limiting tuning
- [ ] Performance optimization
- **Skills:** `backend-architect`, `api-documenter`
- **Tahmin:** 12 saat (per dev)

#### DevOps

- [ ] Production deployment (blue-green)
- [ ] Monitoring setup (Sentry, Grafana)
- [ ] Alerting setup (PagerDuty/Slack)
- [ ] Backup strategy
- [ ] Runbook yazımı
- **Skills:** `deployment-engineer`, `observability-engineer`, `incident-responder`
- **Tahmin:** 20 saat

#### QA

- [ ] Beta testing coordination
- [ ] Feedback collection
- [ ] Critical bug prioritization
- [ ] Smoke testing (production)
- **Skills:** `test-automator`
- **Tahmin:** 20 saat

#### UI/UX Designer

- [ ] Marketing materials
- [ ] Onboarding flow optimization
- [ ] Launch assets
- **Skills:** `ui-ux-designer`, `content-creator`
- **Tahmin:** 12 saat

---

## 📊 Toplam Efor Tahmini (Sprint Bazlı)

| Sprint | Mobile (2) | Backend (2) | DevOps (1) | QA (1) | UI/UX (1) | **Toplam** |
|--------|-----------|-------------|-----------|--------|----------|-----------|
| S1     | 44h       | 52h         | 16h       | 8h     | 20h      | **140h**  |
| S2     | 56h       | 56h         | 6h        | 10h    | 12h      | **140h**  |
| S3     | 64h       | 68h         | 8h        | 12h    | 10h      | **162h**  |
| S4     | 60h       | 68h         | 6h        | 14h    | 8h       | **156h**  |
| S5     | 52h       | 60h         | 6h        | 10h    | 6h       | **134h**  |
| S6     | 36h       | 48h         | 8h        | 8h     | 6h       | **106h**  |
| S7     | 40h       | 40h         | 16h       | 30h    | 10h      | **136h**  |
| S8     | 32h       | 24h         | 20h       | 20h    | 12h      | **108h**  |
| **TOPLAM** | **384h** | **416h** | **86h** | **112h** | **84h** | **1082h** |

**Tahmini Süre:**
- 7 kişi × 40 saat/hafta = 280 saat/hafta
- 1082 saat ÷ 280 saat/hafta ≈ **4 hafta (1 ay) pure development time**
- Gerçek süre (toplantılar, review, beklemeler): **12-14 hafta (3-3.5 ay)**

---

## 🎯 Skill Mapping (Kişi Başına)

### Mobile Developer 1
**Kullanacağı Skills:**
- `flutter-expert` (primary)
- `ui-ux-pro-max`
- `auth-implementation-patterns`
- `test-driven-development`
- `ios-developer`

### Mobile Developer 2
**Kullanacağı Skills:**
- `flutter-expert` (primary)
- `riverpod`
- `socket_io_client`
- `firebase_messaging`
- `payment-integration`

### Backend Developer 1
**Kullanacağı Skills:**
- `backend-architect` (primary)
- `nestjs-expert`
- `auth-implementation-patterns`
- `clean-code`
- `test-driven-development`

### Backend Developer 2
**Kullanacağı Skills:**
- `backend-architect` (primary)
- `database-architect`
- `prisma-expert`
- `browser-automation`
- `workflow-automation`
- `payment-integration`

### DevOps Engineer
**Kullanacağı Skills:**
- `deployment-engineer` (primary)
- `docker-expert`
- `github-actions-templates`
- `observability-engineer`
- `cloud-architect`
- `incident-responder`

### QA Engineer
**Kullanacağı Skills:**
- `test-automator` (primary)
- `test-driven-development`
- `e2e-testing-patterns`
- `security-auditor`
- `performance-engineer`

### UI/UX Designer
**Kullanacağı Skills:**
- `ui-ux-designer` (primary)
- `frontend-design`
- `accessibility-compliance-accessibility-audit`
- `content-creator`
- `app-store-optimization`

---

## 📝 Communication Plan

### Daily Standup (15 dk)
- Ne yaptım?
- Ne yapacağım?
- Blocker var mı?

### Sprint Planning (2 saat)
- Sprint goal belirleme
- Task assignment
- Story point estimation

### Sprint Review (1.5 saat)
- Demo
- Stakeholder feedback
- "Done" kriterleri kontrolü

### Sprint Retrospective (1 saat)
- What went well?
- What didn't?
- Action items

### Weekly Sync
- **Monday:** Sprint planning
- **Friday:** Sprint review + retrospective

---

## ⚠️ Riskler ve Mitigasyon

| Risk | Impact | Olasılık | Mitigasyon |
|------|--------|----------|-----------|
| Scraper siteler değişir | Orta | Yüksek | Fallback + manual override |
| e-Devlet API gecikmesi | Düşük | Yüksek | V1'de manuel verification |
| Ödeme entegrasyonu karmaşıklığı | Yüksek | Orta | İyzico sandbox erken test |
| Platform-specific bug'lar | Orta | Yüksek | Erken cross-platform test |
| Database performansı | Yüksek | Düşük | Index stratejisi + load test |

---

## ✅ Definition of Done (DoD)

Her task tamamlanmış sayılması için:

1. ✅ Kod yazıldı
2. ✅ Unit test yazıldı (%80+ coverage)
3. ✅ Code review yapıldı (1+ dev)
4. ✅ Clean code prensipleri uygulandı
5. ✅ Lint errors yok
6. ✅ Manual test geçti (QA)
7. ✅ README güncellendi (ilgili klasörde)
8. ✅ Branch merge edildi (main)

---

**Son Güncelleme:** 2026-02-03  
**Hazırlayan:** Technical Team + AI Assistant  
**Onay:** Pending
