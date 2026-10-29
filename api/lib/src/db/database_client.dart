import 'dart:async';
import 'package:postgres/postgres.dart';

abstract interface class DatabaseClient {
  Future<bool> checkConnection();
  Future<Result> execute(String query, {Map<String, dynamic>? parameters});
  Future<void> close();
}

class PostgreSqlDatabaseClient implements DatabaseClient {
  final Pool<dynamic> _pool;

  PostgreSqlDatabaseClient._(this._pool);

  factory PostgreSqlDatabaseClient.fromUrl(String databaseUrl) {
    final endpoint = parseEndpoint(databaseUrl);
    final sslMode = resolveSslMode(databaseUrl);

    final pool = Pool<dynamic>.withEndpoints(
      [endpoint],
      settings: PoolSettings(sslMode: sslMode),
    );

    return PostgreSqlDatabaseClient._(pool);
  }

  static Endpoint parseEndpoint(String connectionUrl) {
    final uri = Uri.parse(connectionUrl);

    final userInfo = uri.userInfo.split(':');
    final username = userInfo.isNotEmpty && userInfo[0].isNotEmpty
        ? Uri.decodeComponent(userInfo[0])
        : null;
    final password =
        userInfo.length > 1 ? Uri.decodeComponent(userInfo[1]) : null;

    final database =
        uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;

    return Endpoint(
      host: uri.host,
      port: uri.hasPort ? uri.port : 5432,
      database: database.isEmpty ? 'postgres' : database,
      username: username,
      password: password,
    );
  }

  static SslMode resolveSslMode(String connectionUrl) {
    final uri = Uri.parse(connectionUrl);
    final modeParam = uri.queryParameters['sslmode']?.toLowerCase();

    if (modeParam == 'disable') {
      return SslMode.disable;
    }
    return SslMode.require;
  }

  @override
  Future<bool> checkConnection() async {
    try {
      final result = await _pool.execute('SELECT 1;');
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<Result> execute(String query, {Map<String, dynamic>? parameters}) {
    return _pool.execute(Sql.named(query), parameters: parameters);
  }

  @override
  Future<void> close() => _pool.close();
}

class FakeDatabaseClient implements DatabaseClient {
  bool isConnected;

  FakeDatabaseClient({this.isConnected = true});

  @override
  Future<bool> checkConnection() async => isConnected;

  @override
  Future<Result> execute(String query,
      {Map<String, dynamic>? parameters}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> close() async {}
}
