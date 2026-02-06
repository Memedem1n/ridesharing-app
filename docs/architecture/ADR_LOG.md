# Architecture Decision Records (ADR)

## ADR Index

1. [ADR-001: Flutter for Mobile Development](#adr-001-flutter-for-mobile-development)
2. [ADR-002: NestJS with Clean Architecture for Backend](#adr-002-nestjs-with-clean-architecture-for-backend)
3. [ADR-003: PostgreSQL with Prisma for Database](#adr-003-postgresql-with-prisma-for-database)
4. [ADR-004: Playwright for Bus Price Scraping](#adr-004-playwright-for-bus-price-scraping)
5. [ADR-005: İyzico for Payment Processing](#adr-005-iyzico-for-payment-processing)

---

## ADR-001: Flutter for Mobile Development

**Status:** Accepted  
**Date:** 2026-02-03  
**Deciders:** Technical Team + flutter-expert skill  
**Consulted:** mobile-developer, react-native-architecture skills

### Context

Paylaşımlı yolculuk uygulamasının hem iOS hem Android platformlarında çalışması gerekiyor. Cross-platform framework seçimi kritik bir karar.

### Decision

**Flutter 3.x + Riverpod 2.x** kullanılacak.

### Rationale

**Flutter Avantajları:**
1. **Tek kod tabanı** → iOS + Android + (ileride) Web
2. **Hot reload** → Hızlı geliştirme döngüsü
3. **Native performans** → Impeller rendering engine
4. **Mature ecosystem** → 40K+ packages
5. **Material 3 + Cupertino** → Platform-native UI

**Riverpod Avantajları:**
1. **Compile-time safety** → Runtime hataları önlenir
2. **Built-in DI** → Test edilebilirlik
3. **Modern provider pattern** → Redux karmaşıklığı yok

### Alternatives Considered

**React Native:**
- ✅ JS/TS ecosystem familiar
- ✅ Hot reload
- ❌ Bridge performance overhead
- ❌ Native module tangling
- ❌ Expo limitasyonları

**Native (Swift/Kotlin):**
- ✅ Maximum performance
- ✅ Platform-specific best practices
- ❌ İki ayrı kod tabanı
- ❌ 2x development time
- ❌ Expensive maintenance

### Consequences

**Positive:**
- ✅ Hızlı geliştirme
- ✅ Tek ekip hem iOS hem Android
- ✅ Consistent UI cross-platform
- ✅ Hot reload productivity boost

**Negative:**
- ⚠️ App size (~15MB base)
- ⚠️ Platform-specific code için plugin gerekir
- ⚠️ Öğrenme eğrisi (Dart)

**Risks:**
- Plugin bağımlılığı (native features için)
- Flutter framework version updates

**Mitigation:**
- Critical features için native plugins hazır
- Stable channel kullanımı
- Comprehensive testing strategy

---

## ADR-002: NestJS with Clean Architecture for Backend

**Status:** Accepted  
**Date:** 2026-02-03  
**Deciders:** Technical Team + backend-architect skill  
**Consulted:** nodejs-backend-patterns, fastapi-pro skills

### Context

Backend için scalable, maintainable, ve test edilebilir bir framework seçilmeli. Microservice'e geçiş de mümkün olmalı.

### Decision

**Node.js 20 LTS + NestJS 10 + Clean Architecture** pattern kullanılacak.

### Rationale

**NestJS Avantajları:**
1. **TypeScript-first** → Type safety
2. **Decorator-based** → Express overhead'i yok
3. **Built-in DI** → Testable code
4. **Modular architecture** → Separation of concerns
5. **Microservice-ready** → Future-proof

**Clean Architecture Avantajları:**
1. **Domain-driven design** → Business logic isolated
2. **Testable** → Pure business logic
3. **Framework-independent** → Easy migration
4. **Clear boundaries** → Maintainable

### Architecture Layers

```
interfaces/ (Controllers, DTOs)
    ↓
application/ (Use cases, Services)
    ↓
domain/ (Entities, Business logic)
    ↓
infrastructure/ (DB, External services)
```

### Alternatives Considered

**FastAPI (Python):**
- ✅ Fast development
- ✅ Auto-generated OpenAPI
- ✅ Async support
- ❌ Ecosystem smaller than Node.js
- ❌ Deployment complexity (ASGI)
- ❌ Team expertise (daha az Python)

**Express.js (Vanilla):**
- ✅ Minimal, flexible
- ✅ Huge ecosystem
- ❌ No structure → maintenance hell
- ❌ Manual DI setup
- ❌ Boilerplate heavy

**Spring Boot (Java):**
- ✅ Enterprise-grade
- ✅ Mature ecosystem
- ❌ Verbose
- ❌ Slower development
- ❌ Memory footprint

### Consequences

**Positive:**
- ✅ Type safety end-to-end
- ✅ Testable business logic
- ✅ Scalable architecture
- ✅ Easy onboarding (decorators self-documenting)

**Negative:**
- ⚠️ Learning curve (DI, decorators)
- ⚠️ More boilerplate than Express

**Risks:**
- NestJS framework lock-in

**Mitigation:**
- Clean Architecture isolates business logic from NestJS
- Domain layer framework-independent

---

## ADR-003: PostgreSQL with Prisma for Database

**Status:** Accepted  
**Date:** 2026-02-03  
**Deciders:** Technical Team + database-architect skill  
**Consulted:** prisma-expert, nosql-expert skills

### Context

Veri modeli ilişkisel (users → trips → bookings). ACID compliance gerekli (payments). Full-text search ve JSON support isteniyor.

### Decision

**PostgreSQL 15 + Prisma 5.x ORM** kullanılacak.

### Rationale

**PostgreSQL Avantajları:**
1. **ACID compliance** → Financial transaction safety
2. **JSONB support** → Flexible data (preferences, metadata)
3. **PostGIS** → GPS coordinates, spatial queries
4. **Full-text search** → Native search without Elasticsearch
5. **Mature** → Battle-tested, 30+ years

**Prisma Avantajları:**
1. **Type-safe** → Auto-generated TypeScript types
2. **Migration management** → Version-controlled schema
3. **Intuitive schema** → Readable, maintainable
4. **Prisma Studio** → GUI for data exploration
5. **N+1 query prevention** → dataloader pattern built-in

### Schema Design Principles

- Normalized design (3NF)
- Selective denormalization (ratings cache)
- Partial indexes (status filters)
- Composite indexes (query patterns)

### Alternatives Considered

**MongoDB:**
- ✅ Schema flexibility
- ✅ JSON-native
- ❌ No ACID multi-document transactions (until 4.0)
- ❌ Join performance (manual aggregation)
- ❌ Data integrity harder to enforce

**MySQL:**
- ✅ Popular, easy hosting
- ✅ ACID compliance
- ❌ JSON support inferior to PostgreSQL
- ❌ No PostGIS equivalent
- ❌ Full-text search weaker

**DynamoDB:**
- ✅ Serverless, auto-scale
- ✅ Low latency
- ❌ Query complexity (LSI/GSI limits)
- ❌ No JOIN operations
- ❌ Cost unpredictable at scale

### Consequences

**Positive:**
- ✅ Type safety (Prisma types)
- ✅ Easy migrations
- ✅ ACID guarantees
- ✅ Spatial queries (PostGIS)

**Negative:**
- ⚠️ Vertical scaling limits (eventual sharding needed)
- ⚠️ Prisma can be slower than raw SQL (complex queries)

**Risks:**
- ORM lock-in
- Scaling beyond single instance

**Mitigation:**
- Complex queries use raw SQL via Prisma.$queryRaw
- Read replicas for scaling reads
- Partitioning strategy prepared

---

## ADR-004: Playwright for Bus Price Scraping

**Status:** Accepted  
**Date:** 2026-02-03  
**Deciders:** Technical Team + browser-automation skill  
**Consulted:** firecrawl-scraper skill

### Context

Otobüs fiyatları günlük otomatik çekilmeli (Obilet, Enuygun, Busbud). Siteler JavaScript-heavy.

### Decision

**Playwright** ile headless browser scraping.

### Rationale

1. **JavaScript execution** → SPA sites desteklenir
2. **Multi-browser** → Chromium, Firefox, WebKit
3. **Auto-wait** → Flaky tests azalır
4. **Stealth mode** → Anti-bot bypass
5. **Parallel execution** → Hızlı scraping

### Implementation

```typescript
// Daily cron job (02:00)
async function scrapeBusPrices(route: string) {
  const browser = await playwright.chromium.launch({ headless: true });
  const page = await browser.newPage();
  
  try {
    await page.goto(`https://www.obilet.com/otobus-bileti/${route}`);
    await page.waitForSelector('.price-cell');
    const price = await page.$eval('.price-cell', el => parseFloat(el.textContent));
    
    await redis.set(`bus:price:${route}`, price, 'EX', 86400); // 24h TTL
    return price;
  } catch (error) {
    logger.error('Scraping failed', { route, error });
    // Fallback to last known price
    return await redis.get(`bus:price:${route}`);
  } finally {
    await browser.close();
  }
}
```

### Alternatives Considered

**Firecrawl API:**
- ✅ Managed service
- ✅ Anti-bot handling
- ❌ Cost ($29+/month)
- ❌ External dependency

**Puppeteer:**
- ✅ Chrome-only (smaller binary)
- ❌ Weaker than Playwright
- ❌ Less features

**Cheerio (Static scraping):**
- ✅ Fast, lightweight
- ❌ No JS execution
- ❌ Won't work on SPAs

### Consequences

**Positive:**
- ✅ Automated daily updates
- ✅ Fallback to cached prices
- ✅ No manual data entry

**Negative:**
- ⚠️ Sites may break scraper (DOM changes)
- ⚠️ Anti-bot detection risk

**Risks:**
- Scrapers require maintenance
- Sites may block IP

**Mitigation:**
- User-agent rotation
- Retry logic with backoff
- Manual override via admin panel
- Monitor scraper health

---

## ADR-005: İyzico for Payment Processing

**Status:** Accepted  
**Date:** 2026-02-03  
**Deciders:** Technical Team + payment-integration skill  
**Consulted:** stripe-integration skill

### Context

Ödeme altyapısı Türkiye'de çalışmalı. PCI-DSS compliant, 3D Secure zorunlu.

### Decision

**İyzico** payment gateway kullanılacak.

### Rationale

1. **Türkiye-focused** → TL support, local banks
2. **PCI-DSS certified** → Security compliance
3. **3D Secure** → Built-in
4. **Komisyon:** %2.49 + ₺0.25/transaction
5. **Developer-friendly:** REST API, sandbox

### Implementation

- Checkout API (single payment)
- Subscription API (recurring payments - V2)
- Webhook integration (async payment confirmation)
- Refund API (cancellation policy)

### Alternatives Considered

**Stripe:**
- ✅ Best-in-class API
- ✅ Global coverage
- ❌ TL support limited
- ❌ Higher fees for Turkish cards
- ❌ Payout delays to Turkey

**PayTR:**
- ✅ Local, TL-native
- ✅ Lower fees (%1.99)
- ❌ Documentation quality
- ❌ API less mature
- ❌ Developer experience weaker

**PayPal:**
- ✅ Global brand trust
- ❌ High fees (%4.4)
- ❌ Not popular in Turkey
- ❌ Complex integration

### Consequences

**Positive:**
- ✅ Local support (Turkish)
- ✅ Fast payouts
- ✅ Competitive fees

**Negative:**
- ⚠️ Turkey-only (international expansion requires dual gateway)

**Risks:**
- Vendor lock-in
- Rate changes

**Mitigation:**
- Payment abstraction layer (future multi-gateway support)
- Contract review annually

---

## ADR Template (Future Decisions)

```markdown
## ADR-XXX: [Decision Title]

**Status:** [Proposed | Accepted | Deprecated | Superseded]  
**Date:** YYYY-MM-DD  
**Deciders:** [Team members]  
**Consulted:** [Skills/experts consulted]

### Context
[Describe the problem and constraints]

### Decision
[What was decided]

### Rationale
[Why this decision was made]

### Alternatives Considered
[Other options and why they were rejected]

### Consequences
**Positive:**
**Negative:**
**Risks:**
**Mitigation:**
```
