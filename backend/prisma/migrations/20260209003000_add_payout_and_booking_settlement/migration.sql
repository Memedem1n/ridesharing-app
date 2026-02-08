ALTER TABLE "users"
ADD COLUMN "payout_iban_masked" TEXT,
ADD COLUMN "payout_iban_hash" TEXT,
ADD COLUMN "payout_account_holder_name" TEXT,
ADD COLUMN "payout_provider_account_id" TEXT,
ADD COLUMN "payout_verification_status" TEXT NOT NULL DEFAULT 'none',
ADD COLUMN "payout_verified_at" TIMESTAMP(3),
ADD COLUMN "payout_blocked_until" TIMESTAMP(3),
ADD COLUMN "payout_risk_level" TEXT NOT NULL DEFAULT 'low',
ADD COLUMN "payout_updated_at" TIMESTAMP(3);

ALTER TABLE "bookings"
ADD COLUMN "accepted_at" TIMESTAMP(3),
ADD COLUMN "paid_at" TIMESTAMP(3),
ADD COLUMN "completed_at" TIMESTAMP(3),
ADD COLUMN "completion_source" TEXT,
ADD COLUMN "dispute_status" TEXT NOT NULL DEFAULT 'none',
ADD COLUMN "disputed_at" TIMESTAMP(3),
ADD COLUMN "dispute_reason" TEXT,
ADD COLUMN "dispute_deadline_at" TIMESTAMP(3),
ADD COLUMN "payout_10_released_at" TIMESTAMP(3),
ADD COLUMN "payout_90_released_at" TIMESTAMP(3),
ADD COLUMN "payout_hold_reason" TEXT;

CREATE TABLE "payout_ledgers" (
    "id" TEXT NOT NULL,
    "booking_id" TEXT NOT NULL,
    "driver_id" TEXT NOT NULL,
    "gross_amount" DOUBLE PRECISION NOT NULL,
    "commission_amount" DOUBLE PRECISION NOT NULL,
    "driver_net_amount" DOUBLE PRECISION NOT NULL,
    "release_10_amount" DOUBLE PRECISION NOT NULL,
    "release_90_amount" DOUBLE PRECISION NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "stage_10_released_at" TIMESTAMP(3),
    "stage_90_released_at" TIMESTAMP(3),
    "hold_reason" TEXT,
    "last_error" TEXT,
    "provider_transfer_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "payout_ledgers_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "payout_ledgers_booking_id_key" ON "payout_ledgers"("booking_id");

ALTER TABLE "payout_ledgers"
ADD CONSTRAINT "payout_ledgers_booking_id_fkey"
FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "payout_ledgers"
ADD CONSTRAINT "payout_ledgers_driver_id_fkey"
FOREIGN KEY ("driver_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
