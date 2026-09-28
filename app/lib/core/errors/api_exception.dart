/// An error from the Glowbook API, carrying the server's human-readable message.
class ApiException implements Exception {
  const ApiException(this.message, {this.status, this.data, this.offline = false});

  final String message;
  final int? status;
  final Object? data;
  final bool offline;

  bool get isUnauthorized => status == 401;
  bool get isConflict => status == 409;

  /// Field-level validation errors from a 422 response, keyed by field path.
  Map<String, String> get fieldErrors {
    final d = data;
    if (d is Map && d['fields'] is Map) {
      return (d['fields'] as Map).map((k, v) => MapEntry('$k', '$v'));
    }
    return const {};
  }

  @override
  String toString() => message;
}
