import { deflateSync } from "node:zlib";
import { PKPass } from "passkit-generator";
import { db } from "@/lib/db";
import { badRequest, conflict, notFound } from "@/lib/http";
import { formatLocal } from "@/lib/time";

/**
 * Apple Wallet passes for seasonal tokens.
 *
 * A .pkpass is a zip of pass.json + images, signed with the salon's Apple "Pass Type ID"
 * certificate. Nothing works until these are set in Vercel (never in the app):
 *   APPLE_WALLET_PASS_TYPE_ID   e.g. pass.om.maisonbeauty.tokens
 *   APPLE_WALLET_TEAM_ID        10-character Apple Developer team id
 *   APPLE_WALLET_CERT           the Pass Type ID certificate (PEM)
 *   APPLE_WALLET_KEY            its private key (PEM)
 *   APPLE_WALLET_KEY_PASSPHRASE optional
 *   APPLE_WALLET_WWDR           Apple WWDR intermediate certificate, G4 (PEM)
 * PEMs may be stored with literal "\n" sequences; they are unescaped here.
 */

const env = (k: string) => process.env[k]?.trim() || undefined;
const pem = (k: string) => env(k)?.replace(/\\n/g, "\n");

export function walletConfigured() {
  return !!(env("APPLE_WALLET_PASS_TYPE_ID") && env("APPLE_WALLET_TEAM_ID") && pem("APPLE_WALLET_CERT") && pem("APPLE_WALLET_KEY") && pem("APPLE_WALLET_WWDR"));
}

/** Statuses a pass makes sense for: paid and not over. */
export const WALLET_STATUSES = ["CONFIRMED", "ARRIVED", "COMPLETED"];

// Brand colours (rosewood / blush).
const BG = "rgb(142, 75, 97)";
const FG = "rgb(255, 255, 255)";
const LABEL = "rgb(248, 222, 230)";

const COPY = {
  en: {
    token: "TOKEN",
    date: "DATE",
    time: "TIME",
    arrive: "ARRIVE BY",
    ref: "REFERENCE",
    salon: "Salon",
    address: "Address",
    phone: "Phone",
    paid: "Paid",
    balance: "Due at the salon",
    link: "Your token online",
    note: "Please arrive a few minutes early so you don't miss your turn.",
    description: (n: number, s: string) => `Token #${n} — ${s}`,
  },
  ar: {
    token: "الرقم",
    date: "التاريخ",
    time: "الوقت",
    arrive: "الحضور قبل",
    ref: "المرجع",
    salon: "الصالون",
    address: "العنوان",
    phone: "الهاتف",
    paid: "المدفوع",
    balance: "المتبقي في الصالون",
    link: "رقمك على الإنترنت",
    note: "يرجى الحضور قبل الموعد بدقائق حتى لا يفوتك دورك.",
    description: (n: number, s: string) => `الرقم ${n} — ${s}`,
  },
};

export async function buildTokenPass(tokenId: string, opts: { lang: "en" | "ar"; link: string }) {
  if (!walletConfigured()) throw badRequest("Apple Wallet isn't set up for this salon yet.");
  const t = await db.seasonalToken.findUnique({
    where: { id: tokenId },
    include: { salon: true, offering: { include: { event: true } } },
  });
  if (!t) throw notFound("Token not found.");
  if (!WALLET_STATUSES.includes(t.status)) throw conflict("Only a paid token can be added to Wallet.");

  const ar = opts.lang === "ar";
  const c = COPY[opts.lang];
  const tz = t.salon.timezone;
  const loc = opts.lang;
  const salonName = (ar && t.salon.nameAr) || t.salon.name;
  const offering = (ar && t.offering.nameAr) || t.offering.name;
  const eventName = (ar && t.offering.event.nameAr) || t.offering.event.name;
  const money = (b: number) => `${(b / 1000).toFixed(3).replace(/\.?0+$/, "")} ${ar ? "ر.ع" : "OMR"}`;
  const arriveBy = new Date(t.startTime.getTime() - 10 * 60_000);

  const pass = new PKPass(
    {
      "icon.png": solidPng(29, 29),
      "icon@2x.png": solidPng(58, 58),
      "icon@3x.png": solidPng(87, 87),
    },
    {
      wwdr: pem("APPLE_WALLET_WWDR")!,
      signerCert: pem("APPLE_WALLET_CERT")!,
      signerKey: pem("APPLE_WALLET_KEY")!,
      signerKeyPassphrase: env("APPLE_WALLET_KEY_PASSPHRASE"),
    },
    {
      formatVersion: 1,
      passTypeIdentifier: env("APPLE_WALLET_PASS_TYPE_ID")!,
      teamIdentifier: env("APPLE_WALLET_TEAM_ID")!,
      serialNumber: t.id,
      organizationName: salonName,
      description: c.description(t.number, offering),
      logoText: salonName,
      backgroundColor: BG,
      foregroundColor: FG,
      labelColor: LABEL,
      sharingProhibited: true,
    },
  );
  pass.type = "eventTicket";
  pass.headerFields.push({ key: "number", label: c.token, value: `#${t.number}` });
  pass.primaryFields.push({ key: "service", label: eventName, value: offering });
  pass.secondaryFields.push(
    { key: "date", label: c.date, value: formatLocal(t.startTime, tz, loc, { weekday: "short", day: "numeric", month: "short" }) },
    { key: "time", label: c.time, value: formatLocal(t.startTime, tz, loc, { hour: "numeric", minute: "2-digit" }) },
  );
  pass.auxiliaryFields.push(
    { key: "arrive", label: c.arrive, value: formatLocal(arriveBy, tz, loc, { hour: "numeric", minute: "2-digit" }) },
    { key: "ref", label: c.ref, value: t.reference },
  );
  pass.backFields.push(
    { key: "note", label: c.salon, value: `${salonName}\n${c.note}` },
    ...(t.salon.address ? [{ key: "address", label: c.address, value: (ar && t.salon.addressAr) || t.salon.address }] : []),
    ...(t.salon.phone ? [{ key: "phone", label: c.phone, value: t.salon.phone }] : []),
    { key: "paid", label: c.paid, value: money(t.paidBaisa) },
    ...(t.priceBaisa > t.paidBaisa ? [{ key: "balance", label: c.balance, value: money(t.priceBaisa - t.paidBaisa) }] : []),
    { key: "link", label: c.link, value: opts.link },
  );
  // The desk can scan the reference to find the token.
  pass.setBarcodes({ format: "PKBarcodeFormatQR", message: t.reference, messageEncoding: "iso-8859-1", altText: t.reference });
  pass.setRelevantDate(arriveBy);
  pass.setExpirationDate(new Date(t.endTime.getTime() + 24 * 3600_000));
  if (t.salon.latitude != null && t.salon.longitude != null) {
    pass.setLocations({ latitude: t.salon.latitude, longitude: t.salon.longitude, relevantText: c.description(t.number, offering) });
  }
  return { buffer: pass.getAsBuffer(), fileName: `token-${t.number}.pkpass` };
}

// ---------------------------------------------------------------------------
// A plain brand-coloured PNG, generated in code (no binary assets in the repo).
// ---------------------------------------------------------------------------

const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c >>> 0;
  }
  return table;
})();

function crc32(buf: Buffer) {
  let c = 0xffffffff;
  for (const b of buf) c = CRC_TABLE[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type: string, data: Buffer) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}

/** Rosewood square with a soft blush ring — the pass icon. */
function solidPng(w: number, h: number) {
  const [r, g, b] = [142, 75, 97];
  const ring = [248, 222, 230];
  const raw = Buffer.alloc((w * 4 + 1) * h);
  const cx = (w - 1) / 2;
  const cy = (h - 1) / 2;
  const outer = Math.min(w, h) * 0.32;
  const inner = outer * 0.62;
  for (let y = 0; y < h; y++) {
    const row = y * (w * 4 + 1);
    raw[row] = 0; // filter: none
    for (let x = 0; x < w; x++) {
      const d = Math.hypot(x - cx, y - cy);
      const onRing = d <= outer && d >= inner;
      const o = row + 1 + x * 4;
      raw[o] = onRing ? ring[0] : r;
      raw[o + 1] = onRing ? ring[1] : g;
      raw[o + 2] = onRing ? ring[2] : b;
      raw[o + 3] = 255;
    }
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // RGBA
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", ihdr),
    chunk("IDAT", deflateSync(raw)),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}
