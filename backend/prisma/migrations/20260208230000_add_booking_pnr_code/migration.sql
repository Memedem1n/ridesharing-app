ALTER TABLE "bookings"
ADD COLUMN "pnr_code" TEXT;

CREATE UNIQUE INDEX "bookings_pnr_code_key"
ON "bookings"("pnr_code");
