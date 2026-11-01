import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../auth/account_http.dart';
import '../auth/auth_attempt_limiter.dart';
import '../auth/auth_service.dart';
import '../auth/session_http.dart';
import '../auth/session_service.dart';
import '../config/app_config.dart';
import '../db/database_client.dart';

Router buildApiRouter(AppConfig config,
    {DatabaseClient? dbClient,
    SessionService? sessions,
    AuthService? auth,
    AuthAttemptLimiter? authAttempts}) {
  final router = Router();

  final accounts = AccountEndpoints(
    auth: auth,
    attempts: authAttempts ??
        AuthAttemptLimiter(
          registerLimit: config.authRegisterLimit,
          loginEmailLimit: config.authLoginEmailLimit,
          loginAddressLimit: config.authLoginAddressLimit,
        ),
    trustedProxies: config.trustedProxyAddresses,
  );
  router.post('/auth/register', accounts.register);
  router.post('/auth/login', accounts.login);

  router.get('/auth/session', buildSessionHandler(sessions));
  router.post('/auth/logout', buildLogoutHandler(sessions));

  router.get('/health', (Request request) async {
    String dbStatus = 'not_configured';
    var isHealthy = true;

    if (dbClient != null) {
      final isConnected = await dbClient.checkConnection();
      dbStatus = isConnected ? 'connected' : 'disconnected';
      if (!isConnected) {
        isHealthy = false;
      }
    }

    final statusCode = isHealthy ? 200 : 503;
    final statusText = isHealthy ? 'ok' : 'degraded';

    return Response(
      statusCode,
      body: jsonEncode({
        'status': statusText,
        'environment': config.environment,
        'database': dbStatus,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      }),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  router.all('/<ignored|.*>', (Request request) {
    return Response.notFound(
      jsonEncode({
        'error': 'Not Found: ${request.method} /${request.url.path}',
        'statusCode': 404,
      }),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  return router;
}
