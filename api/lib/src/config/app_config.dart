import 'dart:io';

class AppConfig {
  final int port;
  final String host;
  final String environment;
  final String? databaseUrl;
  final int sessionTtlHours;

  const AppConfig({
    required this.port,
    required this.host,
    required this.environment,
    this.databaseUrl,
    required this.sessionTtlHours,
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

    return AppConfig(
      port: port,
      host: host,
      environment: environment,
      databaseUrl: databaseUrl,
      sessionTtlHours: sessionTtlHours,
    );
  }
}
