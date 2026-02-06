-- RedefineTables
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_users" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "phone" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "password_hash" TEXT NOT NULL,
    "full_name" TEXT NOT NULL,
    "date_of_birth" DATETIME,
    "gender" TEXT,
    "profile_photo_url" TEXT,
    "bio" TEXT,
    "rating_avg" REAL NOT NULL DEFAULT 0,
    "rating_count" INTEGER NOT NULL DEFAULT 0,
    "total_trips" INTEGER NOT NULL DEFAULT 0,
    "identity_status" TEXT NOT NULL DEFAULT 'pending',
    "license_status" TEXT NOT NULL DEFAULT 'pending',
    "identity_document_url" TEXT,
    "license_document_url" TEXT,
    "criminal_record_document_url" TEXT,
    "criminal_record_status" TEXT NOT NULL DEFAULT 'none',
    "verified" BOOLEAN NOT NULL DEFAULT false,
    "preferences" TEXT NOT NULL DEFAULT '{}',
    "women_only_mode" BOOLEAN NOT NULL DEFAULT false,
    "banned_until" DATETIME,
    "penalty_score" REAL NOT NULL DEFAULT 0,
    "wallet_balance" REAL NOT NULL DEFAULT 0,
    "referral_code" TEXT NOT NULL,
    "referred_by" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL
);
INSERT INTO "new_users" ("banned_until", "bio", "created_at", "date_of_birth", "email", "full_name", "gender", "id", "identity_document_url", "identity_status", "license_document_url", "license_status", "password_hash", "penalty_score", "phone", "preferences", "profile_photo_url", "rating_avg", "rating_count", "referral_code", "referred_by", "total_trips", "updated_at", "verified", "wallet_balance", "women_only_mode") SELECT "banned_until", "bio", "created_at", "date_of_birth", "email", "full_name", "gender", "id", "identity_document_url", "identity_status", "license_document_url", "license_status", "password_hash", "penalty_score", "phone", "preferences", "profile_photo_url", "rating_avg", "rating_count", "referral_code", "referred_by", "total_trips", "updated_at", "verified", "wallet_balance", "women_only_mode" FROM "users";
DROP TABLE "users";
ALTER TABLE "new_users" RENAME TO "users";
CREATE UNIQUE INDEX "users_phone_key" ON "users"("phone");
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");
CREATE UNIQUE INDEX "users_referral_code_key" ON "users"("referral_code");
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;
