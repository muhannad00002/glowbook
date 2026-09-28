import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/providers.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../shared/models/models.dart';

class ServicesRepository {
  ServicesRepository(this._api);
  final ApiClient _api;

  Future<List<Service>> list() async => asJsonList(await _api.get<List<dynamic>>('/api/services')).map(Service.fromJson).toList();
  Future<List<ServiceCategory>> categories() async =>
      asJsonList(await _api.get<List<dynamic>>('/api/service-categories')).map(ServiceCategory.fromJson).toList();
  Future<void> create(Json body) => _api.post<Object?>('/api/services', body: body);
  Future<void> update(String id, Json body) => _api.patch<Object?>('/api/services/$id', body: body);
  Future<void> delete(String id) => _api.delete<Object?>('/api/services/$id');
  Future<void> createCategory(String name, String? nameAr) => _api.post<Object?>('/api/service-categories', body: {'name': name, 'nameAr': nameAr});
}

final servicesRepositoryProvider = Provider((ref) => ServicesRepository(ref.watch(apiClientProvider)));

final servicesProvider = FutureProvider.autoDispose<List<Service>>((ref) {
  ref.watch(membershipProvider.select((m) => m?.salonId));
  return ref.watch(servicesRepositoryProvider).list();
});

final serviceCategoriesProvider = FutureProvider.autoDispose<List<ServiceCategory>>((ref) {
  ref.watch(membershipProvider.select((m) => m?.salonId));
  return ref.watch(servicesRepositoryProvider).categories();
});
