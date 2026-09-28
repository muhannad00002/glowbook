import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/providers.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../shared/models/models.dart';

class StaffRepository {
  StaffRepository(this._api);
  final ApiClient _api;

  Future<List<StaffMember>> list() async => asJsonList(await _api.get<List<dynamic>>('/api/staff')).map(StaffMember.fromJson).toList();
  Future<StaffMember> detail(String id) async => StaffMember.fromJson(asJson(await _api.get<Object?>('/api/staff/$id')));
  Future<void> create(Json body) => _api.post<Object?>('/api/staff', body: body);
  Future<void> update(String id, Json body) => _api.patch<Object?>('/api/staff/$id', body: body);
  /// Deletes, or deactivates when she has booking history (the server decides).
  Future<void> remove(String id) => _api.delete<Object?>('/api/staff/$id');

  Future<void> addTimeOff(String staffId, {required DateTime start, required DateTime end, required String type, String? reason, bool force = false}) =>
      _api.post<Object?>('/api/staff/$staffId/time-off', body: {
        'startTime': start.toUtc().toIso8601String(),
        'endTime': end.toUtc().toIso8601String(),
        'type': type,
        'reason': reason,
        'force': force,
      });

  Future<void> deleteTimeOff(String staffId, String id) => _api.delete<Object?>('/api/staff/$staffId/time-off/$id');
}

final staffRepositoryProvider = Provider((ref) => StaffRepository(ref.watch(apiClientProvider)));

final staffListProvider = FutureProvider.autoDispose<List<StaffMember>>((ref) {
  ref.watch(membershipProvider.select((m) => m?.salonId));
  return ref.watch(staffRepositoryProvider).list();
});

final staffDetailProvider = FutureProvider.autoDispose.family<StaffMember, String>((ref, id) => ref.watch(staffRepositoryProvider).detail(id));
