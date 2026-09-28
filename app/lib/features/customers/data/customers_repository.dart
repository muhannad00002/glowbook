import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/providers.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../shared/models/models.dart';

class CustomersRepository {
  CustomersRepository(this._api);
  final ApiClient _api;

  Future<List<CustomerSummary>> search(String q) async {
    final data = asJson(await _api.get<Object?>('/api/customers', query: {'q': q.isEmpty ? null : q, 'limit': '60'}));
    return asJsonList(data['items']).map(CustomerSummary.fromJson).toList();
  }

  Future<CustomerProfile> profile(String id) async => CustomerProfile.fromJson(asJson(await _api.get<Object?>('/api/customers/$id')));

  Future<String> create(Json body) async => asJson(await _api.post<Object?>('/api/customers', body: body))['id'] as String;

  Future<void> update(String id, Json body) => _api.patch<Object?>('/api/customers/$id', body: body);
}

final customersRepositoryProvider = Provider((ref) => CustomersRepository(ref.watch(apiClientProvider)));

final customerSearchProvider = FutureProvider.autoDispose.family<List<CustomerSummary>, String>((ref, q) async {
  ref.watch(membershipProvider.select((m) => m?.salonId));
  return ref.watch(customersRepositoryProvider).search(q);
});

final customerProfileProvider = FutureProvider.autoDispose.family<CustomerProfile, String>(
  (ref, id) => ref.watch(customersRepositoryProvider).profile(id),
);
