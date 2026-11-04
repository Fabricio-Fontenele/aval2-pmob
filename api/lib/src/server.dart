import 'package:shelf/shelf.dart';
import 'auth/auth_attempt_limiter.dart';
import 'auth/auth_service.dart';
import 'auth/data/postgres_account_store.dart';
import 'auth/data/postgres_session_store.dart';
import 'auth/session_service.dart';
import 'config/app_config.dart';
import 'db/database_client.dart';
import 'items/data/postgres_item_store.dart';
import 'items/domain/item_store.dart';
import 'middleware/cors.dart';
import 'middleware/error_handler.dart';
import 'routes/api_router.dart';

Handler buildServerHandler(AppConfig config,
    {DatabaseClient? dbClient,
    SessionService? sessions,
    AuthService? auth,
    AuthAttemptLimiter? authAttempts,
    ItemStore? itemStore}) {
  final sessionService = sessions ??
      (dbClient == null
          ? null
          : SessionService(
              store: PostgresSessionStore(dbClient),
              lifetime: Duration(hours: config.sessionTtlHours),
            ));
  final items =
      itemStore ?? (dbClient == null ? null : PostgresItemStore(dbClient));

  final router = buildApiRouter(
    config,
    dbClient: dbClient,
    sessions: sessionService,
    auth: auth ??
        (dbClient == null || sessionService == null
            ? null
            : AuthService(
                accounts: PostgresAccountStore(dbClient),
                sessions: sessionService,
                maxConcurrentOperations: config.authMaxConcurrent,
              )),
    authAttempts: authAttempts,
    itemStore: items,
  );

  final pipeline = const Pipeline()
      .addMiddleware(corsHeaders())
      .addMiddleware(errorHandler())
      .addHandler(router.call);

  return pipeline;
}
