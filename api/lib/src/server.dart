import 'package:shelf/shelf.dart';
import 'auth/data/postgres_session_store.dart';
import 'auth/session_service.dart';
import 'config/app_config.dart';
import 'db/database_client.dart';
import 'middleware/cors.dart';
import 'middleware/error_handler.dart';
import 'routes/api_router.dart';

Handler buildServerHandler(AppConfig config,
    {DatabaseClient? dbClient, SessionService? sessions}) {
  final sessionService = sessions ??
      (dbClient == null
          ? null
          : SessionService(
              store: PostgresSessionStore(dbClient),
              lifetime: Duration(hours: config.sessionTtlHours),
            ));
  final router = buildApiRouter(
    config,
    dbClient: dbClient,
    sessions: sessionService,
  );

  final pipeline = const Pipeline()
      .addMiddleware(corsHeaders())
      .addMiddleware(errorHandler())
      .addHandler(router.call);

  return pipeline;
}
