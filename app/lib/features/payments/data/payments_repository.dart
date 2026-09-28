import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../shared/models/models.dart';

class PaymentsPage {
  PaymentsPage({required this.items, required this.collected, required this.refunded, required this.net, required this.owed, required this.byMethod});
  final List<Payment> items;
  final int collected;
  final int refunded;
  final int net;
  final int owed;
  final Map<String, int> byMethod;
}

final paymentsProvider = FutureProvider.autoDispose.family<PaymentsPage, ({String from, String to})>((ref, r) async {
  ref.watch(membershipProvider.select((m) => m?.salonId));
  final j = asJson(await ref.watch(apiClientProvider).get<Object?>('/api/payments', query: {'from': r.from, 'to': r.to, 'limit': '300'}));
  final t = asJson(j['totals']);
  return PaymentsPage(
    items: asJsonList(j['items']).map(Payment.fromJson).toList(),
    collected: asInt(t['collectedBaisa']),
    refunded: asInt(t['refundedBaisa']),
    net: asInt(t['netBaisa']),
    owed: asInt(t['owedRefundsBaisa']),
    byMethod: asJson(t['byMethod']).map((k, v) => MapEntry(k, asInt(v))),
  );
});

Future<void> settleRefund(WidgetRef ref, String paymentId, String method) =>
    ref.read(apiClientProvider).post<Object?>('/api/payments/$paymentId/settle', body: {'method': method});
