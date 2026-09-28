import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../shared/models/models.dart';

class DashboardData {
  DashboardData({
    required this.salonName,
    this.salonNameAr,
    required this.slug,
    required this.localMinute,
    required this.appointments,
    required this.confirmed,
    required this.pending,
    required this.arrived,
    required this.completed,
    required this.revenueBaisa,
    required this.expectedRevenueBaisa,
    required this.schedule,
    this.nextUp,
    required this.week,
    required this.pendingRefunds,
    required this.unread,
  });
  final String salonName;
  final String? salonNameAr;
  final String slug;
  final int localMinute;
  final int appointments;
  final int confirmed;
  final int pending;
  final int arrived;
  final int completed;
  final int revenueBaisa;
  final int expectedRevenueBaisa;
  final List<Booking> schedule;
  final Booking? nextUp;
  final List<({String date, int revenueBaisa})> week;
  final int pendingRefunds;
  final int unread;

  factory DashboardData.fromJson(Json j) {
    final salon = asJson(j['salon']);
    final s = asJson(j['summary']);
    return DashboardData(
      salonName: salon['name'] as String,
      salonNameAr: asStr(salon['nameAr']),
      slug: asStr(salon['slug']) ?? '',
      localMinute: asInt(j['localMinute']),
      appointments: asInt(s['appointments']),
      confirmed: asInt(s['confirmed']),
      pending: asInt(s['pending']),
      arrived: asInt(s['arrived']),
      completed: asInt(s['completed']),
      revenueBaisa: asInt(s['revenueBaisa']),
      expectedRevenueBaisa: asInt(s['expectedRevenueBaisa']),
      schedule: asJsonList(j['schedule']).map(Booking.fromJson).toList(),
      nextUp: j['nextUp'] is Map ? Booking.fromJson(asJson(j['nextUp'])) : null,
      week: asJsonList(j['week']).map((w) => (date: w['date'] as String, revenueBaisa: asInt(w['revenueBaisa']))).toList(),
      pendingRefunds: asInt(j['pendingRefunds']),
      unread: asInt(j['unreadNotifications']),
    );
  }
}

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  ref.watch(membershipProvider.select((m) => m?.salonId)); // reload when switching salons
  final api = ref.watch(apiClientProvider);
  return DashboardData.fromJson(asJson(await api.get<Object?>('/api/dashboard')));
});
