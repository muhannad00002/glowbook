import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/token_store.dart';
import '../constants/env.dart';
import '../errors/api_exception.dart';

/// The one gateway between the app and the Glowbook API.
///
/// - Unwraps the `{ success, data, message }` envelope and throws [ApiException].
/// - Attaches the bearer token, the active salon hint and the UI language.
/// - On 401 refreshes the session once (single-flight) and replays the request.
/// - Retries idempotent GETs once on network failure.
class ApiClient {
  ApiClient({required this.tokens, String? baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? Env.apiBaseUrl,
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 25),
          sendTimeout: const Duration(seconds: 25),
          contentType: 'application/json',
          responseType: ResponseType.json,
          // We read the envelope ourselves for every status.
          validateStatus: (_) => true,
        ));

  final Dio _dio;
  final TokenStore tokens;

  String? salonId;
  String locale = 'en';

  /// Called when the refresh token is rejected — the app signs the user out.
  void Function()? onSessionExpired;

  Future<bool>? _refreshing;

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) => _send<T>('GET', path, query: query);
  Future<T> post<T>(String path, {Object? body, Map<String, dynamic>? query}) =>
      _send<T>('POST', path, body: body ?? const {}, query: query);
  Future<T> patch<T>(String path, {Object? body}) => _send<T>('PATCH', path, body: body);
  Future<T> put<T>(String path, {Object? body}) => _send<T>('PUT', path, body: body);
  Future<T> delete<T>(String path, {Object? body}) => _send<T>('DELETE', path, body: body);

  /// Like [post] but returns the envelope message too (for success toasts).
  Future<(T, String?)> postWithMessage<T>(String path, {Object? body}) async {
    final res = await _raw('POST', path, body: body ?? const {});
    return (res.data as T, res.message);
  }

  /// A FormData can only be sent once; a retry needs a fresh copy.
  Object? _again(Object? body) => body is FormData ? body.clone() : body;

  Future<T> _send<T>(String method, String path, {Object? body, Map<String, dynamic>? query}) async {
    final res = await _raw(method, path, body: body, query: query);
    return res.data as T;
  }

  Future<({Object? data, String? message})> _raw(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool retried = false,
    int attempt = 0,
  }) async {
    Response<dynamic> res;
    try {
      res = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query?..removeWhere((_, v) => v == null),
        // Uploads go as multipart; everything else is JSON (the client default).
        options: Options(method: method, headers: _headers(), contentType: body is FormData ? 'multipart/form-data' : null),
      );
    } on DioException catch (e) {
      final network = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout;
      if (network && method == 'GET' && attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        return _raw(method, path, body: _again(body), query: query, retried: retried, attempt: 1);
      }
      throw ApiException('offline', offline: network, status: e.response?.statusCode);
    }

    final status = res.statusCode ?? 0;
    final json = res.data is Map ? res.data as Map : const {};

    if (status == 401 && !retried && !path.startsWith('/api/auth/')) {
      if (await _refresh()) {
        return _raw(method, path, body: _again(body), query: query, retried: true, attempt: attempt);
      }
      // The session is over: drop the stale token and sign out. Public endpoints (the
      // booking page) still work, so replay once as a guest.
      final hadToken = tokens.accessToken != null;
      tokens.accessToken = null;
      onSessionExpired?.call();
      if (hadToken) return _raw(method, path, body: _again(body), query: query, retried: true, attempt: attempt);
    }

    if (status >= 200 && status < 300 && json['success'] == true) {
      return (data: json['data'], message: json['message'] as String?);
    }
    throw ApiException(
      (json['message'] as String?) ?? 'Something went wrong (HTTP $status).',
      status: status,
      data: json['data'],
    );
  }

  Map<String, String> _headers() => {
        if (tokens.accessToken != null) 'Authorization': 'Bearer ${tokens.accessToken}',
        'X-Salon-Id': ?salonId,
        'Accept-Language': locale,
      };

  /// Single-flight refresh: concurrent 401s share one refresh round-trip.
  Future<bool> _refresh() {
    return _refreshing ??= () async {
      try {
        final token = await tokens.readRefreshToken();
        if (token == null) return false;
        final res = await _dio.post<dynamic>('/api/auth/refresh', data: {'refreshToken': token});
        final json = res.data is Map ? res.data as Map : const {};
        if (res.statusCode == 200 && json['success'] == true) {
          final data = json['data'] as Map;
          tokens.accessToken = data['accessToken'] as String;
          await tokens.writeRefreshToken(data['refreshToken'] as String);
          return true;
        }
        return false;
      } catch (_) {
        return false;
      } finally {
        // Let the next expiry trigger a fresh refresh.
        scheduleMicrotask(() => _refreshing = null);
      }
    }();
  }

  /// Used at startup to restore a session from the stored refresh token.
  Future<bool> restore() => _refresh();
}
