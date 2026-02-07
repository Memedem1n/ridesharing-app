# System Architecture Diagrams

## 1. System Context Diagram (C4 Level 1)

```mermaid
C4Context
    title System Context - Paylaşımlı Yolculuk Platformu

    Person(passenger, "Yolcu", "Uygulama kullanıcısı")
    Person(driver, "Sürücü", "Araç sahibi kullanıcı")
    Person(admin, "Admin", "Platform yöneticisi")
    
    System(ridesharing, "Paylaşımlı Yolculuk<br/>Platformu", "İnsan, hayvan, yük ve gıda<br/>taşımacılık sistemi")
    
    System_Ext(payment, "İyzico", "Ödeme işlemleri")
    System_Ext(sms, "Netgsm", "SMS bildirimleri")
    System_Ext(fcm, "Firebase Cloud<br/>Messaging", "Push notifications")
    System_Ext(maps, "OpenStreetMap", "Harita servisleri")
    System_Ext(scraper_target, "Otobüs Bilet<br/>Siteleri", "Fiyat kaynakları")
    System_Ext(edevlet, "e-Devlet", "Kimlik doğrulama<br/>(V2)")
    
    Rel(passenger, ridesharing, "Yolculuk arar, rezervasyon yapar")
    Rel(driver, ridesharing, "Yolculuk ilanı verir")
    Rel(admin, ridesharing, "Yönetir, destek verir")
    
    Rel(ridesharing, payment, "Ödeme işler")
    Rel(ridesharing, sms, "SMS gönderir")
    Rel(ridesharing, fcm, "Push bildirim gönderir")
    Rel(ridesharing, maps, "Harita ve rota bilgisi")
    Rel(ridesharing, scraper_target, "Fiyat bilgisi çeker")
    Rel(ridesharing, edevlet, "Kimlik doğrular (V2)")
```

## 2. Container Diagram (C4 Level 2)

```mermaid
C4Container
    title Container Diagram - Paylaşımlı Yolculuk Platformu

    Person(user, "Kullanıcı", "Yolcu veya Sürücü")
    
    Container(mobile, "Mobile App", "Flutter 3.x", "iOS ve Android native app")
    Container(api, "API Application", "NestJS 10", "REST + WebSocket API")
    Container(worker, "Background Workers", "Node.js + BullMQ", "Async job processing")
    
    ContainerDb(postgres, "PostgreSQL", "PostgreSQL 15", "Kullanıcı, yolculuk, rezervasyon   verileri")
    ContainerDb(redis, "Redis Cache", "Redis 7.x", "Session, cache, pub/sub")
    
    System_Ext(payment, "İyzico")
    System_Ext(sms, "Netgsm")
    System_Ext(fcm, "FCM")
    System_Ext(maps, "OpenStreetMap")
    
    Rel(user, mobile, "Kullanır", "HTTPS")
    Rel(mobile, api, "API çağrıları", "REST/WebSocket")
    
    Rel(api, postgres, "Okur/Yazar", "SQL")
    Rel(api, redis, "Cache/Session", "TCP")
    Rel(worker, postgres, "Okur/Yazar", "SQL")
    Rel(worker, redis, "Job queue", "TCP")
    
    Rel(api, payment, "Ödeme işler", "HTTPS")
    Rel(worker, sms, "SMS gönderir", "HTTPS")
    Rel(api, fcm, "Push bildirim", "HTTPS")
    Rel(mobile, maps, "Harita gösterir", "HTTPS")
```

## 3. Component Diagram - Backend API (C4 Level 3)

```mermaid
C4Component
    title Component Diagram - API Application (NestJS)

    Container(mobile, "Mobile App", "Flutter")
    
    Component(auth, "Auth Module", "NestJS Module", "JWT token yönetimi")
    Component(users, "Users Module", "NestJS Module", "Kullanıcı işlemleri")
    Component(trips, "Trips Module", "NestJS Module", "Yolculuk yönetimi")
    Component(bookings, "Bookings Module", "NestJS Module", "Rezervasyon işlemleri")
    Component(payments, "Payments Module", "NestJS Module", "Ödeme işlemleri")
    Component(messages, "Messages Module", "NestJS Module", "Real-time mesajlaşma")
    Component(gateway, "WebSocket Gateway", "Socket.io", "Real-time connection")
    
    ContainerDb(postgres, "PostgreSQL")
    ContainerDb(redis, "Redis")
    
    Rel(mobile, auth, "Login/Register", "HTTPS")
    Rel(mobile, users, "Profil işlemleri", "HTTPS")
    Rel(mobile, trips, "Yolculuk CRUD", "HTTPS")
    Rel(mobile, bookings, "Rezervasyon", "HTTPS")
    Rel(mobile, payments, "Ödeme", "HTTPS")
    Rel(mobile, gateway, "Mesajlaşma", "WebSocket")
    
    Rel(messages, gateway, "Kullanır")
    
    Rel(auth, postgres, "User auth")
    Rel(users, postgres, "User data")
    Rel(trips, postgres, "Trip data")
    Rel(bookings, postgres, "Booking data")
    Rel(payments, postgres, "Payment data")
    Rel(messages, postgres, "Message data")
    
    Rel(auth, redis, "Session") 
    Rel(gateway, redis, "Pub/Sub")
```

## 4. Deployment Diagram

```mermaid
graph TB
    subgraph Mobile["Mobile Layer"]
        iOS["iOS App<br/>(AppStore)"]
        Android["Android App<br/>(PlayStore)"]
    end
    
    subgraph CDN["CDN Layer"]
        CF["Cloudflare<br/>(DDoS, SSL)"]
    end
    
    subgraph LoadBalancer["Load Balancer"]
        LB["Railway LB<br/>(Auto-scale)"]
    end
    
    subgraph APIServers["API Servers (Railway)"]
        API1["API Instance 1<br/>(NestJS)"]
        API2["API Instance 2<br/>(NestJS)"]
        API3["API Instance N<br/>(Auto-scale)"]
    end
    
    subgraph Workers["Background Workers"]
        Worker1["Worker 1<br/>(Scraper)"]
        Worker2["Worker 2<br/>(SMS/Push)"]
    end
    
    subgraph DataLayer["Data Layer"]
        PG["PostgreSQL<br/>(Supabase)"]
        Redis["Redis<br/>(Upstash)"]
    end
    
    subgraph Storage["File Storage"]
        R2["Cloudflare R2<br/>(Images/Docs)"]
    end
    
    subgraph External["External Services"]
        Iyzico["İyzico"]
        SMS["Netgsm"]
        FCM["Firebase"]
        Maps["OpenStreetMap"]
    end
    
    iOS --> CF
    Android --> CF
    CF --> LB
    LB --> API1
    LB --> API2
    LB --> API3
    
    API1 --> PG
    API2 --> PG
    API3 --> PG
    
    API1 --> Redis
    API2 --> Redis
    API3 --> Redis
    
    Worker1 --> PG
    Worker2 --> PG
    Worker1 --> Redis
    Worker2 --> Redis
    
    API1 --> R2
    API1 --> Iyzico
    Worker2 --> SMS
    Worker2 --> FCM
    iOS --> Maps
    Android --> Maps
```

## 5. Data Flow Diagram - Rezervasyon Süreci

```mermaid
sequenceDiagram
    actor Yolcu
    participant Mobile
    participant API
    participant DB
    participant Redis
    participant İyzico
    participant SMS
    participant FCM
    
    Yolcu->>Mobile: Yolculuk ara
    Mobile->>API: GET /trips?from=istanbul&to=ankara
    API->>Redis: Cache kontrol
    alt Cache hit
        Redis-->>API: Cached results
    else Cache miss
        API->>DB: SELECT trips WHERE...
        DB-->>API: Trip list
        API->>Redis: Cache results (5 min TTL)
    end
    API-->>Mobile: Trip list
    
    Yolcu->>Mobile: Rezervasyon yap
    Mobile->>API: POST /bookings
    API->>DB: BEGIN TRANSACTION
    API->>DB: Check seat availability
    API->>DB: INSERT booking
    API->>DB: UPDATE trip.available_seats
    
    API->>İyzico: Initialize payment
    İyzico-->>API: Payment URL + token
    API->>DB: COMMIT TRANSACTION
    API-->>Mobile: Payment URL
    
    Mobile->>İyzico: 3D Secure payment
    İyzico->>API: Webhook (payment success)
    API->>DB: UPDATE booking.payment_status
    API->>Redis: PUBLISH booking_confirmed
    API->>SMS: Queue SMS job
    API->>FCM: Queue push job
    
    SMS-->>Yolcu: "Rezervasyonunuz onaylandı"
    FCM-->>Mobile: Push notification
    
    alt Hayvan taşımacılığı
        API->>SMS: Feragat metni SMS
        API->>FCM: Feragat onay push
        Yolcu->>Mobile: "Onaylıyorum"
        Mobile->>API: POST /waivers/accept
        API->>DB: INSERT waiver record
    end
```

## 6. Microservices Architecture (Future V2)

```mermaid
graph TB
    subgraph Gateway["API Gateway"]
        Kong["Kong Gateway<br/>(Rate limit, Auth)"]
    end
    
    subgraph Services["Microservices"]
        Auth["Auth Service<br/>(Users, Tokens)"]
        Trip["Trip Service<br/>(Trips, Search)"]
        Booking["Booking Service<br/>(Reservations)"]
        Payment["Payment Service<br/>(Transactions)"]
        Notification["Notification Service<br/>(SMS, Push)"]
        Message["Message Service<br/>(Chat, WebSocket)"]
    end
    
    subgraph EventBus["Event Bus"]
        Kafka["Apache Kafka<br/>(Event Streaming)"]
    end
    
    subgraph Databases["Databases (Per-Service)"]
        AuthDB[(Auth DB)]
        TripDB[(Trip DB)]
        BookingDB[(Booking DB)]
        PaymentDB[(Payment DB)]
        MessageDB[(Message DB)]
    end
    
    Kong --> Auth
    Kong --> Trip
    Kong --> Booking
    Kong --> Payment
    Kong --> Message
    
    Auth --> AuthDB
    Trip --> TripDB
    Booking --> BookingDB
    Payment --> PaymentDB
    Message --> MessageDB
    
    Auth -.->|Event| Kafka
    Trip -.->|Event| Kafka
    Booking -.->|Event| Kafka
    Payment -.->|Event| Kafka
    
    Kafka -.->|Subscribe| Notification
```

## Açıklamalar

### System Context
- Genel sistem sınırları ve dış aktörler
- Ana iletişim kanalları

### Container Diagram
- Fiziksel deployment birimleri
- Mobile app, API, Workers ayrımı
- Database ve cache katmanları

### Component Diagram
- Backend içindeki modüller
- NestJS module yapısı
- Her modülün sorumluluğu

### Deployment Diagram
- Production ortamı
- Auto-scaling stratejisi
- CDN ve load balancer
- External service bağlantıları

### Data Flow
- Rezervasyon sürecinin detaylı akışı
- Cache stratejisi
- Payment flow
- Notification sistemi

### Microservices (V2)
- Gelecek versiyonda microservice dönüşümü
- Event-driven architecture
- Database per service pattern
