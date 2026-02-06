# Backend API

NestJS 10 + TypeScript + Clean Architecture

## 🏗️ Architecture

```
src/
├─ domain/           # Business logic (framework-agnostic)
├─ application/      # Application services
│  ├─ services/      # Auth, Trip, Booking, Message, Verification
│  ├─ dto/           # Data transfer objects
│  └─ validators/    # Input validation
├─ infrastructure/   # External dependencies
│  ├─ database/      # Prisma repositories (SQLite/PostgreSQL)
│  ├─ cache/         # Redis (Planned)
│  └─ websockets/    # Socket.io Gateway
└─ interfaces/       # API layer
   ├─ http/          # REST controllers
   │  ├─ auth/       # Login/Register
   │  ├─ trips/      # Trip Management
   │  ├─ bookings/   # Booking & QR
   │  ├─ messages/   # Chat History
   │  ├─ verification/ # Document Upload
   │  └─ vehicles/   # Vehicle Management
   └─ websocket/     # Real-time Chat Gateway
```

## ✨ Features Implemented

### 1. Authentication (`/auth`)
- Login/Register with JWT
- Password hashing (Argon2)
- Profile management

### 2. Trip Management (`/trips`)
- Create trips (People, Pets, Cargo, Food)
- Search & Filter trips
- Trip Details

### 3. Bookings (`/bookings`)
- Reserve seats
- Driver approval flow
- **QR Code Verification** (Boarding Pass)

### 4. Messaging (`/messages`)
- Real-time WebSocket Chat (Socket.io)
- Chat History per booking

### 5. Verification (`/verification`)
- **Identity & License Upload**
- **Criminal Record Upload**
- Vehicle Registration Verification

### 6. Vehicles (`/vehicles`)
- CRUD operations for vehicles
- Registration status tracking

## 🚀 Quick Start

```bash
# Install dependencies
npm install

# Copy environment file
cp .env.example .env

# Start Docker services (PostgreSQL + Redis)
docker-compose up -d

# Run database migrations
npm run db:migrate

# Seed database (optional)
npm run db:seed

# Start development server
npm run dev
```

## 📝 Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start development server with hot reload |
| `npm run build` | Build for production |
| `npm run start` | Start production server |
| `npm run lint` | Run ESLint |
| `npm run type-check` | Run TypeScript type checking |
| `npm test` | Run unit tests |
| `npm run test:e2e` | Run E2E tests |
| `npm run db:migrate` | Run database migrations |
| `npm run db:seed` | Seed database |
| `npm run db:studio` | Open Prisma Studio |

## 🔧 Environment Variables

See `.env.example` for all required environment variables.

## 📚 API Documentation

After starting the server, visit:
- Swagger UI: `http://localhost:3000/api/docs`
- OpenAPI JSON: `http://localhost:3000/api/docs-json`
