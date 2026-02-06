# ERD (Entity Relationship Diagram)

This is a textual ERD summary. See `backend/prisma/schema.prisma` for the source of truth.

## Entities
- User
- Vehicle
- Trip
- Booking
- Message
- Review

## Key Relationships
- User 1..* Vehicle
- User 1..* Trip (as driver)
- User 1..* Booking (as passenger)
- Trip 1..* Booking
- Booking 1..* Message
- Booking 1..* Review

