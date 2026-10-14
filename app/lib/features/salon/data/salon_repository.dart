import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/providers.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../shared/models/models.dart';

/// Public, customer-facing salon data: discovery, profiles, availability, favourites.
class SalonRepository {
  SalonRepository(this._api);
  final ApiClient _api;

  Future<List<SalonCard>> discover({String? q, String? category, bool favorites = false}) async {
    final data = asJson(await _api.get<Object?>('/api/salons', query: {
      'q': (q?.isEmpty ?? true) ? null : q,
      'category': category,
      if (favorites) 'favorites': 'true',
    }));
    return asJsonList(data['items']).map(SalonCard.fromJson).toList();
  }

  Future<SalonProfile> profile(String slug) async => SalonProfile.fromJson(asJson(await _api.get<Object?>('/api/salons/$slug')));

  Future<List<Review>> reviews(String slug) async =>
      asJsonList(asJson(await _api.get<Object?>('/api/salons/$slug/reviews'))['items']).map(Review.fromJson).toList();

  /// [serviceIds] are booked back to back with one artist.
  Future<List<DayAvailability>> days({required String salon, required List<String> serviceIds, required String from, int days = 21, String? staffId}) async {
    final data = asJson(await _api.get<Object?>('/api/availability/days', query: {
      'salon': salon,
      'serviceIds': serviceIds.join(','),
      'from': from,
      'days': '$days',
      'staffId': staffId,
    }));
    return asJsonList(data['days']).map(DayAvailability.fromJson).toList();
  }

  Future<List<Slot>> slots({required String salon, required List<String> serviceIds, required String date, String? staffId}) async {
    final data = asJson(await _api.get<Object?>('/api/availability', query: {'salon': salon, 'serviceIds': serviceIds.join(','), 'date': date, 'staffId': staffId}));
    return asJsonList(data['slots']).map(Slot.fromJson).toList();
  }

  Future<void> setFavorite(String salonId, bool favorite) =>
      favorite ? _api.post<Object?>('/api/my/favorites', body: {'salonId': salonId}) : _api.delete<Object?>('/api/my/favorites/$salonId');
}

final salonRepositoryProvider = Provider((ref) => SalonRepository(ref.watch(apiClientProvider)));

final salonProfileProvider = FutureProvider.autoDispose.family<SalonProfile, String>((ref, slug) {
  // Re-fetch when auth changes so `isFavorite` is right.
  ref.watch(authControllerProvider.select((s) => s.valueOrNull?.me.user.id));
  return ref.watch(salonRepositoryProvider).profile(slug);
});

final discoverProvider = FutureProvider.autoDispose.family<List<SalonCard>, ({String q, String? category})>((ref, f) {
  ref.watch(authControllerProvider.select((s) => s.valueOrNull?.me.user.id));
  return ref.watch(salonRepositoryProvider).discover(q: f.q, category: f.category);
});

final favoritesProvider = FutureProvider.autoDispose<List<SalonCard>>((ref) => ref.watch(salonRepositoryProvider).discover(favorites: true));
