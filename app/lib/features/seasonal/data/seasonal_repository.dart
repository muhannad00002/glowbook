import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/providers.dart';
import '../../../shared/models/models.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

/// What a customer pays up front to confirm a token.
enum PrepayMode { full, fixed }

class SeasonalOffering {
  SeasonalOffering({
    required this.id,
    required this.name,
    this.nameAr,
    this.description,
    required this.tokenMinutes,
    required this.capacity,
    required this.priceBaisa,
    required this.prepayMode,
    required this.prepayBaisa,
    this.isActive = true,
    this.sortOrder = 0,
    this.tokenCount = 0,
  });
  final String id;
  final String name;
  final String? nameAr;
  final String? description;
  final int tokenMinutes;
  final int capacity;
  final int priceBaisa;
  final PrepayMode prepayMode;

  /// The amount actually due up front (the full price, or the fixed advance).
  final int prepayBaisa;
  final bool isActive;
  final int sortOrder;
  final int tokenCount;

  String title(String lang) => lang == 'ar' && (nameAr?.isNotEmpty ?? false) ? nameAr! : name;
  bool get paysInFull => prepayMode == PrepayMode.full;

  factory SeasonalOffering.fromJson(Json j) => SeasonalOffering(
    id: j['id'] as String,
    name: j['name'] as String,
    nameAr: asStr(j['nameAr']),
    description: asStr(j['description']),
    tokenMinutes: asInt(j['tokenMinutes']),
    capacity: asInt(j['capacity'], 1),
    priceBaisa: asInt(j['priceBaisa']),
    prepayMode: j['prepayMode'] == 'FIXED' ? PrepayMode.fixed : PrepayMode.full,
    // Public payloads send the effective advance as prepayBaisa; admin payloads add
    // effectivePrepayBaisa next to the stored value.
    prepayBaisa: asInt(j['effectivePrepayBaisa'] ?? j['prepayBaisa']),
    isActive: j['isActive'] != false,
    sortOrder: asInt(j['sortOrder']),
    tokenCount: asInt(j['tokenCount']),
  );
}

class SeasonalEvent {
  SeasonalEvent({
    required this.id,
    required this.name,
    this.nameAr,
    this.description,
    this.descriptionAr,
    required this.startDate,
    required this.endDate,
    required this.openMinute,
    required this.closeMinute,
    this.dates = const [],
    this.timezone = 'Asia/Muscat',
    this.isActive = true,
    required this.offerings,
  });
  final String id;
  final String name;
  final String? nameAr;
  final String? description;
  final String? descriptionAr;
  final String startDate; // YYYY-MM-DD
  final String endDate;
  final int openMinute;
  final int closeMinute;

  /// Days still to come (public payload only).
  final List<String> dates;
  final String timezone;
  final bool isActive;
  final List<SeasonalOffering> offerings;

  String title(String lang) => lang == 'ar' && (nameAr?.isNotEmpty ?? false) ? nameAr! : name;
  String? blurb(String lang) => lang == 'ar' && (descriptionAr?.isNotEmpty ?? false) ? descriptionAr : description;

  factory SeasonalEvent.fromJson(Json j) => SeasonalEvent(
    id: j['id'] as String,
    name: j['name'] as String,
    nameAr: asStr(j['nameAr']),
    description: asStr(j['description']),
    descriptionAr: asStr(j['descriptionAr']),
    startDate: j['startDate'] as String,
    endDate: j['endDate'] as String,
    openMinute: asInt(j['openMinute']),
    closeMinute: asInt(j['closeMinute']),
    dates: (j['dates'] as List?)?.cast<String>() ?? const [],
    timezone: asStr(j['timezone']) ?? 'Asia/Muscat',
    isActive: j['isActive'] != false,
    offerings: asJsonList(j['offerings']).map(SeasonalOffering.fromJson).toList(),
  );
}

class TokenSlot {
  TokenSlot({required this.start, required this.end, required this.capacity, required this.left, required this.firstNumber});
  final DateTime start;
  final DateTime end;
  final int capacity;
  final int left;
  final int firstNumber;
  bool get full => left <= 0;
  factory TokenSlot.fromJson(Json j) => TokenSlot(
    start: asDateReq(j['start']),
    end: asDateReq(j['end']),
    capacity: asInt(j['capacity'], 1),
    left: asInt(j['left']),
    firstNumber: asInt(j['firstNumber'], 1),
  );
}

/// A token as its customer sees it.
class SeasonalToken {
  SeasonalToken({
    required this.id,
    required this.reference,
    required this.number,
    required this.start,
    required this.end,
    required this.status,
    required this.priceBaisa,
    required this.prepayBaisa,
    required this.paidBaisa,
    required this.dueBaisa,
    required this.balanceBaisa,
    this.holdExpiresAt,
    required this.offeringName,
    this.offeringNameAr,
    required this.eventName,
    this.eventNameAr,
    required this.salon,
    required this.timezone,
    this.salonPhone,
    this.salonAddress,
    this.customerName,
  });
  final String id;
  final String reference;
  final int number;
  final DateTime start;
  final DateTime end;

  /// PENDING_PAYMENT, CONFIRMED, ARRIVED, COMPLETED, CANCELLED, NO_SHOW, EXPIRED.
  final String status;
  final int priceBaisa;
  final int prepayBaisa;
  final int paidBaisa;
  final int dueBaisa;
  final int balanceBaisa;
  final DateTime? holdExpiresAt;
  final String offeringName;
  final String? offeringNameAr;
  final String eventName;
  final String? eventNameAr;
  final SalonCard salon;
  final String timezone;
  final String? salonPhone;
  final String? salonAddress;
  final String? customerName;

  bool get awaitingPayment => status == 'PENDING_PAYMENT';
  bool get isLive => const ['PENDING_PAYMENT', 'CONFIRMED', 'ARRIVED'].contains(status);
  String offering(String lang) => lang == 'ar' && (offeringNameAr?.isNotEmpty ?? false) ? offeringNameAr! : offeringName;
  String event(String lang) => lang == 'ar' && (eventNameAr?.isNotEmpty ?? false) ? eventNameAr! : eventName;

  factory SeasonalToken.fromJson(Json j) {
    final offering = asJson(j['offering']);
    final event = asJson(offering['event']);
    final salon = asJson(j['salon']);
    return SeasonalToken(
      id: j['id'] as String,
      reference: j['reference'] as String,
      number: asInt(j['number']),
      start: asDateReq(j['startTime']),
      end: asDateReq(j['endTime']),
      status: j['status'] as String,
      priceBaisa: asInt(j['priceBaisa']),
      prepayBaisa: asInt(j['prepayBaisa']),
      paidBaisa: asInt(j['paidBaisa']),
      dueBaisa: asInt(j['dueBaisa']),
      balanceBaisa: asInt(j['balanceBaisa']),
      holdExpiresAt: asDate(j['holdExpiresAt']),
      offeringName: asStr(offering['name']) ?? '',
      offeringNameAr: asStr(offering['nameAr']),
      eventName: asStr(event['name']) ?? '',
      eventNameAr: asStr(event['nameAr']),
      salon: SalonCard.fromJson(salon),
      timezone: asStr(salon['timezone']) ?? 'Asia/Muscat',
      salonPhone: asStr(salon['phone']),
      salonAddress: asStr(salon['address']),
      customerName: asStr(asJson(j['customer'])['name']),
    );
  }
}

/// A token in the salon's daily queue.
class QueueToken {
  QueueToken({
    required this.id,
    required this.reference,
    required this.number,
    required this.start,
    required this.status,
    required this.paidBaisa,
    required this.balanceBaisa,
    required this.offeringId,
    required this.offeringName,
    this.offeringNameAr,
    required this.customerName,
    this.customerPhone,
    this.notes,
  });
  final String id;
  final String reference;
  final int number;
  final DateTime start;
  final String status;
  final int paidBaisa;
  final int balanceBaisa;
  final String offeringId;
  final String offeringName;
  final String? offeringNameAr;
  final String customerName;
  final String? customerPhone;
  final String? notes;

  String offering(String lang) => lang == 'ar' && (offeringNameAr?.isNotEmpty ?? false) ? offeringNameAr! : offeringName;

  factory QueueToken.fromJson(Json j) {
    final o = asJson(j['offering']);
    final c = asJson(j['customer']);
    return QueueToken(
      id: j['id'] as String,
      reference: j['reference'] as String,
      number: asInt(j['number']),
      start: asDateReq(j['startTime']),
      status: j['status'] as String,
      paidBaisa: asInt(j['paidBaisa']),
      balanceBaisa: asInt(j['balanceBaisa']),
      offeringId: asStr(o['id']) ?? '',
      offeringName: asStr(o['name']) ?? '',
      offeringNameAr: asStr(o['nameAr']),
      customerName: asStr(c['name']) ?? '',
      customerPhone: asStr(c['phone']),
      notes: asStr(j['customerNotes']),
    );
  }
}

class TokenQueue {
  TokenQueue({
    required this.date,
    required this.tokens,
    required this.waiting,
    required this.arrived,
    required this.completed,
    required this.noShow,
    required this.collectedBaisa,
  });
  final String date;
  final List<QueueToken> tokens;
  final int waiting;
  final int arrived;
  final int completed;
  final int noShow;
  final int collectedBaisa;
  factory TokenQueue.fromJson(Json j) {
    final s = asJson(j['summary']);
    return TokenQueue(
      date: j['date'] as String,
      tokens: asJsonList(j['tokens']).map(QueueToken.fromJson).toList(),
      waiting: asInt(s['waiting']),
      arrived: asInt(s['arrived']),
      completed: asInt(s['completed']),
      noShow: asInt(s['noShow']),
      collectedBaisa: asInt(s['collectedBaisa']),
    );
  }
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class SeasonalRepository {
  SeasonalRepository(this._api);
  final ApiClient _api;

  // Public ------------------------------------------------------------------
  Future<List<SeasonalEvent>> events(String salon) async =>
      asJsonList(await _api.get<Object?>('/api/public/seasonal', query: {'salon': salon})).map(SeasonalEvent.fromJson).toList();

  Future<List<TokenSlot>> slots(String offeringId, String date) async =>
      asJsonList(asJson(await _api.get<Object?>('/api/public/seasonal/offerings/$offeringId/slots', query: {'date': date}))['slots'])
          .map(TokenSlot.fromJson)
          .toList();

  /// Holds a token while the customer pays. Returns the token and its link signature.
  Future<({SeasonalToken token, String access})> take({
    required String offeringId,
    required DateTime start,
    required String name,
    required String phone,
    String? phoneToken,
    String? notes,
  }) async {
    final j = asJson(
      await _api.post<Object?>(
        '/api/public/tokens',
        body: {
          'offeringId': offeringId,
          'startTime': start.toUtc().toIso8601String(),
          'customer': {'name': name, 'phone': phone},
          'phoneToken': ?phoneToken,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      ),
    );
    return (token: SeasonalToken.fromJson(asJson(j['token'])), access: j['accessToken'] as String);
  }

  Future<SeasonalToken> token(String id, {String? access}) async =>
      SeasonalToken.fromJson(asJson(await _api.get<Object?>('/api/public/tokens/$id', query: {'token': access})));

  /// Pays the advance. With the sandbox gateway the payment completes in place; a real
  /// gateway would return a checkout page to open instead.
  Future<SeasonalToken> pay(String id, {String? access}) async {
    await _api.post<Object?>('/api/public/tokens/$id/pay', query: {'token': access}, body: const {});
    final j = asJson(await _api.post<Object?>('/api/public/tokens/$id/test-confirm', query: {'token': access}, body: const {}));
    return SeasonalToken.fromJson(asJson(j['token']));
  }

  // Salon admin ---------------------------------------------------------------
  Future<List<SeasonalEvent>> adminEvents() async => asJsonList(await _api.get<Object?>('/api/seasonal/events')).map(SeasonalEvent.fromJson).toList();

  Future<void> saveEvent(String? id, Map<String, dynamic> body) =>
      id == null ? _api.post<Object?>('/api/seasonal/events', body: body) : _api.patch<Object?>('/api/seasonal/events/$id', body: body);

  Future<void> deleteEvent(String id) => _api.delete<Object?>('/api/seasonal/events/$id');

  Future<void> saveOffering({required String eventId, String? id, required Map<String, dynamic> body}) =>
      id == null ? _api.post<Object?>('/api/seasonal/events/$eventId/offerings', body: body) : _api.patch<Object?>('/api/seasonal/offerings/$id', body: body);

  Future<void> deleteOffering(String id) => _api.delete<Object?>('/api/seasonal/offerings/$id');

  Future<TokenQueue> queue({required String date, String? eventId}) async =>
      TokenQueue.fromJson(asJson(await _api.get<Object?>('/api/seasonal/tokens', query: {'date': date, 'eventId': eventId})));

  Future<void> setStatus(String tokenId, String status) => _api.post<Object?>('/api/seasonal/tokens/$tokenId/status', body: {'status': status});
}

final seasonalRepositoryProvider = Provider((ref) => SeasonalRepository(ref.watch(apiClientProvider)));

final salonSeasonalEventsProvider = FutureProvider.autoDispose.family<List<SeasonalEvent>, String>(
  (ref, slug) => ref.watch(seasonalRepositoryProvider).events(slug),
);

final tokenSlotsProvider = FutureProvider.autoDispose.family<List<TokenSlot>, ({String offeringId, String date})>(
  (ref, q) => ref.watch(seasonalRepositoryProvider).slots(q.offeringId, q.date),
);

final seasonalTokenProvider = FutureProvider.autoDispose.family<SeasonalToken, ({String id, String? access})>(
  (ref, q) => ref.watch(seasonalRepositoryProvider).token(q.id, access: q.access),
);

final adminSeasonalEventsProvider = FutureProvider.autoDispose<List<SeasonalEvent>>((ref) => ref.watch(seasonalRepositoryProvider).adminEvents());

final tokenQueueProvider = FutureProvider.autoDispose.family<TokenQueue, ({String date, String? eventId})>(
  (ref, q) => ref.watch(seasonalRepositoryProvider).queue(date: q.date, eventId: q.eventId),
);
