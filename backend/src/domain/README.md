# Domain Layer

Pure business logic, **framework-agnostic**.

## 📁 Structure

```
domain/
├─ entities/         # Domain entities
├─ repositories/     # Repository interfaces
└─ use-cases/        # Business use cases
```

## 📜 Rules

1. ❌ NO framework imports (NestJS, Prisma, etc.)
2. ❌ NO external dependencies
3. ✅ Pure TypeScript only
4. ✅ Fully testable without mocks

## 🎯 Entities

Domain entities represent core business objects:

- `User` - Platform user (driver/passenger)
- `Vehicle` - User's registered vehicle
- `Trip` - Published trip
- `Booking` - Trip reservation
- `Review` - User rating/review
- `Message` - Chat message

## 🔄 Use Cases

Business operations:

- `CreateTrip` - Publish a new trip
- `BookTrip` - Reserve seat(s)
- `ProcessPayment` - Handle payment
- `VerifyUser` - Identity verification
