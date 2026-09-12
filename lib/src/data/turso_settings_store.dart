import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TursoSettings {
  const TursoSettings({required this.databaseUrl, required this.authToken});

  static const defaultDatabaseUrl =
      'libsql://nabu-leolira1.aws-us-east-2.turso.io';

  final String databaseUrl;
  final String authToken;

  bool get isConfigured => databaseUrl.isNotEmpty && authToken.isNotEmpty;
}

class TursoSettingsStore {
  static const _databaseUrlKey = 'nabu.turso.database_url';
  static const _authTokenKey = 'nabu.turso.auth_token';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<TursoSettings> load() async {
    final values = await _storage.readAll();
    return TursoSettings(
      databaseUrl:
          values[_databaseUrlKey] ?? TursoSettings.defaultDatabaseUrl,
      authToken: values[_authTokenKey] ?? '',
    );
  }

  Future<void> save(TursoSettings settings) async {
    await _storage.write(
      key: _databaseUrlKey,
      value: settings.databaseUrl.trim(),
    );
    await _storage.write(
      key: _authTokenKey,
      value: settings.authToken.trim(),
    );
  }
}
