// End-to-end API smoke test against a running server with the demo seed loaded.
//   node tests/api-smoke.mjs [baseUrl]
// Exercises auth, tenant isolation, availability, the booking engine (incl. a
// concurrent double-booking race), cancellation policy, deposits, cron and reports.
import "dotenv/config";
const BASE = process.argv[2] ?? "http://localhost:3000";
let passed = 0;
let failed = 0;

async function call(method, path, { token, body, headers = {} } = {}) {
  const res = await fetch(BASE + path, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...headers,
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await res.json().catch(() => null);
  return { status: res.status, ...json };
}

function check(name, cond, detail) {
  if (cond) {
    passed++;
    console.log(`  ✓ ${name}`);
  } else {
    failed++;
    console.log(`  ✗ ${name}`, detail ?? "");
  }
}

const login = async (identifier, password) => (await call("POST", "/api/auth/login", { body: { identifier, password } })).data;
const ymd = (d) => new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Muscat" }).format(d);
const addDays = (s, n) => ymd(new Date(Date.parse(s + "T12:00:00+04:00") + n * 86400_000));

console.log(`Glowbook API smoke test → ${BASE}\n`);

console.log("Health & envelope");
const health = await call("GET", "/api/health");
check("health ok", health.status === 200 && health.success === true && health.message === null);
const bad = await call("POST", "/api/auth/login", { body: { identifier: "owner@maisonbeauty.om", password: "wrong" } });
check("bad login → 401 envelope", bad.status === 401 && bad.success === false && bad.data === null && typeof bad.message === "string");

console.log("Auth & roles");
const owner = await login("owner@maisonbeauty.om", "Maison#2026");
check("owner routes to SALON_ADMIN", owner?.me.homeRole === "SALON_ADMIN");
const staff = await login("sarah@maisonbeauty.om", "Staff#2026");
check("staff routes to STAFF", staff?.me.homeRole === "STAFF");
const customer = await login("customer@glowbook.app", "Customer#2026");
check("customer routes to CUSTOMER", customer?.me.homeRole === "CUSTOMER");
const admin = await login("admin@glowbook.app", "Glowbook#2026");
check("super admin routes to SUPER_ADMIN", admin?.me.homeRole === "SUPER_ADMIN");
const velvet = await login("owner@velvethair.om", "Velvet#2026");

const refreshed = await call("POST", "/api/auth/refresh", { body: { refreshToken: customer.refreshToken } });
check("refresh rotates tokens", refreshed.status === 200 && refreshed.data.refreshToken !== customer.refreshToken);
const reuse = await call("POST", "/api/auth/refresh", { body: { refreshToken: customer.refreshToken } });
check("reused refresh token rejected", reuse.status === 401);
const customer2 = await login("customer@glowbook.app", "Customer#2026");

const reg = await call("POST", "/api/auth/register", {
  body: { name: "Test Guest", email: `test${Date.now()}@example.com`, password: "Password123" },
});
check("register customer", reg.status === 201 && reg.data.me.homeRole === "CUSTOMER");
const forgot = await call("POST", "/api/auth/forgot-password", { body: { email: "customer@glowbook.app" } });
check("forgot password answers generically", forgot.status === 200);
if (forgot.data?.devResetToken) {
  const reset = await call("POST", "/api/auth/reset-password", { body: { token: forgot.data.devResetToken, password: "Customer#2026" } });
  check("reset password with token", reset.status === 200);
  const again = await call("POST", "/api/auth/reset-password", { body: { token: forgot.data.devResetToken, password: "Customer#2026" } });
  check("reset token single-use", again.status === 400);
}
const cust = await login("customer@glowbook.app", "Customer#2026");
const otp = await call("POST", "/api/auth/otp/request", { body: { phone: "+96890001234" } });
if (otp.data?.devCode) {
  const v = await call("POST", "/api/auth/otp/verify", { body: { phone: "+96890001234", code: otp.data.devCode, name: "Phone User" } });
  check("phone OTP sign-in", v.status === 200 && v.data.me.user.phone === "+96890001234");
}

console.log("Multi-tenant isolation");
const ownerT = owner.accessToken;
const services = (await call("GET", "/api/services", { token: ownerT })).data;
const maisonCustomers = (await call("GET", "/api/customers", { token: ownerT })).data.items;
const vSvc = await call("GET", `/api/services/${services[0].id}`, { token: velvet.accessToken });
check("Salon B can't read Salon A service", vSvc.status === 404);
const vCust = await call("GET", `/api/customers/${maisonCustomers[0].id}`, { token: velvet.accessToken });
check("Salon B can't read Salon A customer", vCust.status === 404);
const spoof = await call("GET", "/api/customers", { token: velvet.accessToken, headers: { "X-Salon-Id": owner.me.memberships[0].salonId } });
check("X-Salon-Id spoof rejected", spoof.status === 403);
const custAsSalon = await call("GET", "/api/bookings", { token: cust.accessToken });
check("customer can't hit salon API", custAsSalon.status === 403);
const staffReports = await call("GET", "/api/reports", { token: staff.accessToken });
check("staff can't see reports", staffReports.status === 403);
const staffBookings = (await call("GET", `/api/bookings?from=${ymd(new Date())}&to=${addDays(ymd(new Date()), 7)}`, { token: staff.accessToken })).data;
check("staff sees only own bookings", staffBookings.every((b) => b.staffId === staff.me.memberships[0].staffId));
const custView = await call("GET", "/api/my/bookings?scope=all", { token: cust.accessToken });
check("customer view hides internal notes", custView.data.every((b) => !("internalNotes" in b)));

console.log("Availability & booking engine");
const soft = services.find((s) => s.name === "Soft Makeup");
const bridal = services.find((s) => s.name === "Bridal Makeup");
const profile = (await call("GET", "/api/salons/maison-beauty")).data;
check("public salon page by slug", profile?.slug === "maison-beauty" && profile.services.length >= 4);
const days = (await call("GET", `/api/availability/days?salon=maison-beauty&serviceId=${soft.id}&from=${ymd(new Date())}&days=14`)).data;
check("availability day summary", days.days.length === 14);
// The emptiest upcoming day, so the test can be re-run against the same database.
const day = [...days.days].sort((a, b) => b.slotCount - a.slotCount)[0].date;
const avail = (await call("GET", `/api/availability?salon=maison-beauty&serviceId=${soft.id}&date=${day}`)).data;
check("availability returns slots", avail.slots.length > 0, avail);

// Race: 8 guests try to book the same artist at the same instant.
const slot = avail.slots[Math.floor(avail.slots.length / 2)];
const artist = slot.staffIds[0];
const attempts = await Promise.all(
  Array.from({ length: 8 }, (_, i) =>
    call("POST", "/api/public/bookings", {
      body: {
        salon: "maison-beauty",
        serviceId: soft.id,
        staffId: artist,
        startTime: slot.start,
        customer: { name: `Race Guest ${i}`, phone: `+9687${String(1000000 + i)}` },
      },
    }),
  ),
);
const wins = attempts.filter((a) => a.status === 201);
const losses = attempts.filter((a) => a.status === 409);
check("concurrent race → exactly one booking", wins.length === 1 && losses.length === 7, attempts.map((a) => `${a.status} ${a.message}`));
check("loser message", losses[0]?.message === "Appointment is no longer available.");
const won = wins[0]?.data;

const after = (await call("GET", `/api/availability?salon=maison-beauty&serviceId=${soft.id}&date=${day}&staffId=${artist}`)).data;
check("taken slot disappears", !after.slots.some((s) => s.start === slot.start));

// Blocked time prevents booking.
const block = after.slots.at(-1); // artist's last free slot that day
check("found a later slot to block", !!block);
if (block) {
  const bt = await call("POST", "/api/blocked-times", {
    token: ownerT,
    body: { staffId: artist, startTime: block.start, endTime: new Date(Date.parse(block.start) + 3600_000).toISOString(), type: "MEETING" },
  });
  check("block time", bt.status === 201);
  const attempt = await call("POST", "/api/bookings", {
    token: ownerT,
    body: { serviceId: soft.id, staffId: artist, startTime: block.start, newCustomer: { name: "Walk In" } },
  });
  check("blocked time prevents booking", attempt.status === 409, attempt.message);
  await call("DELETE", `/api/blocked-times/${bt.data.id}`, { token: ownerT });
}

// Outside hours.
const night = new Date(Date.parse(day + "T23:30:00+04:00")).toISOString();
const late = await call("POST", "/api/bookings", { token: ownerT, body: { serviceId: soft.id, staffId: artist, startTime: night, newCustomer: { name: "Night Owl" } } });
check("outside hours rejected", late.status === 409 && /working hours|closed/.test(late.message), late.message);

// "Any available" picks someone.
const day2 = [...days.days].sort((a, b) => b.slotCount - a.slotCount)[1].date;
const avail2 = (await call("GET", `/api/availability?salon=maison-beauty&serviceId=${soft.id}&date=${day2}`)).data;
const anySlot = avail2.slots.find((s) => s.staffIds.length > 1) ?? avail2.slots[0];
const anyBook = await call("POST", "/api/public/bookings", {
  token: cust.accessToken,
  body: { salon: "maison-beauty", serviceId: soft.id, staffId: null, startTime: anySlot.start, customer: { name: "Aisha Al-Balushi", phone: "+96899112233" } },
});
check("any-available booking by signed-in customer", anyBook.status === 201 && anySlot.staffIds.includes(anyBook.data.booking.staff.id), anyBook.message);

console.log("Reschedule, cancel, undo");
const later = after.slots.find((s) => Date.parse(s.start) > Date.parse(slot.start) + 90 * 60_000);
const rs = await call("POST", `/api/bookings/${won.booking.id}/reschedule`, { token: ownerT, body: { startTime: later.start } });
check("front desk reschedule", rs.status === 200 && rs.data.startTime === later.start, rs.message);
const detail = (await call("GET", `/api/bookings/${won.booking.id}`, { token: ownerT })).data;
const hist = detail.history.find((h) => h.kind === "RESCHEDULE");
check("history keeps old + new time and actor", hist?.oldStartTime === slot.start && hist?.newStartTime === later.start && hist?.changedByName === "Layla Al-Harthy");

const guestView = await call("GET", `/api/public/bookings/${won.booking.id}?token=${won.manageToken}`);
check("guest manage link works", guestView.status === 200);
const noToken = await call("GET", `/api/public/bookings/${won.booking.id}`);
check("guest link needs token", noToken.status === 403);

const cancel = await call("POST", `/api/bookings/${won.booking.id}/cancel`, { token: ownerT, body: { reason: "Test" } });
check("salon cancel", cancel.status === 200 && cancel.data.booking.status === "CANCELLED");
const restore = await call("POST", `/api/bookings/${won.booking.id}/restore`, { token: ownerT });
check("undo cancellation", restore.status === 200 && restore.data.status === "CONFIRMED", restore.message);
const myCancel = await call("POST", `/api/my/bookings/${anyBook.data.booking.id}/cancel`, { token: cust.accessToken, body: {} });
check("customer cancel (free window)", myCancel.status === 200 && myCancel.data.quote.isFreeCancellation === true);

console.log("Deposits & payments");
const bDays = (await call("GET", `/api/availability/days?salon=maison-beauty&serviceId=${bridal.id}&from=${addDays(ymd(new Date()), 2)}&days=21`)).data;
const bDay = bDays.days.find((d) => d.slotCount > 0);
check("bridal availability found", !!bDay, bDays);
const bSlot = (await call("GET", `/api/availability?salon=maison-beauty&serviceId=${bridal.id}&date=${bDay.date}`)).data.slots[0];
const bBook = await call("POST", "/api/public/bookings", {
  body: { salon: "maison-beauty", serviceId: bridal.id, staffId: null, startTime: bSlot.start, customer: { name: "Bride Test", phone: "+96877788899" } },
});
check("deposit booking held as PENDING", bBook.status === 201 && bBook.data.booking.status === "PENDING" && bBook.data.requiresPayment);
const pay = await call("POST", `/api/public/bookings/${bBook.data.booking.id}/pay?token=${bBook.data.manageToken}`, { body: { kind: "DEPOSIT" } });
check("start deposit payment (OMR 20)", pay.status === 201 && pay.data.amountBaisa === 20000, pay.message);
const confirm = await call("POST", `/api/payments/${pay.data.paymentId}/test-confirm`, { body: { token: bBook.data.manageToken } });
check("deposit paid → CONFIRMED", confirm.status === 200 && confirm.data.booking.status === "CONFIRMED" && confirm.data.booking.balanceBaisa === 55000, confirm.message);
const desk = await call("POST", `/api/bookings/${bBook.data.booking.id}/payments`, { token: ownerT, body: { amountBaisa: 55000, method: "CARD", kind: "BALANCE" } });
check("desk records remaining OMR 55", desk.status === 201);
const salonCancel = await call("POST", `/api/bookings/${bBook.data.booking.id}/cancel`, { token: ownerT, body: {} });
check("salon cancel refunds everything paid", salonCancel.data.quote.refundBaisa === 75000);

console.log("Cron, reports, notifications");
const cronNo = await call("GET", "/api/cron/reminders");
check("cron requires secret", cronNo.status === 401);
const cron = await call("GET", "/api/cron/reminders", { headers: { Authorization: "Bearer dev-cron-secret" } });
check("cron runs", cron.status === 200, cron.message);
const cron2 = await call("GET", "/api/cron/reminders", { headers: { Authorization: "Bearer dev-cron-secret" } });
check("cron is idempotent (no duplicate reminders)", cron2.data.reminders24h === 0 && cron2.data.reminders3h === 0 && cron2.data.reviewRequests === 0, cron2.data);
const reports = await call("GET", "/api/reports", { token: ownerT });
check("reports", reports.status === 200 && reports.data.revenue.totalBaisa > 0 && reports.data.popularServices.length > 0);
const dash = await call("GET", "/api/dashboard", { token: ownerT });
check("dashboard populated", dash.status === 200 && dash.data.summary.appointments > 0);
const inbox = await call("GET", "/api/notifications", { token: ownerT });
check("owner inbox has items", inbox.data.items.length > 0);
const log = await call("GET", "/api/salon/notification-log", { token: ownerT });
check("delivery log records channel outcome", log.data.items.some((n) => n.status === "SKIPPED" || n.status === "SENT"));
const cal = await call("GET", `/api/calendar?from=${ymd(new Date())}&to=${ymd(new Date())}`, { token: ownerT });
check("calendar day feed", cal.status === 200 && cal.data.staff.length === 3);
const month = await call("GET", `/api/calendar/month?month=${ymd(new Date()).slice(0, 7)}`, { token: ownerT });
check("calendar month feed", month.status === 200 && month.data.days.length >= 28);
const adminSalons = await call("GET", "/api/admin/salons", { token: admin.accessToken });
check("super admin lists tenants", adminSalons.data.length >= 3);
const notAdmin = await call("GET", "/api/admin/salons", { token: ownerT });
check("owner is not super admin", notAdmin.status === 403);

// Regression: compare against the database itself, not an API round trip. A session
// timezone mismatch once shifted every stored instant while round trips still matched.
if (process.env.DATABASE_URL) {
  console.log("Storage");
  const { default: pg } = await import("pg");
  const client = new pg.Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();
  const row = (
    await client.query(
      `SELECT extract(epoch FROM "startTime") * 1000 AS ms, extract(epoch FROM now() - "createdAt") AS age FROM "Booking" WHERE id = $1`,
      [won.booking.id],
    )
  ).rows[0];
  check("stored instant equals the requested slot", Number(row.ms) === Date.parse(later.start), { stored: new Date(Number(row.ms)).toISOString(), expected: later.start });
  check("createdAt agrees with the database clock", Math.abs(Number(row.age)) < 600, row);
  await client.end();
}

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
