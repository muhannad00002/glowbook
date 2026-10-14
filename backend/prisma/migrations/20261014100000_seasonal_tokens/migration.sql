-- CreateEnum
CREATE TYPE "TokenStatus" AS ENUM ('PENDING_PAYMENT', 'CONFIRMED', 'ARRIVED', 'COMPLETED', 'CANCELLED', 'NO_SHOW', 'EXPIRED');

-- CreateEnum
CREATE TYPE "PrepayMode" AS ENUM ('FULL', 'FIXED');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "NotificationType" ADD VALUE 'TOKEN_CONFIRMED';
ALTER TYPE "NotificationType" ADD VALUE 'TOKEN_REMINDER_1H';
ALTER TYPE "NotificationType" ADD VALUE 'TOKEN_CANCELLED';

-- AlterTable
ALTER TABLE "Notification" ADD COLUMN     "tokenId" TEXT;

-- CreateTable
CREATE TABLE "SeasonalEvent" (
    "id" TEXT NOT NULL,
    "salonId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "nameAr" TEXT,
    "description" TEXT,
    "descriptionAr" TEXT,
    "startDate" DATE NOT NULL,
    "endDate" DATE NOT NULL,
    "openMinute" INTEGER NOT NULL,
    "closeMinute" INTEGER NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "SeasonalEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SeasonalOffering" (
    "id" TEXT NOT NULL,
    "eventId" TEXT NOT NULL,
    "salonId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "nameAr" TEXT,
    "description" TEXT,
    "tokenMinutes" INTEGER NOT NULL,
    "capacity" INTEGER NOT NULL DEFAULT 1,
    "priceBaisa" INTEGER NOT NULL,
    "prepayMode" "PrepayMode" NOT NULL DEFAULT 'FULL',
    "prepayBaisa" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "SeasonalOffering_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SeasonalToken" (
    "id" TEXT NOT NULL,
    "reference" TEXT NOT NULL,
    "salonId" TEXT NOT NULL,
    "offeringId" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "number" INTEGER NOT NULL,
    "startTime" TIMESTAMPTZ(3) NOT NULL,
    "endTime" TIMESTAMPTZ(3) NOT NULL,
    "status" "TokenStatus" NOT NULL DEFAULT 'PENDING_PAYMENT',
    "priceBaisa" INTEGER NOT NULL,
    "prepayBaisa" INTEGER NOT NULL,
    "paidBaisa" INTEGER NOT NULL DEFAULT 0,
    "holdExpiresAt" TIMESTAMPTZ(3),
    "paymentProvider" TEXT,
    "paymentRef" TEXT,
    "paidAt" TIMESTAMPTZ(3),
    "customerNotes" TEXT,
    "arrivedAt" TIMESTAMPTZ(3),
    "completedAt" TIMESTAMPTZ(3),
    "cancelledAt" TIMESTAMPTZ(3),
    "cancelReason" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "SeasonalToken_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "SeasonalEvent_salonId_endDate_idx" ON "SeasonalEvent"("salonId", "endDate");

-- CreateIndex
CREATE INDEX "SeasonalOffering_eventId_idx" ON "SeasonalOffering"("eventId");

-- CreateIndex
CREATE UNIQUE INDEX "SeasonalToken_reference_key" ON "SeasonalToken"("reference");

-- CreateIndex
CREATE UNIQUE INDEX "SeasonalToken_paymentRef_key" ON "SeasonalToken"("paymentRef");

-- CreateIndex
CREATE INDEX "SeasonalToken_salonId_date_idx" ON "SeasonalToken"("salonId", "date");

-- CreateIndex
CREATE INDEX "SeasonalToken_offeringId_startTime_idx" ON "SeasonalToken"("offeringId", "startTime");

-- CreateIndex
CREATE INDEX "SeasonalToken_status_startTime_idx" ON "SeasonalToken"("status", "startTime");

-- CreateIndex
CREATE INDEX "SeasonalToken_customerId_idx" ON "SeasonalToken"("customerId");

-- AddForeignKey
ALTER TABLE "Notification" ADD CONSTRAINT "Notification_tokenId_fkey" FOREIGN KEY ("tokenId") REFERENCES "SeasonalToken"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SeasonalEvent" ADD CONSTRAINT "SeasonalEvent_salonId_fkey" FOREIGN KEY ("salonId") REFERENCES "Salon"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SeasonalOffering" ADD CONSTRAINT "SeasonalOffering_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "SeasonalEvent"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SeasonalToken" ADD CONSTRAINT "SeasonalToken_salonId_fkey" FOREIGN KEY ("salonId") REFERENCES "Salon"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SeasonalToken" ADD CONSTRAINT "SeasonalToken_offeringId_fkey" FOREIGN KEY ("offeringId") REFERENCES "SeasonalOffering"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SeasonalToken" ADD CONSTRAINT "SeasonalToken_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "Customer"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Hand-written: a token number is unique per offering and day among live tokens only,
-- so an expired or cancelled hold frees its number for the next customer.
CREATE UNIQUE INDEX "SeasonalToken_live_number_key"
  ON "SeasonalToken" ("offeringId", "date", "number")
  WHERE "status" IN ('PENDING_PAYMENT', 'CONFIRMED', 'ARRIVED', 'COMPLETED');

ALTER TABLE "SeasonalEvent"
  ADD CONSTRAINT "SeasonalEvent_window_check" CHECK ("openMinute" >= 0 AND "closeMinute" <= 1440 AND "openMinute" < "closeMinute"),
  ADD CONSTRAINT "SeasonalEvent_dates_check" CHECK ("startDate" <= "endDate");

ALTER TABLE "SeasonalOffering"
  ADD CONSTRAINT "SeasonalOffering_values_check" CHECK ("tokenMinutes" > 0 AND "capacity" > 0 AND "priceBaisa" >= 0 AND "prepayBaisa" >= 0);
