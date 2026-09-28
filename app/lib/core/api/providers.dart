import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/token_store.dart';
import 'api_client.dart';

/// Overridden in main() with the loaded instance.
final sharedPrefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError('sharedPrefsProvider not overridden'));

final tokenStoreProvider = Provider<TokenStore>((_) => TokenStore());

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(tokens: ref.watch(tokenStoreProvider)));
