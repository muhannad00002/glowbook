import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../shared/models/models.dart';

class ReportData {
  ReportData({
    required this.totalRevenue,
    required this.avgPerDay,
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.bookingsTotal,
    required this.completed,
    required this.cancellationRate,
    required this.noShowRate,
    required this.byStatus,
    required this.popular,
    required this.staff,
    required this.newClients,
    required this.returningClients,
    required this.retention,
  });

  final int totalRevenue;
  final int avgPerDay;
  final List<({String label, int value})> daily;
  final List<({String label, int value})> weekly;
  final List<({String label, int value})> monthly;
  final int bookingsTotal;
  final int completed;
  final double cancellationRate;
  final double noShowRate;
  final Map<String, int> byStatus;
  final List<({String name, String? nameAr, int count, int revenue})> popular;
  final List<({String name, String? nameAr, String color, int completed, int revenue, double? rating})> staff;
  final int newClients;
  final int returningClients;
  final double retention;

  factory ReportData.fromJson(Json j) {
    final rev = asJson(j['revenue']);
    final b = asJson(j['bookings']);
    final c = asJson(j['customers']);
    return ReportData(
      totalRevenue: asInt(rev['totalBaisa']),
      avgPerDay: asInt(rev['averagePerDayBaisa']),
      daily: asJsonList(rev['daily']).map((d) => (label: d['date'] as String, value: asInt(d['revenueBaisa']))).toList(),
      weekly: asJsonList(rev['weekly']).map((d) => (label: d['weekStart'] as String, value: asInt(d['revenueBaisa']))).toList(),
      monthly: asJsonList(rev['monthly']).map((d) => (label: d['month'] as String, value: asInt(d['revenueBaisa']))).toList(),
      bookingsTotal: asInt(b['total']),
      completed: asInt(b['completed']),
      cancellationRate: asDouble(b['cancellationRate']),
      noShowRate: asDouble(b['noShowRate']),
      byStatus: asJson(b['byStatus']).map((k, v) => MapEntry(k, asInt(v))),
      popular: asJsonList(j['popularServices'])
          .map((s) => (name: s['name'] as String, nameAr: asStr(s['nameAr']), count: asInt(s['count']), revenue: asInt(s['revenueBaisa'])))
          .toList(),
      staff: asJsonList(j['staffPerformance'])
          .map((s) => (
                name: s['name'] as String,
                nameAr: asStr(s['nameAr']),
                color: asStr(s['color']) ?? '#8E4B61',
                completed: asInt(s['completed']),
                revenue: asInt(s['revenueBaisa']),
                rating: s['avgRating'] == null ? null : asDouble(s['avgRating']),
              ))
          .toList(),
      newClients: asInt(c['new']),
      returningClients: asInt(c['returning']),
      retention: asDouble(c['retentionRate']),
    );
  }
}

final reportsProvider = FutureProvider.autoDispose.family<ReportData, ({String from, String to})>((ref, r) async {
  ref.watch(membershipProvider.select((m) => m?.salonId));
  final api = ref.watch(apiClientProvider);
  return ReportData.fromJson(asJson(await api.get<Object?>('/api/reports', query: {'from': r.from, 'to': r.to})));
});
