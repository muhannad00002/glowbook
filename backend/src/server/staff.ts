import { db } from "@/lib/db";
import { notFound } from "@/lib/http";

export async function staffDetail(salonId: string, id: string) {
  const s = await db.staff.findFirst({
    where: { id, salonId },
    include: {
      services: { select: { serviceId: true } },
      hours: { orderBy: [{ dayOfWeek: "asc" }, { startMinute: "asc" }] },
      timeOff: { where: { endTime: { gte: new Date() } }, orderBy: { startTime: "asc" } },
      user: { select: { id: true, email: true } },
    },
  });
  if (!s) throw notFound("Staff member not found.");
  const { services, ...rest } = s;
  return { ...rest, serviceIds: services.map((x) => x.serviceId), hasLogin: !!s.userId };
}
