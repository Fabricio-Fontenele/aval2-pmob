import 'package:shelf/shelf.dart';
import 'config/app_config.dart';
import 'db/database_client.dart';
import 'middleware/cors.dart';
import 'middleware/error_handler.dart';
import 'routes/api_router.dart';

Handler buildServerHandler(AppConfig config, {DatabaseClient? dbClient}) {
  final router = buildApiRouter(config, dbClient: dbClient);

  final pipeline = const Pipeline()
      .addMiddleware(corsHeaders())
      .addMiddleware(errorHandler())
      .addHandler(router.call);

  return pipeline;
}
