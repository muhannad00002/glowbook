import type { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { clientIp } from "@/lib/http";
import type { Prisma } from "@/generated/prisma/client";

/** Append-only trail of who did what. Never throws — auditing must not break a request. */
export async function audit(input: {
  req?: NextRequest;
  salonId?: string | null;
  userId?: string | null;
  action: string;
  entityType: string;
  entityId?: string | null;
  metadata?: Prisma.InputJsonValue;
}) {
  try {
    await db.auditLog.create({
      data: {
        salonId: input.salonId ?? null,
        userId: input.userId ?? null,
        action: input.action,
        entityType: input.entityType,
        entityId: input.entityId ?? null,
        metadata: input.metadata,
        ip: input.req ? clientIp(input.req) : null,
      },
    });
  } catch (e) {
    console.error("[audit] failed", e);
  }
}
