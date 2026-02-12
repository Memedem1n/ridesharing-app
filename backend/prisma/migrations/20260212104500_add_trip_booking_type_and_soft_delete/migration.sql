ALTER TABLE "trips"
ADD COLUMN "booking_type" TEXT NOT NULL DEFAULT 'instant',
ADD COLUMN "deleted_at" TIMESTAMP(3);

UPDATE "trips"
SET "booking_type" = CASE
    WHEN "instant_booking" = true THEN 'instant'
    ELSE 'approval_required'
END;

ALTER TABLE "bookings"
ADD COLUMN "payment_due_at" TIMESTAMP(3);

CREATE INDEX "trips_deleted_at_idx" ON "trips"("deleted_at");
CREATE INDEX "trips_booking_type_idx" ON "trips"("booking_type");
CREATE INDEX "bookings_payment_due_at_idx" ON "bookings"("payment_due_at");
