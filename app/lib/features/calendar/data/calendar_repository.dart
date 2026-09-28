import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../shared/models/models.dart';

class CalendarBlock {
  CalendarBlock({required this.id, this.staffId, required this.start, required this.end, required this.type, this.note, this.isTimeOff = false});
  final String id;
  final String? staffId; // null = whole salon
  final DateTime start;
  final DateTime end;
  final String type;
  final String? note;
  final bool isTimeOff;
}

class CalendarData {
  CalendarData({required this.from, required this.to, required this.staff, required this.salonHours, required this.closedDates, required this.bookings, required this.blocks});
  final String from;
  final String to;
  final List<StaffMember> staff;
  final List<Shift> salonHours;
  final Map<String, String> closedDates; // date → occasion
  final List<Booking> bookings;
  final List<CalendarBlock> blocks;

  factory CalendarData.fromJson(Json j) => CalendarData(
        from: j['from'] as String,
        to: j['to'] as String,
        staff: asJsonList(j['staff']).map(StaffMember.fromJson).toList(),
        salonHours: asJsonList(j['salonHours']).map(Shift.fromJson).toList(),
        closedDates: {
          for (final h in asJsonList(j['holidays']))
            if (h['isClosed'] != false) h['date'] as String: asStr(h['name']) ?? '',
        },
        bookings: asJsonList(j['bookings']).map(Booking.fromJson).toList(),
        blocks: [
          ...asJsonList(j['blocked']).map((b) => CalendarBlock(
                id: b['id'] as String,
                staffId: asStr(b['staffId']),
                start: asDateReq(b['startTime']),
                end: asDateReq(b['endTime']),
                type: asStr(b['type']) ?? 'OTHER',
                note: asStr(b['note']),
              )),
          ...asJsonList(j['timeOff']).map((t) => CalendarBlock(
                id: t['id'] as String,
                staffId: asStr(t['staffId']),
                start: asDateReq(t['startTime']),
                end: asDateReq(t['endTime']),
                type: asStr(t['type']) ?? 'VACATION',
                note: asStr(t['reason']),
                isTimeOff: true,
              )),
        ],
      );
}

class MonthDay {
  MonthDay({required this.date, required this.total, required this.byStatus, required this.valueBaisa});
  final String date;
  final int total;
  final Map<String, int> byStatus;
  final int valueBaisa;
}

typedef CalendarRange = ({String from, String to, String? staffId});

final calendarRangeProvider = FutureProvider.autoDispose.family<CalendarData, CalendarRange>((ref, r) async {
  ref.watch(membershipProvider.select((m) => m?.salonId));
  final api = ref.watch(apiClientProvider);
  return CalendarData.fromJson(asJson(await api.get<Object?>('/api/calendar', query: {'from': r.from, 'to': r.to, 'staffId': r.staffId})));
});

final calendarMonthProvider = FutureProvider.autoDispose.family<({List<MonthDay> days, Map<String, String> closed}), ({String month, String? staffId})>((ref, r) async {
  ref.watch(membershipProvider.select((m) => m?.salonId));
  final api = ref.watch(apiClientProvider);
  final j = asJson(await api.get<Object?>('/api/calendar/month', query: {'month': r.month, 'staffId': r.staffId}));
  return (
    days: asJsonList(j['days'])
        .map((d) => MonthDay(
              date: d['date'] as String,
              total: asInt(d['total']),
              byStatus: asJson(d['byStatus']).map((k, v) => MapEntry(k, asInt(v))),
              valueBaisa: asInt(d['bookedValueBaisa']),
            ))
        .toList(),
    closed: {
      for (final h in asJsonList(j['holidays']))
        if (h['isClosed'] != false) h['date'] as String: asStr(h['name']) ?? '',
    },
  );
});
