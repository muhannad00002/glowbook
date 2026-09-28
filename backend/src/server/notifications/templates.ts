import type { NotificationType } from "@/generated/prisma/enums";

/**
 * Built-in copy for every notification. The seed copies these into NotificationTemplate
 * (salonId = null) so salons can override them per channel/locale; this map is the
 * last-resort fallback if the table has no row.
 *
 * Variables: {{customer_name}} {{salon_name}} {{service_name}} {{date}} {{time}}
 *            {{staff_name}} {{booking_id}}
 */
export const DEFAULT_TEMPLATES: Record<NotificationType, Record<"en" | "ar", { title: string; body: string }>> = {
  BOOKING_CREATED: {
    en: {
      title: "Booking received ✨",
      body: "Hi {{customer_name}} 💕 We've received your {{service_name}} booking at {{salon_name}} for {{date}} at {{time}}. Ref {{booking_id}}.",
    },
    ar: {
      title: "تم استلام حجزك ✨",
      body: "مرحباً {{customer_name}} 💕 استلمنا حجزك لخدمة {{service_name}} في {{salon_name}} يوم {{date}} الساعة {{time}}. رقم الحجز {{booking_id}}.",
    },
  },
  BOOKING_CONFIRMED: {
    en: {
      title: "Appointment confirmed 💕",
      body: "Hi {{customer_name}} 💕 Your appointment at {{salon_name}} is confirmed for {{date}} at {{time}} with {{staff_name}}. Ref {{booking_id}}.",
    },
    ar: {
      title: "تم تأكيد موعدك 💕",
      body: "مرحباً {{customer_name}} 💕 تم تأكيد موعدك في {{salon_name}} يوم {{date}} الساعة {{time}} مع {{staff_name}}. رقم الحجز {{booking_id}}.",
    },
  },
  BOOKING_RESCHEDULED: {
    en: {
      title: "Appointment moved",
      body: "Hi {{customer_name}}, your {{service_name}} at {{salon_name}} is now on {{date}} at {{time}} with {{staff_name}}.",
    },
    ar: {
      title: "تم تغيير موعدك",
      body: "مرحباً {{customer_name}}، أصبح موعد {{service_name}} في {{salon_name}} يوم {{date}} الساعة {{time}} مع {{staff_name}}.",
    },
  },
  BOOKING_CANCELLED: {
    en: {
      title: "Appointment cancelled",
      body: "Hi {{customer_name}}, your {{service_name}} at {{salon_name}} on {{date}} at {{time}} has been cancelled. We hope to see you soon.",
    },
    ar: {
      title: "تم إلغاء الموعد",
      body: "مرحباً {{customer_name}}، تم إلغاء موعد {{service_name}} في {{salon_name}} يوم {{date}} الساعة {{time}}. نتطلع لرؤيتك قريباً.",
    },
  },
  REMINDER_24H: {
    en: {
      title: "See you tomorrow 💄",
      body: "Hi {{customer_name}} 💕 A little reminder: {{service_name}} at {{salon_name}} tomorrow ({{date}}) at {{time}} with {{staff_name}}.",
    },
    ar: {
      title: "نراكِ غداً 💄",
      body: "مرحباً {{customer_name}} 💕 تذكير لطيف: موعد {{service_name}} في {{salon_name}} غداً ({{date}}) الساعة {{time}} مع {{staff_name}}.",
    },
  },
  REMINDER_3H: {
    en: {
      title: "Almost time ✨",
      body: "Hi {{customer_name}}, your {{service_name}} at {{salon_name}} starts at {{time}} today with {{staff_name}}. See you soon!",
    },
    ar: {
      title: "اقترب موعدك ✨",
      body: "مرحباً {{customer_name}}، موعد {{service_name}} في {{salon_name}} اليوم الساعة {{time}} مع {{staff_name}}. نراكِ قريباً!",
    },
  },
  BOOKING_COMPLETED: {
    en: {
      title: "Thank you for visiting 💕",
      body: "Thank you {{customer_name}} for visiting {{salon_name}}! We hope you loved your {{service_name}}.",
    },
    ar: {
      title: "شكراً لزيارتك 💕",
      body: "شكراً {{customer_name}} لزيارتك {{salon_name}}! نتمنى أن تكوني استمتعتِ بخدمة {{service_name}}.",
    },
  },
  REVIEW_REQUEST: {
    en: {
      title: "How was your visit?",
      body: "Hi {{customer_name}}, how was your {{service_name}} at {{salon_name}}? Leave a quick review — it means the world to us.",
    },
    ar: {
      title: "كيف كانت زيارتك؟",
      body: "مرحباً {{customer_name}}، كيف كانت خدمة {{service_name}} في {{salon_name}}؟ شاركينا تقييمك — يهمنا كثيراً.",
    },
  },
  PASSWORD_RESET: {
    en: { title: "Reset your password", body: "Use this link to reset your Glowbook password (valid for 1 hour): {{link}}" },
    ar: { title: "إعادة تعيين كلمة المرور", body: "استخدمي هذا الرابط لإعادة تعيين كلمة المرور (صالح لمدة ساعة): {{link}}" },
  },
  PHONE_OTP: {
    en: { title: "Your code", body: "Your Glowbook code is {{code}}. It expires in 10 minutes." },
    ar: { title: "رمز التحقق", body: "رمز التحقق الخاص بك في Glowbook هو {{code}}. صالح لمدة 10 دقائق." },
  },
};

export function renderTemplate(text: string, vars: Record<string, string>): string {
  return text.replace(/\{\{\s*(\w+)\s*\}\}/g, (_, key: string) => vars[key] ?? "");
}
