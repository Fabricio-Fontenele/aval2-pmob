import 'package:lost_and_found_api/src/db/database_client.dart';
import 'package:postgres/postgres.dart';

class ConnectionDatabaseClient implements DatabaseClient {
  final Connection connection;

  ConnectionDatabaseClient(this.connection);

  @override
  Future<bool> checkConnection() async => connection.isOpen;

  @override
  Future<Result> execute(String query, {Map<String, Object?>? parameters}) {
    return connection.execute(Sql.named(query), parameters: parameters);
  }

  @override
  Future<void> close() => connection.close();
}
