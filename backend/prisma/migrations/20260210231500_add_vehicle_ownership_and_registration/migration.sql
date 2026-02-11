ALTER TABLE "vehicles"
ADD COLUMN "registration_number" TEXT,
ADD COLUMN "ownership_type" TEXT NOT NULL DEFAULT 'self',
ADD COLUMN "owner_full_name" TEXT,
ADD COLUMN "owner_relation" TEXT;

UPDATE "vehicles"
SET "registration_number" = "license_plate"
WHERE "registration_number" IS NULL;

ALTER TABLE "vehicles"
ALTER COLUMN "registration_number" SET NOT NULL;

CREATE UNIQUE INDEX "vehicles_registration_number_key" ON "vehicles"("registration_number");
