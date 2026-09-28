import { db } from "@/lib/db";
import { notFound, route } from "@/lib/http";
import { optionalUser } from "@/lib/auth/context";
import { publicName, reviewPublicSelect, salonPublicSelect, serviceSelect, staffPublicSelect } from "@/server/dto";
import { dateColumn, dateColumnToString, localDate } from "@/lib/time";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Public salon profile — powers /salon/:slug. Accepts an id or a slug. */
export const GET = route(async (req, { id }) => {
  const salon = await db.salon.findFirst({
    where: { isPublished: true, ...(UUID_RE.test(id) ? { id } : { slug: id.toLowerCase() }) },
    select: {
      ...salonPublicSelect,
      workingHours: { select: { dayOfWeek: true, openMinute: true, closeMinute: true }, orderBy: { dayOfWeek: "asc" } },
      categories: { select: { id: true, name: true, nameAr: true, sortOrder: true }, orderBy: { sortOrder: "asc" } },
      services: {
        where: { isActive: true, deletedAt: null },
        select: { ...serviceSelect, staff: { select: { staffId: true } } },
        orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
      },
      staff: { where: { isActive: true }, select: staffPublicSelect, orderBy: { sortOrder: "asc" } },
    },
  });
  if (!salon) throw notFound("Salon not found.");

  const today = localDate(new Date(), salon.timezone);
  const [reviews, holidays, user] = await Promise.all([
    db.review.findMany({
      where: { salonId: salon.id, isPublished: true },
      select: reviewPublicSelect,
      orderBy: { createdAt: "desc" },
      take: 6,
    }),
    db.salonHoliday.findMany({
      where: { salonId: salon.id, date: { gte: dateColumn(today) } },
      orderBy: { date: "asc" },
      take: 10,
    }),
    optionalUser(req),
  ]);
  const isFavorite = user
    ? !!(await db.favorite.findUnique({ where: { userId_salonId: { userId: user.id, salonId: salon.id } } }))
    : false;

  return {
    ...salon,
    services: salon.services.map(({ staff, ...s }) => ({ ...s, staffIds: staff.map((x) => x.staffId) })),
    reviews: reviews.map((r) => ({ ...r, customer: { name: publicName(r.customer.name) } })),
    upcomingClosures: holidays.map((h) => ({ ...h, date: dateColumnToString(h.date) })),
    isFavorite,
  };
});
