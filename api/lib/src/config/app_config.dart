import 'dart:io';

class AppConfig {
  final int port;
  final String host;
  final String environment;
  final String? databaseUrl;
  final int sessionTtlHours;
  final int authRegisterLimit;
  final int authLoginEmailLimit;
  final int authLoginAddressLimit;
  final int authMaxConcurrent;
  final Set<String> trustedProxyAddresses;

  const AppConfig({
    required this.port,
    required this.host,
    required this.environment,
    this.databaseUrl,
    required this.sessionTtlHours,
    this.authRegisterLimit = 5,
    this.authLoginEmailLimit = 5,
    this.authLoginAddressLimit = 20,
    this.authMaxConcurrent = 2,
    this.trustedProxyAddresses = const {},
  });

  bool get isProduction => environment == 'production';

  factory AppConfig.fromEnvironment([Map<String, String>? env]) {
    final environmentMap = env ?? Platform.environment;

    final port = int.tryParse(environmentMap['PORT'] ?? '') ?? 8080;
    final host = environmentMap['HOST'] ?? '0.0.0.0';
    final environment = environmentMap['ENVIRONMENT'] ?? 'development';
    final databaseUrl = environmentMap['DATABASE_URL'];
    final sessionTtlHours =
        int.tryParse(environmentMap['SESSION_TTL_HOURS'] ?? '') ?? 24;
    if (sessionTtlHours < 1) {
      throw const FormatException('SESSION_TTL_HOURS must be positive');
    }
    final trustedProxies = <String>{};
    for (final entry
        in (environmentMap['TRUSTED_PROXY_IPS'] ?? '').split(',')) {
      if (entry.trim().isEmpty) continue;
      final address = InternetAddress.tryParse(entry.trim());
      if (address == null) {
        throw const FormatException(
            'TRUSTED_PROXY_IPS must contain IP addresses');
      }
      trustedProxies.add(address.address);
    }

    return AppConfig(
      port: port,
      host: host,
      environment: environment,
      databaseUrl: databaseUrl,
      sessionTtlHours: sessionTtlHours,
      authRegisterLimit: _positiveInt(environmentMap, 'AUTH_REGISTER_LIMIT', 5),
      authLoginEmailLimit:
          _positiveInt(environmentMap, 'AUTH_LOGIN_EMAIL_LIMIT', 5),
      authLoginAddressLimit:
          _positiveInt(environmentMap, 'AUTH_LOGIN_ADDRESS_LIMIT', 20),
      authMaxConcurrent: _positiveInt(environmentMap, 'AUTH_MAX_CONCURRENT', 2),
      trustedProxyAddresses: Set.unmodifiable(trustedProxies),
    );
  }

  static int _positiveInt(Map<String, String> env, String key, int fallback) {
    final raw = env[key];
    if (raw == null) return fallback;
    final value = int.tryParse(raw);
    if (value == null || value < 1) {
      throw FormatException('$key must be positive');
    }
    return value;
  }
}
