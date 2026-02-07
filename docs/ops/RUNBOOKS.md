# Operational Runbooks

## İçindekiler
1. [Deployment Runbook](#deployment-runbook)
2. [Incident Response Runbook](#incident-response-runbook)
3. [Troubleshooting Guide](#troubleshooting-guide)

---

## Deployment Runbook

### Pre-Deployment Checklist

```
[ ] Tüm testler geçti (CI green)
[ ] Code review tamamlandı
[ ] Migration script hazır
[ ] Rollback planı hazır
[ ] Stakeholder'lar bilgilendirildi
```

### Production Deployment Steps

#### 1. Database Migration
```bash
# 1. Backup al
pg_dump $DATABASE_URL > backup_$(date +%Y%m%d_%H%M%S).sql

# 2. Migration çalıştır
npx prisma migrate deploy

# 3. Verify
npx prisma db pull --force
```

#### 2. Backend Deployment (Railway)
```bash
# 1. Git tag oluştur
git tag -a v1.x.x -m "Release v1.x.x"
git push origin v1.x.x

# 2. Railway auto-deploy başlar
# 3. Health check bekle
curl https://api.ridesharing.com/v1/health

# 4. Verify logs
railway logs --service api
```

#### 3. Mobile Deployment
```bash
# iOS (TestFlight → Production)
cd mobile
flutter build ios --release
# Xcode'dan App Store Connect'e upload

# Android (Internal → Production)
flutter build appbundle --release
# Play Console'dan release
```

### Rollback Procedure
```bash
# 1. Önceki tag'e dön
git checkout v1.x.x-previous
git push origin main --force

# 2. Railway redeploy
railway redeploy --service api

# 3. Database rollback (gerekirse)
npx prisma migrate rollback

# 4. Verify
curl https://api.ridesharing.com/v1/health
```

---

## Incident Response Runbook

### Severity Levels

| Level | Tanım | Response Time | Örnek |
|-------|-------|---------------|-------|
| **SEV1** | Kritik - Tüm sistem down | 15 dk | API tamamen çöktü |
| **SEV2** | Yüksek - Önemli feature down | 1 saat | Ödeme çalışmıyor |
| **SEV3** | Orta - Kısmi etki | 4 saat | Mesajlaşma yavaş |
| **SEV4** | Düşük - Minimal etki | 24 saat | UI bug |

### Incident Response Flow

```
1. DETECT → Monitoring alert veya kullanıcı raporı
2. TRIAGE → Severity belirle
3. NOTIFY → İlgili ekibi bilgilendir
4. INVESTIGATE → Root cause ara
5. MITIGATE → Geçici çözüm uygula
6. RESOLVE → Kalıcı fix deploy et
7. POSTMORTEM → Analiz yaz
```

### SEV1 Playbook (Kritik)

```bash
# 1. Status page güncelle
# status.ridesharing.com → "Investigating"

# 2. War room başlat
# Slack: #incident-response

# 3. Quick diagnostics
curl https://api.ridesharing.com/v1/health
railway logs --service api --tail 100

# 4. Database check
psql $DATABASE_URL -c "SELECT 1"

# 5. Redis check
redis-cli -u $REDIS_URL ping

# 6. Gerekirse rollback
railway redeploy --service api --commit <previous>
```

### On-Call Rotation
- **Primary:** Slack bildirim + telefon
- **Secondary:** 15 dk sonra escalate
- **Manager:** 30 dk sonra escalate

---

## Troubleshooting Guide

### API 5xx Errors

**Belirtiler:** 500, 502, 503 hataları

**Diagnostics:**
```bash
# Logs kontrol
railway logs --service api --tail 200 | grep ERROR

# Memory/CPU kontrol
railway metrics --service api

# Database connection pool
psql $DATABASE_URL -c "SELECT count(*) FROM pg_stat_activity"
```

**Çözümler:**
1. Restart: `railway redeploy --service api`
2. Scale: `railway scale --service api --replicas 3`
3. DB pool artır: `DATABASE_URL?pool_size=20`

---

### Slow API Response

**Belirtiler:** Response time > 500ms

**Diagnostics:**
```bash
# Slow queries bul
SELECT query, mean_time 
FROM pg_stat_statements 
ORDER BY mean_time DESC LIMIT 10;

# Redis latency
redis-cli -u $REDIS_URL --latency
```

**Çözümler:**
1. Missing index ekle
2. Query optimize et
3. Cache ekle (Redis)

---

### Payment Failures

**Belirtiler:** İyzico webhook 4xx/5xx

**Diagnostics:**
```bash
# Webhook logs
railway logs --service api | grep "iyzico"

# İyzico dashboard kontrol
# sandbox.iyzipay.com → Transactions
```

**Çözümler:**
1. API key verify
2. Webhook URL doğrula
3. İyzico support iletişim

---

### Scraper Failures

**Belirtiler:** Bus prices güncellenmiyor

**Diagnostics:**
```bash
# Scraper logs
railway logs --service worker | grep "scraper"

# Redis cache kontrol
redis-cli -u $REDIS_URL keys "bus:price:*"
redis-cli -u $REDIS_URL ttl "bus:price:istanbul-ankara"
```

**Çözümler:**
1. Site DOM değişti → Selector güncelle
2. IP blocked → Proxy kullan
3. Fallback: Admin panel'dan manual güncelle

---

### Mobile App Crashes

**Belirtiler:** Sentry crash reports

**Diagnostics:**
```bash
# Sentry dashboard
# sentry.io/organizations/ridesharing/issues/

# Flutter logs
flutter logs
adb logcat | grep -i flutter
```

**Çözümler:**
1. Crash stack trace analiz
2. Hotfix prepare
3. Force update (kritikse)

---

## Contact List

| Role | Kişi | Telefon | Slack |
|------|------|---------|-------|
| Backend Lead | TBD | +90... | @backend-lead |
| Mobile Lead | TBD | +90... | @mobile-lead |
| DevOps | TBD | +90... | @devops |
| İyzico Support | - | - | support@iyzico.com |

---

**Son Güncelleme:** 2026-02-03
