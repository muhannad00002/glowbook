import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/providers.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../shared/models/models.dart';

/// The salon's own settings document (GET /api/salon), kept as JSON: the settings
/// screens edit many small fields and PATCH only what changed.
class SalonSettings {
  SalonSettings(this.json);
  final Json json;

  String get slug => json['slug'] as String;
  String get name => json['name'] as String;
  String get timezone => asStr(json['timezone']) ?? 'Asia/Muscat';
  bool flag(String k) => json[k] == true;
  int integer(String k) => asInt(json[k]);
  String? text(String k) => asStr(json[k]);
  List<Shift> get hours => asJsonList(json['workingHours']).map(Shift.fromJson).toList();
}

class SettingsRepository {
  SettingsRepository(this._api);
  final ApiClient _api;

  Future<SalonSettings> load() async => SalonSettings(asJson(await _api.get<Object?>('/api/salon')));
  Future<void> patch(Json fields) => _api.patch<Object?>('/api/salon', body: fields);
  Future<void> saveHours(List<Shift> days) => _api.put<Object?>('/api/salon/hours', body: {
        'days': [for (final d in days) {'dayOfWeek': d.dayOfWeek, 'openMinute': d.startMinute, 'closeMinute': d.endMinute}],
      });

  Future<List<Json>> holidays() async => asJsonList(await _api.get<List<dynamic>>('/api/salon/holidays'));
  Future<void> addHoliday(Json body) => _api.post<Object?>('/api/salon/holidays', body: body);
  Future<void> deleteHoliday(String id) => _api.delete<Object?>('/api/salon/holidays/$id');

  Future<Json> deliveryLog() async => asJson(await _api.get<Object?>('/api/salon/notification-log', query: {'limit': '40'}));
  Future<List<Json>> members() async => asJsonList(await _api.get<List<dynamic>>('/api/salon/members'));
}

final settingsRepositoryProvider = Provider((ref) => SettingsRepository(ref.watch(apiClientProvider)));

final salonSettingsProvider = FutureProvider.autoDispose<SalonSettings>((ref) {
  ref.watch(membershipProvider.select((m) => m?.salonId));
  return ref.watch(settingsRepositoryProvider).load();
});

final holidaysProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(settingsRepositoryProvider).holidays());
final deliveryLogProvider = FutureProvider.autoDispose<Json>((ref) => ref.watch(settingsRepositoryProvider).deliveryLog());
final membersProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(settingsRepositoryProvider).members());
