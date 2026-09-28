/// Small helpers for tolerant JSON decoding.
typedef Json = Map<String, dynamic>;

Json asJson(Object? v) => v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
List<Json> asJsonList(Object? v) => v is List ? v.map(asJson).toList() : const [];
DateTime? asDate(Object? v) => v is String ? DateTime.tryParse(v) : null;
DateTime asDateReq(Object? v) => DateTime.parse(v as String);
int asInt(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;
double asDouble(Object? v, [double fallback = 0]) => v is num ? v.toDouble() : fallback;
String? asStr(Object? v) => v is String && v.isNotEmpty ? v : null;
List<String> asStrList(Object? v) => v is List ? v.whereType<String>().toList() : const [];
