import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/models.dart';
import '../api/api_client.dart';
import '../api/providers.dart';
import '../errors/api_exception.dart';

/// Authentication state: who is signed in and which salon she's working in.
class Session {
  const Session({required this.me, this.activeSalonId});
  final Me me;
  final String? activeSalonId;

  Membership? get membership {
    if (me.memberships.isEmpty) return null;
    return me.memberships.firstWhere((m) => m.salonId == activeSalonId, orElse: () => me.memberships.first);
  }

  Session copyWith({Me? me, String? activeSalonId}) => Session(me: me ?? this.me, activeSalonId: activeSalonId ?? this.activeSalonId);
}

class AuthController extends AsyncNotifier<Session?> {
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  Future<Session?> build() async {
    _api.onSessionExpired = () => state = const AsyncData(null);
    // Restore a previous session from the stored refresh token.
    try {
      if (!await _api.restore()) return null;
      return await _loadSession();
    } catch (_) {
      return null;
    }
  }

  Future<Session> _loadSession() async {
    final me = Me.fromJson(asJson(await _api.get<Object?>('/api/me')));
    return _activate(me);
  }

  Future<Session> _activate(Me me) async {
    final tokens = ref.read(tokenStoreProvider);
    final saved = await tokens.readSalonId();
    final active = me.memberships.any((m) => m.salonId == saved) ? saved : me.memberships.firstOrNull?.salonId;
    _api.salonId = active;
    return Session(me: me, activeSalonId: active);
  }

  Future<void> _acceptAuthPayload(Object? data) async {
    final j = asJson(data);
    final tokens = ref.read(tokenStoreProvider);
    tokens.accessToken = j['accessToken'] as String;
    await tokens.writeRefreshToken(j['refreshToken'] as String);
    state = AsyncData(await _activate(Me.fromJson(asJson(j['me']))));
  }

  Future<void> login(String identifier, String password) async {
    await _acceptAuthPayload(await _api.post<Object?>('/api/auth/login', body: {'identifier': identifier, 'password': password}));
  }

  Future<void> register({required String name, required String email, required String password, String? phone, required String locale}) async {
    await _acceptAuthPayload(await _api.post<Object?>('/api/auth/register', body: {
      'name': name,
      'email': email,
      'password': password,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'locale': locale,
    }));
  }

  Future<void> registerSalon({
    required String ownerName,
    required String email,
    required String password,
    required String salonName,
    String? phone,
    String? city,
    required String locale,
  }) async {
    await _acceptAuthPayload(await _api.post<Object?>('/api/auth/register-salon', body: {
      'ownerName': ownerName,
      'email': email,
      'password': password,
      'salonName': salonName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (city != null && city.isNotEmpty) 'city': city,
      'locale': locale,
    }));
  }

  /// Returns the development code when no SMS provider is configured.
  Future<String?> requestOtp(String phone, String locale) async {
    final data = asJson(await _api.post<Object?>('/api/auth/otp/request', body: {'phone': phone, 'locale': locale}));
    return asStr(data['devCode']);
  }

  Future<void> verifyOtp(String phone, String code, {String? name, required String locale}) async {
    await _acceptAuthPayload(await _api.post<Object?>('/api/auth/otp/verify', body: {
      'phone': phone,
      'code': code,
      if (name != null && name.isNotEmpty) 'name': name,
      'locale': locale,
    }));
  }

  /// Returns the development reset token when no email provider is configured.
  Future<String?> forgotPassword(String email) async {
    final data = asJson(await _api.post<Object?>('/api/auth/forgot-password', body: {'email': email}));
    return asStr(data['devResetToken']);
  }

  Future<void> resetPassword(String token, String password) =>
      _api.post<Object?>('/api/auth/reset-password', body: {'token': token, 'password': password});

  Future<void> refreshMe() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final me = Me.fromJson(asJson(await _api.get<Object?>('/api/me')));
    state = AsyncData(current.copyWith(me: me));
  }

  Future<void> updateProfile({String? name, String? locale}) async {
    final me = Me.fromJson(asJson(await _api.patch<Object?>('/api/me', body: {
      'name': ?name,
      'locale': ?locale,
    })));
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(current.copyWith(me: me));
  }

  Future<void> switchSalon(String salonId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await ref.read(tokenStoreProvider).writeSalonId(salonId);
    _api.salonId = salonId;
    state = AsyncData(current.copyWith(activeSalonId: salonId));
  }

  Future<void> logout() async {
    final tokens = ref.read(tokenStoreProvider);
    final refresh = await tokens.readRefreshToken();
    if (refresh != null) {
      try {
        await _api.post<Object?>('/api/auth/logout', body: {'refreshToken': refresh});
      } on ApiException catch (_) {
        // Signing out locally still succeeds.
      }
    }
    await tokens.clear();
    _api.salonId = null;
    state = const AsyncData(null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, Session?>(AuthController.new);

/// The active salon membership (null for customers).
final membershipProvider = Provider<Membership?>((ref) => ref.watch(authControllerProvider).valueOrNull?.membership);

/// Timezone to render salon-side screens in.
final salonTimezoneProvider = Provider<String>((ref) => ref.watch(membershipProvider)?.timezone ?? 'Asia/Muscat');
