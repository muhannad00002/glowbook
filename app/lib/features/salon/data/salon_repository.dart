import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/providers.dart';
import '../../../shared/models/models.dart';

/// Public salon data for the booking pages: the salon profile and availability.
class SalonRepository {
  SalonRepository(this._api);
  final ApiClient _api;

  Future<SalonProfile> profile(String slug) async => SalonProfile.fromJson(asJson(await _api.get<Object?>('/api/salons/$slug')));

  /// [serviceIds] are booked back to back with one artist.
  Future<List<DayAvailability>> days({required String salon, required List<String> serviceIds, required String from, int days = 21, String? staffId}) async {
    final data = asJson(
      await _api.get<Object?>(
        '/api/availability/days',
        query: {'salon': salon, 'serviceIds': serviceIds.join(','), 'from': from, 'days': '$days', 'staffId': staffId},
      ),
    );
    return asJsonList(data['days']).map(DayAvailability.fromJson).toList();
  }

  Future<List<Slot>> slots({required String salon, required List<String> serviceIds, required String date, String? staffId}) async {
    final data = asJson(
      await _api.get<Object?>('/api/availability', query: {'salon': salon, 'serviceIds': serviceIds.join(','), 'date': date, 'staffId': staffId}),
    );
    return asJsonList(data['slots']).map(Slot.fromJson).toList();
  }
}

final salonRepositoryProvider = Provider((ref) => SalonRepository(ref.watch(apiClientProvider)));

final salonProfileProvider = FutureProvider.autoDispose.family<SalonProfile, String>((ref, slug) => ref.watch(salonRepositoryProvider).profile(slug));
