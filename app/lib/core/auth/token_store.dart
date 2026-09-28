import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Refresh token in the platform keystore (Keychain / Keystore / WebCrypto-backed
/// storage on web). The short-lived access token is kept in memory only.
class TokenStore {
  TokenStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;
  static const _refreshKey = 'glowbook.refresh';
  static const _salonKey = 'glowbook.salon';

  String? accessToken;

  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);
  Future<void> writeRefreshToken(String token) => _storage.write(key: _refreshKey, value: token);

  /// The salon the user last worked in (for owners of several salons). The server
  /// still verifies membership on every request.
  Future<String?> readSalonId() => _storage.read(key: _salonKey);
  Future<void> writeSalonId(String? id) =>
      id == null ? _storage.delete(key: _salonKey) : _storage.write(key: _salonKey, value: id);

  Future<void> clear() async {
    accessToken = null;
    await _storage.delete(key: _refreshKey);
  }
}
