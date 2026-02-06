# Mobile App

Flutter 3.x + Riverpod + Clean Architecture

## 🏗️ Architecture

```
lib/
├─ core/                 # Shared utilities & Providers
│  ├─ constants/         # App constants
│  ├─ router/            # GoRouter configuration
│  ├─ providers/         # Riverpod global providers
│  ├─ networking/        # Dio client & Interceptors
│  └─ widgets/           # Shared widgets (Glassmorphism, Maps)
└─ features/             # Feature modules
   ├─ auth/              # Login, Register
   ├─ home/              # Map View, Main Dashboard
   ├─ trips/             # Create Trip, Trip Details
   ├─ bookings/          # Reservations, QR Code, Scanner
   ├─ messages/          # Chat Screen
   ├─ profile/           # User Profile, Document Upload
   ├─ vehicles/          # Vehicle Management
   └─ reviews/           # Driver Rating
```

## ✨ Screens Implemented

### 1. Authentication
- Login Screen (JWT)
- Register Screen (Form Validation)

### 2. Home & Map
- Interactive Map (OpenStreetMap / Flutter Map)
- Search Box overlay
- Popular Routes

### 3. Trip Management
- **Create Trip Screen**: People, Pets, Cargo, Food options
- **Trip Detail Screen**: Route info, driver profile, booking button

### 4. Bookings & Boarding
- **My Reservations**: List past/active bookings
- **Boarding QR Screen**: Digital ticket with QR Generator
- **QR Scanner Screen**: For drivers to scan passenger codes

### 5. Profile & Verification
- **Verification Screen**: Upload ID, License, Criminal Record
- **Vehicle Verification Screen**: Upload vehicle registration

### 6. Messaging
- Real-time Chat Screen (Socket.io)
```

## 🚀 Quick Start

```bash
# Install dependencies
flutter pub get

# Run app (debug)
flutter run

# Run app (release)
flutter run --release

# Build APK
flutter build apk

# Build iOS
flutter build ios
```

## 📝 Scripts

| Command | Description |
|---------|-------------|
| `flutter pub get` | Install dependencies |
| `flutter run` | Run app in debug mode |
| `flutter test` | Run unit tests |
| `flutter analyze` | Run static analysis |
| `flutter build apk` | Build Android APK |
| `flutter build ios` | Build iOS app |

## 🔧 Configuration

### Environment
- Development: `.env.development`
- Production: `.env.production`

### API Base URLs
- Dev: `http://localhost:3000/v1`
- Prod: `https://api.ridesharing.com/v1`

## 📱 Supported Platforms

- Android 6.0+ (API 23+)
- iOS 12.0+

## 🎨 Design System

- **Colors**: See `lib/core/theme/colors.dart`
- **Typography**: Inter font family
- **Components**: See `lib/core/widgets/`
