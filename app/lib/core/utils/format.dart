import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../l10n/app_localizations.dart';
import '../errors/api_exception.dart';

/// Formatting helpers. Every appointment time is shown in the *salon's* timezone —
/// a client browsing from abroad still sees the time she'll actually walk in.
class Fmt {
  Fmt(this.context)
      : l = AppLocalizations.of(context),
        locale = Localizations.localeOf(context).languageCode;

  final BuildContext context;
  final AppLocalizations l;
  final String locale;

  // Money ------------------------------------------------------------------
  /// 25000 → "25", 12500 → "12.5", 7250 → "7.25" (OMR has three decimal places).
  String amount(int baisa) {
    final digits = baisa % 1000 == 0
        ? 0
        : baisa % 100 == 0
            ? 1
            : baisa % 10 == 0
                ? 2
                : 3;
    return NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: digits).format(baisa / 1000);
  }

  String money(int baisa) => l.money(amount(baisa));

  // Time -------------------------------------------------------------------
  static DateTime inZone(DateTime instant, String timezone) {
    try {
      return tz.TZDateTime.from(instant, tz.getLocation(timezone));
    } catch (_) {
      return instant.toLocal();
    }
  }

  /// Salon-local calendar date + minutes-from-midnight → the absolute instant.
  static DateTime zonedInstant(String ymd, int minute, String timezone) {
    final p = ymd.split('-').map(int.parse).toList();
    try {
      return tz.TZDateTime(tz.getLocation(timezone), p[0], p[1], p[2], minute ~/ 60, minute % 60);
    } catch (_) {
      return DateTime(p[0], p[1], p[2], minute ~/ 60, minute % 60);
    }
  }

  String time(DateTime instant, String timezone) => DateFormat.jm(locale).format(inZone(instant, timezone));
  String dayMonth(DateTime instant, String timezone) => DateFormat.MMMd(locale).format(inZone(instant, timezone));
  String weekdayDayMonth(DateTime instant, String timezone) => DateFormat.MMMEd(locale).format(inZone(instant, timezone));
  String fullDate(DateTime instant, String timezone) => DateFormat.yMMMMEEEEd(locale).format(inZone(instant, timezone));
  String dateTime(DateTime instant, String timezone) => '${weekdayDayMonth(instant, timezone)} · ${time(instant, timezone)}';

  /// "Today", "Tomorrow", or "Tue 3 Oct" — relative to the salon's own today.
  String relativeDay(DateTime instant, String timezone) {
    final d = inZone(instant, timezone);
    final now = inZone(DateTime.now(), timezone);
    final days = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days == 0) return l.labelToday;
    if (days == 1) return l.labelTomorrow;
    if (days == -1) return l.labelYesterday;
    return DateFormat.MMMEd(locale).format(d);
  }

  /// "YYYY-MM-DD" → "Tue, 3 Oct" (a calendar date, no timezone involved).
  String ymdLabel(String ymd, {String pattern = 'MMMEd'}) {
    final p = ymd.split('-').map(int.parse).toList();
    return DateFormat(pattern, locale).format(DateTime(p[0], p[1], p[2]));
  }

  String minuteOfDay(int minute) =>
      DateFormat.jm(locale).format(DateTime(2000, 1, 1, minute ~/ 60, minute % 60));

  String duration(int minutes) {
    if (minutes < 60) return l.labelMinutes(minutes);
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? l.labelHours(h) : l.labelHoursMinutes(h, m);
  }

  String weekdayName(int dayOfWeek, {bool short = false}) {
    // 2023-01-01 was a Sunday (dayOfWeek 0).
    final d = DateTime(2023, 1, 1 + dayOfWeek);
    return (short ? DateFormat.E(locale) : DateFormat.EEEE(locale)).format(d);
  }

  String percent(double v) => NumberFormat.percentPattern(locale).format(v);
  String number(num v) => NumberFormat.decimalPattern(locale).format(v);

  String statusLabel(String status) => switch (status) {
        'PENDING' => l.statusPending,
        'CONFIRMED' => l.statusConfirmed,
        'ARRIVED' => l.statusArrived,
        'IN_SERVICE' => l.statusInService,
        'COMPLETED' => l.statusCompleted,
        'CANCELLED' => l.statusCancelled,
        'NO_SHOW' => l.statusNoShow,
        'PENDING_PAYMENT' => l.statusAwaitingPayment,
        'EXPIRED' => l.statusExpired,
        _ => status,
      };

  String methodLabel(String m) => switch (m) {
        'CASH' => l.methodCash,
        'CARD' => l.methodCard,
        'BANK_TRANSFER' => l.methodBank,
        _ => l.methodOnline,
      };

  String kindLabel(String k) => switch (k) {
        'DEPOSIT' => l.kindDeposit,
        'BALANCE' => l.kindBalance,
        'FULL' => l.kindFull,
        'CANCELLATION_FEE' => l.kindFee,
        _ => l.kindRefund,
      };

  String roleLabel(String r) => switch (r) {
        'OWNER' => l.roleOwner,
        'MANAGER' => l.roleManager,
        'RECEPTIONIST' => l.roleReceptionist,
        _ => l.roleStaff,
      };

  /// A friendly message for any error thrown by a repository.
  String error(Object e) {
    if (e is ApiException) return e.offline ? l.errorOffline : e.message;
    return l.errorGeneric;
  }
}

extension FmtX on BuildContext {
  Fmt get fmt => Fmt(this);
  AppLocalizations get l10n => AppLocalizations.of(this);
  String get lang => Localizations.localeOf(this).languageCode;
}

/// "YYYY-MM-DD" helpers for calendar dates (no timezone math).
abstract final class Ymd {
  static String of(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static DateTime parse(String s) {
    final p = s.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  static String add(String s, int days) {
    final d = parse(s);
    return of(DateTime(d.year, d.month, d.day + days));
  }

  /// Today's date in the salon's timezone.
  static String today(String timezone) => of(Fmt.inZone(DateTime.now(), timezone));
  static int dayOfWeek(String s) => parse(s).weekday % 7; // Dart: Mon=1..Sun=7 → Sun=0
}
