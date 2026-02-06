# Flutter SDK Kurulumu

## 📥 Manuel Kurulum (Önerilen)

### 1️⃣ Flutter SDK İndir
https://docs.flutter.dev/get-started/install/windows

Flutter Stable (3.24.5+):
https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip

### 2️⃣ Klasöre Çıkart
```powershell
Expand-Archive -Path "$env:USERPROFILE\Downloads\flutter_windows_*-stable.zip" -DestinationPath C:\
```

### 3️⃣ PATH'e Ekle
System Environment Variables > Path > Edit > New:
```
C:\flutter\bin
```

### 4️⃣ Doğrula
```bash
flutter doctor
```

---

## 🚀 Hızlı Test (Backend Hazır)

Backend çalışıyor: **http://localhost:3000**

### API Endpoints Test
```bash
# Health Check
curl http://localhost:3000/v1/health

# Swagger Docs
http://localhost:3000/api/docs
```

### Flutter Deps Yükle (Flutter kurulunca)
```bash
cd mobile
flutter pub get
flutter run -d chrome
```

---

## ✅ Tamamlanan İşler

### Backend
- ✅ SQLite database (dev.db)
- ✅ Prisma schema & migrations
- ✅ Auth, Trips, Bookings, Messages servisleri
- ✅ Swagger API docs
- ✅ JWT auth + refresh tokens

### Flutter (API Layer)
- ✅ `api_client.dart` - Dio HTTP client + Auth interceptor
- ✅ `auth_provider.dart` - Login, register, logout state
- ✅ `trip_provider.dart` - Arama, popüler güzergahlar
- ✅ `booking_provider.dart` - Rezervasyon, onayla/reddet
- ✅ Models: User, Trip, Booking
- ✅ Repositories: Auth, Trips, Bookings
- ✅ Screens: Login, Register, My Reservations, Driver Requests
- ✅ Router: 5-tab navigation, auth redirect

---

## 📝 Sonraki Adımlar

1. **Flutter SDK Kur** (yukarıdaki talimatlar)
2. **Test Et**:
   ```bash
   cd c:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app\mobile
   flutter pub get
   flutter doctor
   ```
3. **Çalıştır**:
   ```bash
   flutter run -d chrome  # Web'de test
   # veya
   flutter run -d windows  # Windows app
   ```

---

## 🔌 API Entegrasyonu

Backend URL: `http://localhost:3000/v1`

### Login Test
```bash
POST http://localhost:3000/v1/auth/register
{
  "phone": "+905551234567",
  "email": "test@example.com",
  "password": "Test123!",
  "fullName": "Test User"
}
```

Flutter'dan otomatik bağlanacak (`api_client.dart`):
```dart
const String baseUrl = 'http://localhost:3000/v1';
```
