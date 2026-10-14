-- Moving a multi-service visit shifts several back-to-back bookings of the same artist.
-- Updated one by one they briefly overlap each other, so the no-overlap rule is checked
-- at commit instead (only inside transactions that ask for it with SET CONSTRAINTS).
ALTER TABLE "Booking" DROP CONSTRAINT "booking_no_overlap";
ALTER TABLE "Booking" ADD CONSTRAINT "booking_no_overlap"
  EXCLUDE USING gist (
    "staffId" WITH =,
    tstzrange("startTime", "blockedUntil", '[)') WITH &&
  ) WHERE ("status" NOT IN ('CANCELLED', 'NO_SHOW'))
  DEFERRABLE INITIALLY IMMEDIATE;
