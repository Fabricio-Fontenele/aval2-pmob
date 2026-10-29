import 'dart:io';
import 'package:lost_and_found_api/src/config/app_config.dart';
import 'package:lost_and_found_api/src/db/database_client.dart';
import 'package:lost_and_found_api/src/db/migrator.dart';
import 'package:lost_and_found_api/src/server.dart';
import 'package:shelf/shelf_io.dart' as io;

void main(List<String> args) async {
  final config = AppConfig.fromEnvironment();

  DatabaseClient? dbClient;
  if (config.databaseUrl != null && config.databaseUrl!.isNotEmpty) {
    try {
      dbClient = PostgreSqlDatabaseClient.fromUrl(config.databaseUrl!);
      final migrator = DatabaseMigrator(dbClient);
      await migrator.runMigrations();
      print('Database migrations verified successfully.');
    } catch (e) {
      print('Warning: Database initialization or migration failed: $e');
    }
  }

  final handler = buildServerHandler(config, dbClient: dbClient);

  final server = await io.serve(
    handler,
    config.host,
    config.port,
  );

  print(
      'Campus Lost and Found API serving at http://${server.address.host}:${server.port}');
  print('Environment: ${config.environment}');

  ProcessSignal.sigint.watch().listen((_) async {
    print('Shutting down server...');
    if (dbClient != null) {
      await dbClient.close();
    }
    await server.close(force: true);
    exit(0);
  });
}
