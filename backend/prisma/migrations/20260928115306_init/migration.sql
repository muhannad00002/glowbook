-- btree_gist lets the exclusion constraint below mix "=" (staffId) with "&&" (time ranges).
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- CreateEnum
CREATE TYPE "SalonRole" AS ENUM ('OWNER', 'MANAGER', 'RECEPTIONIST', 'STAFF');

-- CreateEnum
CREATE TYPE "SalonCategory" AS ENUM ('MAKEUP', 'BEAUTY', 'HAIR', 'STUDIO', 'ARTIST');

-- CreateEnum
CREATE TYPE "SubscriptionPlan" AS ENUM ('FREE', 'STARTER', 'PRO');

-- CreateEnum
CREATE TYPE "SubscriptionStatus" AS ENUM ('TRIALING', 'ACTIVE', 'PAST_DUE', 'CANCELLED');

-- CreateEnum
CREATE TYPE "DepositPolicy" AS ENUM ('REFUNDABLE_IN_WINDOW', 'NON_REFUNDABLE');

-- CreateEnum
CREATE TYPE "PaymentRequirement" AS ENUM ('NONE', 'DEPOSIT', 'FULL');

-- CreateEnum
CREATE TYPE "BookingStatus" AS ENUM ('PENDING', 'CONFIRMED', 'ARRIVED', 'IN_SERVICE', 'COMPLETED', 'CANCELLED', 'NO_SHOW');

-- CreateEnum
CREATE TYPE "BookingSource" AS ENUM ('CUSTOMER_APP', 'PUBLIC_PAGE', 'WALK_IN', 'ADMIN');

-- CreateEnum
CREATE TYPE "HistoryKind" AS ENUM ('CREATED', 'STATUS_CHANGE', 'RESCHEDULE', 'NOTE');

-- CreateEnum
CREATE TYPE "PaymentMethod" AS ENUM ('CASH', 'CARD', 'BANK_TRANSFER', 'ONLINE');

-- CreateEnum
CREATE TYPE "PaymentKind" AS ENUM ('DEPOSIT', 'BALANCE', 'FULL', 'CANCELLATION_FEE', 'REFUND');

-- CreateEnum
CREATE TYPE "PaymentStatus" AS ENUM ('PENDING', 'PAID', 'FAILED', 'REFUNDED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "NotificationType" AS ENUM ('BOOKING_CREATED', 'BOOKING_CONFIRMED', 'BOOKING_RESCHEDULED', 'BOOKING_CANCELLED', 'REMINDER_24H', 'REMINDER_3H', 'BOOKING_COMPLETED', 'REVIEW_REQUEST', 'PASSWORD_RESET', 'PHONE_OTP');

-- CreateEnum
CREATE TYPE "NotificationChannel" AS ENUM ('IN_APP', 'PUSH', 'WHATSAPP', 'EMAIL', 'SMS');

-- CreateEnum
CREATE TYPE "NotificationStatus" AS ENUM ('PENDING', 'SENT', 'FAILED', 'SKIPPED');

-- CreateEnum
CREATE TYPE "TimeOffType" AS ENUM ('VACATION', 'SICK', 'DAY_OFF', 'OTHER');

-- CreateEnum
CREATE TYPE "BlockedTimeType" AS ENUM ('LUNCH', 'BREAK', 'PERSONAL', 'MEETING', 'PRIVATE_BOOKING', 'OTHER');

-- CreateEnum
CREATE TYPE "CustomerSource" AS ENUM ('APP', 'PUBLIC_PAGE', 'WALK_IN', 'ADMIN');

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "email" TEXT,
    "phone" TEXT,
    "passwordHash" TEXT,
    "name" TEXT NOT NULL,
    "avatarUrl" TEXT,
    "locale" TEXT NOT NULL DEFAULT 'en',
    "isSuperAdmin" BOOLEAN NOT NULL DEFAULT false,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "emailVerifiedAt" TIMESTAMPTZ(3),
    "phoneVerifiedAt" TIMESTAMPTZ(3),
    "googleSub" TEXT,
    "appleSub" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Session" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMPTZ(3) NOT NULL,
    "revokedAt" TIMESTAMPTZ(3),
    "userAgent" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastUsedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Session_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PasswordResetToken" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMPTZ(3) NOT NULL,
    "usedAt" TIMESTAMPTZ(3),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PasswordResetToken_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "OtpCode" (
    "id" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "codeHash" TEXT NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "expiresAt" TIMESTAMPTZ(3) NOT NULL,
    "consumedAt" TIMESTAMPTZ(3),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "OtpCode_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DeviceToken" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "platform" TEXT NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastSeenAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DeviceToken_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Salon" (
    "id" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "nameAr" TEXT,
    "tagline" TEXT,
    "taglineAr" TEXT,
    "description" TEXT,
    "descriptionAr" TEXT,
    "category" "SalonCategory" NOT NULL DEFAULT 'MAKEUP',
    "phone" TEXT,
    "whatsapp" TEXT,
    "email" TEXT,
    "address" TEXT,
    "addressAr" TEXT,
    "city" TEXT,
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "timezone" TEXT NOT NULL DEFAULT 'Asia/Muscat',
    "currency" TEXT NOT NULL DEFAULT 'OMR',
    "logoUrl" TEXT,
    "coverUrl" TEXT,
    "photos" TEXT[],
    "isPublished" BOOLEAN NOT NULL DEFAULT true,
    "slotIntervalMinutes" INTEGER NOT NULL DEFAULT 15,
    "minNoticeMinutes" INTEGER NOT NULL DEFAULT 60,
    "bookingHorizonDays" INTEGER NOT NULL DEFAULT 60,
    "autoConfirm" BOOLEAN NOT NULL DEFAULT true,
    "cancellationWindowHours" INTEGER NOT NULL DEFAULT 24,
    "lateCancellationFeeBaisa" INTEGER NOT NULL DEFAULT 0,
    "depositPolicy" "DepositPolicy" NOT NULL DEFAULT 'REFUNDABLE_IN_WINDOW',
    "allowCustomerReschedule" BOOLEAN NOT NULL DEFAULT true,
    "notifyInApp" BOOLEAN NOT NULL DEFAULT true,
    "notifyPush" BOOLEAN NOT NULL DEFAULT true,
    "notifyWhatsapp" BOOLEAN NOT NULL DEFAULT false,
    "notifyEmail" BOOLEAN NOT NULL DEFAULT true,
    "notifySms" BOOLEAN NOT NULL DEFAULT false,
    "remind24h" BOOLEAN NOT NULL DEFAULT true,
    "remind3h" BOOLEAN NOT NULL DEFAULT true,
    "reviewRequests" BOOLEAN NOT NULL DEFAULT true,
    "plan" "SubscriptionPlan" NOT NULL DEFAULT 'FREE',
    "subscriptionStatus" "SubscriptionStatus" NOT NULL DEFAULT 'TRIALING',
    "trialEndsAt" TIMESTAMPTZ(3),
    "ratingAvg" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "ratingCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "Salon_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SalonMember" (
    "id" TEXT NOT NULL,
    "salonId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "role" "SalonRole" NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SalonMember_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Staff" (
    "id" TEXT NOT NULL,
    "salonId" TEXT NOT NULL,
    "userId" TEXT,
    "name" TEXT NOT NULL,
    "nameAr" TEXT,
    "title" TEXT,
    "titleAr" TEXT,
    "photoUrl" TEXT,
    "phone" TEXT,
    "email" TEXT,
    "bio" TEXT,
    "color" TEXT NOT NULL DEFAULT '#8E4B61',
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "Staff_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "StaffService" (
    "staffId" TEXT NOT NULL,
    "serviceId" TEXT NOT NULL,
    "salonId" TEXT NOT NULL,

    CONSTRAINT "StaffService_pkey" PRIMARY KEY ("staffId","serviceId")
);

-- CreateTable
CREATE TABLE "ServiceCategory" (
    "id" TEXT NOT NULL,
    "salonId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "nameAr" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ServiceCategory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Service" (
    "id" TEXT NOT NULL,
    "salonId" TEXT NOT NULL,
    "categoryId" TEXT,
    "name" TEXT NOT NULL,
    "nameAr" TEXT,
    "description" TEXT,
    "descriptionAr" TEXT,
    "priceBaisa" INTEGER NOT NULL,
    "durationMinutes" INTEGER NOT NULL,
    "bufferMinutes" INTEGER NOT NULL DEFAULT 0,
    "imageUrl" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "paymentRequirement" "PaymentRequirement" NOT NULL DEFAULT 'NONE',
    "depositBaisa" INTEGER NOT NULL DEFAULT 0,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "deletedAt" TIMESTAMPTZ(3),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "Service_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Customer" (
    "id" TEXT NOT NULL,
    "salonId" TEXT NOT NULL,
    "userId" TEXT,
    "name" TEXT NOT NULL,
    "phone" TEXT,
    "email" TEXT,
    "birthday" DATE,
    "notes" TEXT,
    "preferredStaffId" TEXT,
    "source" "CustomerSource" NOT NULL DEFAULT 'ADMIN',
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "Customer_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Booking" (
    "id" TEXT NOT NULL,
    "reference" TEXT NOT NULL,
    "salonId" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "staffId" TEXT NOT NULL,
    "serviceId" TEXT NOT NULL,
    "startTime" TIMESTAMPTZ(3) NOT NULL,
    "endTime" TIMESTAMPTZ(3) NOT NULL,
    "blockedUntil" TIMESTAMPTZ(3) NOT NULL,
    "status" "BookingStatus" NOT NULL DEFAULT 'PENDING',
    "source" "BookingSource" NOT NULL,
    "priceBaisa" INTEGER NOT NULL,
    "paymentRequirement" "PaymentRequirement" NOT NULL DEFAULT 'NONE',
    "depositBaisa" INTEGER NOT NULL DEFAULT 0,
    "paidBaisa" INTEGER NOT NULL DEFAULT 0,
    "customerNotes" TEXT,
    "internalNotes" TEXT,
    "cancelledAt" TIMESTAMPTZ(3),
    "cancelReason" TEXT,
    "cancelledById" TEXT,
    "cancellationFeeBaisa" INTEGER NOT NULL DEFAULT 0,
    "completedAt" TIMESTAMPTZ(3),
    "createdById" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "Booking_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BookingStatusHistory" (
    "id" TEXT NOT NULL,
    "salonId" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "kind" "HistoryKind" NOT NULL,
    "fromStatus" "BookingStatus",
    "toStatus" "BookingStatus",
    "oldStartTime" TIMESTAMPTZ(3),
    "oldEndTime" TIMESTAMPTZ(3),
    "newStartTime" TIMESTAMPTZ(3),
    "newEndTime" TIMESTAMPTZ(3),
    "oldStaffId" TEXT,
    "newStaffId" TEXT,
    "note" TEXT,
    "changedById" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BookingStatusHistory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Payment" (
    "id" TEXT NOT NULL,
    "salonId" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "amountBaisa" INTEGER NOT NULL,
    "method" "PaymentMethod" NOT NULL,
    "kind" "PaymentKind" NOT NULL,
    "status" "PaymentStatus" NOT NULL DEFAULT 'PENDING',
    "provider" TEXT,
    "providerRef" TEXT,
    "checkoutUrl" TEXT,
    "notes" TEXT,
    "recordedById" TEXT,
    "paidAt" TIMESTAMPTZ(3),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "Payment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Notification" (
    "id" TEXT NOT NULL,
    "salonId" TEXT,
    "bookingId" TEXT,
    "userId" TEXT,
    "customerId" TEXT,
    "type" "NotificationType" NOT NULL,
    "channel" "NotificationChannel" NOT NULL,
    "status" "NotificationStatus" NOT NULL DEFAULT 'PENDING',
    "dedupeKey" TEXT NOT NULL,
    "recipient" TEXT,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "lastError" TEXT,
    "providerMessageId" TEXT,
    "sentAt" TIMESTAMPTZ(3),
    "readAt" TIMESTAMPTZ(3),
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Notification_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NotificationTemplate" (
    "id" TEXT NOT NULL,
    "salonId" TEXT,
    "type" "NotificationType" NOT NULL,
    "channel" "NotificationChannel" NOT NULL,
    "locale" TEXT NOT NULL DEFAULT 'en',
    "subject" TEXT,
    "body" TEXT NOT NULL,
    "whatsappTemplateName" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "NotificationTemplate_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SalonWorkingHour" (
    "id" TEXT NOT NULL,
    "salonId" TEXT NOT NULL,
    "dayOfWeek" INTEGER NOT NULL,
    "openMinute" INTEGER NOT NULL,
    "closeMinute" INTEGER NOT NULL,

    CONSTRAINT "SalonWorkingHour_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "StaffWorkingHour" (
    "id" TEXT NOT NULL,
    "salonId" TEXT NOT NULL,
    "staffId" TEXT NOT NULL,
    "dayOfWeek" INTEGER NOT NULL,
    "startMinute" INTEGER NOT NULL,
    "endMinute" INTEGER NOT NULL,

    CONSTRAINT "StaffWorkingHour_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "StaffTimeOff" (
    "id" TEXT NOT NULL,
    "salonId" TEXT NOT NULL,
    "staffId" TEXT NOT NULL,
    "startTime" TIMESTAMPTZ(3) NOT NULL,
    "endTime" TIMESTAMPTZ(3) NOT NULL,
    "type" "TimeOffType" NOT NULL DEFAULT 'VACATION',
    "reason" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "StaffTimeOff_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SalonHoliday" (
    "id" TEXT NOT NULL,
    "salonId" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "name" TEXT NOT NULL,
    "isClosed" BOOLEAN NOT NULL DEFAULT true,
    "openMinute" INTEGER,
    "closeMinute" INTEGER,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SalonHoliday_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BlockedTime" (
    "id" TEXT NOT NULL,
    "salonId" TEXT NOT NULL,
    "staffId" TEXT,
    "startTime" TIMESTAMPTZ(3) NOT NULL,
    "endTime" TIMESTAMPTZ(3) NOT NULL,
    "type" "BlockedTimeType" NOT NULL DEFAULT 'OTHER',
    "note" TEXT,
    "createdById" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BlockedTime_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Review" (
    "id" TEXT NOT NULL,
    "salonId" TEXT NOT NULL,
    "bookingId" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "userId" TEXT,
    "staffId" TEXT,
    "rating" INTEGER NOT NULL,
    "comment" TEXT,
    "reply" TEXT,
    "repliedAt" TIMESTAMPTZ(3),
    "isPublished" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Review_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Favorite" (
    "userId" TEXT NOT NULL,
    "salonId" TEXT NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Favorite_pkey" PRIMARY KEY ("userId","salonId")
);

-- CreateTable
CREATE TABLE "AuditLog" (
    "id" TEXT NOT NULL,
    "salonId" TEXT,
    "userId" TEXT,
    "action" TEXT NOT NULL,
    "entityType" TEXT NOT NULL,
    "entityId" TEXT,
    "metadata" JSONB,
    "ip" TEXT,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AuditLog_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE UNIQUE INDEX "User_phone_key" ON "User"("phone");

-- CreateIndex
CREATE UNIQUE INDEX "User_googleSub_key" ON "User"("googleSub");

-- CreateIndex
CREATE UNIQUE INDEX "User_appleSub_key" ON "User"("appleSub");

-- CreateIndex
CREATE UNIQUE INDEX "Session_tokenHash_key" ON "Session"("tokenHash");

-- CreateIndex
CREATE INDEX "Session_userId_idx" ON "Session"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "PasswordResetToken_tokenHash_key" ON "PasswordResetToken"("tokenHash");

-- CreateIndex
CREATE INDEX "PasswordResetToken_userId_idx" ON "PasswordResetToken"("userId");

-- CreateIndex
CREATE INDEX "OtpCode_phone_createdAt_idx" ON "OtpCode"("phone", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "DeviceToken_token_key" ON "DeviceToken"("token");

-- CreateIndex
CREATE INDEX "DeviceToken_userId_idx" ON "DeviceToken"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "Salon_slug_key" ON "Salon"("slug");

-- CreateIndex
CREATE INDEX "SalonMember_userId_idx" ON "SalonMember"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "SalonMember_salonId_userId_key" ON "SalonMember"("salonId", "userId");

-- CreateIndex
CREATE UNIQUE INDEX "Staff_userId_key" ON "Staff"("userId");

-- CreateIndex
CREATE INDEX "Staff_salonId_idx" ON "Staff"("salonId");

-- CreateIndex
CREATE INDEX "StaffService_serviceId_idx" ON "StaffService"("serviceId");

-- CreateIndex
CREATE INDEX "StaffService_salonId_idx" ON "StaffService"("salonId");

-- CreateIndex
CREATE INDEX "ServiceCategory_salonId_idx" ON "ServiceCategory"("salonId");

-- CreateIndex
CREATE INDEX "Service_salonId_idx" ON "Service"("salonId");

-- CreateIndex
CREATE INDEX "Service_categoryId_idx" ON "Service"("categoryId");

-- CreateIndex
CREATE INDEX "Customer_salonId_idx" ON "Customer"("salonId");

-- CreateIndex
CREATE INDEX "Customer_phone_idx" ON "Customer"("phone");

-- CreateIndex
CREATE INDEX "Customer_email_idx" ON "Customer"("email");

-- CreateIndex
CREATE UNIQUE INDEX "Customer_salonId_userId_key" ON "Customer"("salonId", "userId");

-- CreateIndex
CREATE UNIQUE INDEX "Customer_salonId_phone_key" ON "Customer"("salonId", "phone");

-- CreateIndex
CREATE UNIQUE INDEX "Booking_reference_key" ON "Booking"("reference");

-- CreateIndex
CREATE INDEX "Booking_salonId_idx" ON "Booking"("salonId");

-- CreateIndex
CREATE INDEX "Booking_staffId_idx" ON "Booking"("staffId");

-- CreateIndex
CREATE INDEX "Booking_customerId_idx" ON "Booking"("customerId");

-- CreateIndex
CREATE INDEX "Booking_startTime_idx" ON "Booking"("startTime");

-- CreateIndex
CREATE INDEX "Booking_status_idx" ON "Booking"("status");

-- CreateIndex
CREATE INDEX "Booking_salonId_startTime_idx" ON "Booking"("salonId", "startTime");

-- CreateIndex
CREATE INDEX "BookingStatusHistory_bookingId_idx" ON "BookingStatusHistory"("bookingId");

-- CreateIndex
CREATE INDEX "BookingStatusHistory_salonId_createdAt_idx" ON "BookingStatusHistory"("salonId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "Payment_providerRef_key" ON "Payment"("providerRef");

-- CreateIndex
CREATE INDEX "Payment_salonId_createdAt_idx" ON "Payment"("salonId", "createdAt");

-- CreateIndex
CREATE INDEX "Payment_bookingId_idx" ON "Payment"("bookingId");

-- CreateIndex
CREATE INDEX "Payment_status_idx" ON "Payment"("status");

-- CreateIndex
CREATE UNIQUE INDEX "Notification_dedupeKey_key" ON "Notification"("dedupeKey");

-- CreateIndex
CREATE INDEX "Notification_salonId_createdAt_idx" ON "Notification"("salonId", "createdAt");

-- CreateIndex
CREATE INDEX "Notification_userId_readAt_idx" ON "Notification"("userId", "readAt");

-- CreateIndex
CREATE INDEX "Notification_status_createdAt_idx" ON "Notification"("status", "createdAt");

-- CreateIndex
CREATE INDEX "Notification_bookingId_idx" ON "Notification"("bookingId");

-- CreateIndex
CREATE UNIQUE INDEX "NotificationTemplate_salonId_type_channel_locale_key" ON "NotificationTemplate"("salonId", "type", "channel", "locale");

-- CreateIndex
CREATE UNIQUE INDEX "SalonWorkingHour_salonId_dayOfWeek_key" ON "SalonWorkingHour"("salonId", "dayOfWeek");

-- CreateIndex
CREATE INDEX "StaffWorkingHour_staffId_dayOfWeek_idx" ON "StaffWorkingHour"("staffId", "dayOfWeek");

-- CreateIndex
CREATE INDEX "StaffWorkingHour_salonId_idx" ON "StaffWorkingHour"("salonId");

-- CreateIndex
CREATE INDEX "StaffTimeOff_staffId_startTime_idx" ON "StaffTimeOff"("staffId", "startTime");

-- CreateIndex
CREATE INDEX "StaffTimeOff_salonId_idx" ON "StaffTimeOff"("salonId");

-- CreateIndex
CREATE UNIQUE INDEX "SalonHoliday_salonId_date_key" ON "SalonHoliday"("salonId", "date");

-- CreateIndex
CREATE INDEX "BlockedTime_salonId_startTime_idx" ON "BlockedTime"("salonId", "startTime");

-- CreateIndex
CREATE INDEX "BlockedTime_staffId_startTime_idx" ON "BlockedTime"("staffId", "startTime");

-- CreateIndex
CREATE UNIQUE INDEX "Review_bookingId_key" ON "Review"("bookingId");

-- CreateIndex
CREATE INDEX "Review_salonId_createdAt_idx" ON "Review"("salonId", "createdAt");

-- CreateIndex
CREATE INDEX "Favorite_salonId_idx" ON "Favorite"("salonId");

-- CreateIndex
CREATE INDEX "AuditLog_salonId_createdAt_idx" ON "AuditLog"("salonId", "createdAt");

-- AddForeignKey
ALTER TABLE "Session" ADD CONSTRAINT "Session_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PasswordResetToken" ADD CONSTRAINT "PasswordResetToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DeviceToken" ADD CONSTRAINT "DeviceToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SalonMember" ADD CONSTRAINT "SalonMember_salonId_fkey" FOREIGN KEY ("salonId") REFERENCES "Salon"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SalonMember" ADD CONSTRAINT "SalonMember_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Staff" ADD CONSTRAINT "Staff_salonId_fkey" FOREIGN KEY ("salonId") REFERENCES "Salon"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Staff" ADD CONSTRAINT "Staff_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StaffService" ADD CONSTRAINT "StaffService_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "Staff"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StaffService" ADD CONSTRAINT "StaffService_serviceId_fkey" FOREIGN KEY ("serviceId") REFERENCES "Service"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StaffService" ADD CONSTRAINT "StaffService_salonId_fkey" FOREIGN KEY ("salonId") REFERENCES "Salon"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ServiceCategory" ADD CONSTRAINT "ServiceCategory_salonId_fkey" FOREIGN KEY ("salonId") REFERENCES "Salon"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Service" ADD CONSTRAINT "Service_salonId_fkey" FOREIGN KEY ("salonId") REFERENCES "Salon"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Service" ADD CONSTRAINT "Service_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "ServiceCategory"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Customer" ADD CONSTRAINT "Customer_salonId_fkey" FOREIGN KEY ("salonId") REFERENCES "Salon"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Customer" ADD CONSTRAINT "Customer_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Customer" ADD CONSTRAINT "Customer_preferredStaffId_fkey" FOREIGN KEY ("preferredStaffId") REFERENCES "Staff"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Booking" ADD CONSTRAINT "Booking_salonId_fkey" FOREIGN KEY ("salonId") REFERENCES "Salon"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Booking" ADD CONSTRAINT "Booking_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "Customer"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Booking" ADD CONSTRAINT "Booking_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "Staff"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Booking" ADD CONSTRAINT "Booking_serviceId_fkey" FOREIGN KEY ("serviceId") REFERENCES "Service"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BookingStatusHistory" ADD CONSTRAINT "BookingStatusHistory_salonId_fkey" FOREIGN KEY ("salonId") REFERENCES "Salon"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BookingStatusHistory" ADD CONSTRAINT "BookingStatusHistory_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Payment" ADD CONSTRAINT "Payment_salonId_fkey" FOREIGN KEY ("salonId") REFERENCES "Salon"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Payment" ADD CONSTRAINT "Payment_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Payment" ADD CONSTRAINT "Payment_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "Customer"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Notification" ADD CONSTRAINT "Notification_salonId_fkey" FOREIGN KEY ("salonId") REFERENCES "Salon"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Notification" ADD CONSTRAINT "Notification_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Notification" ADD CONSTRAINT "Notification_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Notification" ADD CONSTRAINT "Notification_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "Customer"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NotificationTemplate" ADD CONSTRAINT "NotificationTemplate_salonId_fkey" FOREIGN KEY ("salonId") REFERENCES "Salon"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SalonWorkingHour" ADD CONSTRAINT "SalonWorkingHour_salonId_fkey" FOREIGN KEY ("salonId") REFERENCES "Salon"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StaffWorkingHour" ADD CONSTRAINT "StaffWorkingHour_salonId_fkey" FOREIGN KEY ("salonId") REFERENCES "Salon"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StaffWorkingHour" ADD CONSTRAINT "StaffWorkingHour_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "Staff"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StaffTimeOff" ADD CONSTRAINT "StaffTimeOff_salonId_fkey" FOREIGN KEY ("salonId") REFERENCES "Salon"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "StaffTimeOff" ADD CONSTRAINT "StaffTimeOff_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "Staff"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SalonHoliday" ADD CONSTRAINT "SalonHoliday_salonId_fkey" FOREIGN KEY ("salonId") REFERENCES "Salon"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BlockedTime" ADD CONSTRAINT "BlockedTime_salonId_fkey" FOREIGN KEY ("salonId") REFERENCES "Salon"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BlockedTime" ADD CONSTRAINT "BlockedTime_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "Staff"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Review" ADD CONSTRAINT "Review_salonId_fkey" FOREIGN KEY ("salonId") REFERENCES "Salon"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Review" ADD CONSTRAINT "Review_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Review" ADD CONSTRAINT "Review_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "Customer"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Review" ADD CONSTRAINT "Review_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Review" ADD CONSTRAINT "Review_staffId_fkey" FOREIGN KEY ("staffId") REFERENCES "Staff"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Favorite" ADD CONSTRAINT "Favorite_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Favorite" ADD CONSTRAINT "Favorite_salonId_fkey" FOREIGN KEY ("salonId") REFERENCES "Salon"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AuditLog" ADD CONSTRAINT "AuditLog_salonId_fkey" FOREIGN KEY ("salonId") REFERENCES "Salon"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- ---------------------------------------------------------------------------
-- Hand-written integrity rules Prisma can't express.
-- ---------------------------------------------------------------------------

-- THE double-booking guard. Two live bookings for the same staff member can never
-- occupy overlapping [startTime, blockedUntil) ranges, no matter how many API
-- instances race each other. Cancelled / no-show bookings free their slot.
ALTER TABLE "Booking" ADD CONSTRAINT "booking_no_overlap"
  EXCLUDE USING gist (
    "staffId" WITH =,
    tstzrange("startTime", "blockedUntil", '[)') WITH &&
  ) WHERE ("status" NOT IN ('CANCELLED', 'NO_SHOW'));

ALTER TABLE "Booking" ADD CONSTRAINT "booking_time_order"
  CHECK ("endTime" > "startTime" AND "blockedUntil" >= "endTime");
ALTER TABLE "Booking" ADD CONSTRAINT "booking_money_nonnegative"
  CHECK ("priceBaisa" >= 0 AND "depositBaisa" >= 0 AND "paidBaisa" >= 0);

ALTER TABLE "Service" ADD CONSTRAINT "service_sane"
  CHECK ("priceBaisa" >= 0 AND "durationMinutes" > 0 AND "bufferMinutes" >= 0 AND "depositBaisa" >= 0);

ALTER TABLE "Review" ADD CONSTRAINT "review_rating_range" CHECK ("rating" BETWEEN 1 AND 5);

ALTER TABLE "StaffWorkingHour" ADD CONSTRAINT "staff_hours_sane"
  CHECK ("dayOfWeek" BETWEEN 0 AND 6 AND "startMinute" >= 0 AND "endMinute" <= 1440 AND "endMinute" > "startMinute");
ALTER TABLE "SalonWorkingHour" ADD CONSTRAINT "salon_hours_sane"
  CHECK ("dayOfWeek" BETWEEN 0 AND 6 AND "openMinute" >= 0 AND "closeMinute" <= 1440 AND "closeMinute" > "openMinute");
ALTER TABLE "StaffTimeOff" ADD CONSTRAINT "time_off_order" CHECK ("endTime" > "startTime");
ALTER TABLE "BlockedTime" ADD CONSTRAINT "blocked_order" CHECK ("endTime" > "startTime");

-- Platform-default templates have salonId NULL, which a normal unique index treats as distinct.
CREATE UNIQUE INDEX "NotificationTemplate_default_key"
  ON "NotificationTemplate" ("type", "channel", "locale") WHERE "salonId" IS NULL;
