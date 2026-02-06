# Database Entity Relationship Diagram

## ERD Diyagramı

```mermaid
erDiagram
    users ||--o{ verifications : has
    users ||--o{ vehicles : owns
    users ||--o{ trips : creates_as_driver
    users ||--o{ bookings : creates_as_passenger
    users ||--o{ messages : sends
    users ||--o{ reviews : gives
    users ||--o{ reviews : receives
    users ||--o{ support_tickets : creates
    users ||--o{ achievements : earns
    users ||--o{ waivers : accepts
    
    vehicles ||--o{ trips : used_in
    
    trips ||--o{ bookings : has
    
    bookings ||--o{ messages : related_to
    bookings ||--o{ reviews : gets
    bookings ||--o{ waivers : requires
    
    users {
        uuid id PK
        string phone UK
        string email UK
        string password_hash
        string full_name
        date date_of_birth
        enum gender
        string profile_photo_url
        text bio
        decimal rating_avg
        int rating_count
        int total_trips
        jsonb verification_status
        jsonb preferences
        boolean women_only_mode
        timestamp banned_until
        decimal penalty_score
        decimal wallet_balance
        string referral_code UK
        uuid referred_by FK
        timestamp created_at
        timestamp updated_at
    }
    
    verifications {
        uuid id PK
        uuid user_id FK
        enum type
        enum status
        text document_url
        jsonb submission_data
        uuid reviewed_by FK
        timestamp reviewed_at
        text rejection_reason
        timestamp created_at
    }
    
    vehicles {
        uuid id PK
        uuid user_id FK
        string license_plate UK
        string brand
        string model
        int year
        string color
        int seats
        boolean has_ac
        boolean allows_pets
        boolean allows_smoking
        text license_document_url
        boolean verified
        timestamp created_at
    }
    
    trips {
        uuid id PK
        uuid driver_id FK
        uuid vehicle_id FK
        enum status
        enum type
        string departure_city
        string arrival_city
        string departure_address
        string arrival_address
        decimal departure_lat
        decimal departure_lng
        decimal arrival_lat
        decimal arrival_lng
        timestamp departure_time
        timestamp estimated_arrival_time
        int available_seats
        decimal price_per_seat
        boolean allows_pets
        enum pet_location
        boolean allows_cargo
        int max_cargo_weight
        boolean recurring
        jsonb recurring_pattern
        text route_polyline
        decimal distance_km
        jsonb preferences
        boolean women_only
        boolean instant_booking
        timestamp created_at
        timestamp updated_at
    }
    
    bookings {
        uuid id PK
        uuid trip_id FK
        uuid passenger_id FK
        enum status
        int seats
        decimal price_total
        decimal commission_amount
        enum item_type
        jsonb item_details
        string qr_code UK
        timestamp checked_in_at
        enum payment_status
        string payment_id
        timestamp cancellation_time
        decimal cancellation_penalty
        timestamp created_at
        timestamp updated_at
    }
    
    messages {
        uuid id PK
        uuid booking_id FK
        uuid sender_id FK
        uuid receiver_id FK
        text message
        boolean read
        timestamp created_at
    }
    
    reviews {
        uuid id PK
        uuid trip_id FK
        uuid booking_id FK
        uuid reviewer_id FK
        uuid reviewee_id FK
        int rating
        text comment
        jsonb categories
        timestamp created_at
    }
    
    support_tickets {
        uuid id PK
        uuid user_id FK
        uuid trip_id FK
        uuid booking_id FK
        enum type
        enum status
        enum priority
        string subject
        text description
        jsonb attachments
        uuid assigned_to FK
        timestamp created_at
        timestamp updated_at
    }
    
    achievements {
        uuid id PK
        uuid user_id FK
        enum type
        timestamp earned_at
    }
    
    waivers {
        uuid id PK
        uuid booking_id FK
        uuid user_id FK
        enum waiver_type
        text waiver_text
        timestamp accepted_at
        string ip_address
        jsonb device_info
    }
```

## Index Stratejisi

### Users Tablosu
```sql
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_rating ON users(rating_avg DESC);
CREATE INDEX idx_users_referral ON users(referral_code);
```

### Trips Tablosu
```sql
CREATE INDEX idx_trips_route ON trips(departure_city, arrival_city, departure_time);
CREATE INDEX idx_trips_driver ON trips(driver_id, status);
CREATE INDEX idx_trips_status_published ON trips(status) WHERE status = 'published';
CREATE INDEX idx_trips_location_departure ON trips USING GIST(ST_MakePoint(departure_lng, departure_lat));
CREATE INDEX idx_trips_departure_time ON trips(departure_time) WHERE status = 'published';
```

### Bookings Tablosu
```sql
CREATE INDEX idx_bookings_trip ON bookings(trip_id, status);
CREATE INDEX idx_bookings_passenger ON bookings(passenger_id, status);
CREATE INDEX idx_bookings_qr ON bookings(qr_code) WHERE status IN ('confirmed', 'checked_in');
CREATE INDEX idx_bookings_payment ON bookings(payment_status);
```

### Messages Tablosu
```sql
CREATE INDEX idx_messages_booking ON messages(booking_id, created_at DESC);
CREATE INDEX idx_messages_sender ON messages(sender_id, created_at DESC);
CREATE INDEX idx_messages_receiver ON messages(receiver_id, read, created_at DESC);
```

### Reviews Tablosu
```sql
CREATE INDEX idx_reviews_reviewee ON reviews(reviewee_id, created_at DESC);
CREATE INDEX idx_reviews_trip ON reviews(trip_id);
CREATE INDEX idx_reviews_booking ON reviews(booking_id);
```

## Performans Notları

1. **Partial Indexes**: `status = 'published'` gibi filtrelerde partial index kullanıldı
2. **Composite Indexes**: Sık kullanılan query patternleri için composite index
3. **JSONB Indexes**: `preferences` ve diğer JSONB kolonları için GIN indexes
4. **Spatial Indexes**: GPS koordinatları için PostGIS GIST indexes
5. **Text Search**: Full-text search için tsvector column ve GIN index
