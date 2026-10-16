-- CreateTable
CREATE TABLE "MediaFile" (
    "id" TEXT NOT NULL,
    "salonId" TEXT NOT NULL,
    "contentType" TEXT NOT NULL,
    "bytes" BYTEA NOT NULL,
    "width" INTEGER NOT NULL,
    "height" INTEGER NOT NULL,
    "createdAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MediaFile_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "MediaFile_salonId_idx" ON "MediaFile"("salonId");

-- AddForeignKey
ALTER TABLE "MediaFile" ADD CONSTRAINT "MediaFile_salonId_fkey" FOREIGN KEY ("salonId") REFERENCES "Salon"("id") ON DELETE CASCADE ON UPDATE CASCADE;
