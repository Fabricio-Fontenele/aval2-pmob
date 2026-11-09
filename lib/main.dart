import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;

import 'app/app_theme.dart';
import 'app/lost_and_found_app.dart';
import 'features/auth/data/http_auth_repository.dart';
import 'features/auth/data/secure_session_token_store.dart';
import 'features/auth/presentation/auth_session_notifier.dart';
import 'features/lost_found/data/http_item_repository.dart';

void main() {
  final client = http.Client();
  try {
    final authRepository = HttpAuthRepository.fromEnvironment(
      client: client,
      tokenStore: const SecureSessionTokenStore(),
    );
    runApp(
      LostAndFoundApp(
        authRepository: authRepository,
        itemRepository: HttpItemRepository.fromEnvironment(
          client: client,
          sessionTokens: authRepository,
        ),
        sessionNotifier: AuthSessionNotifier(repository: authRepository),
      ),
    );
  } on StateError catch (error) {
    client.close();
    runApp(_ConfigurationErrorApp(details: error.message));
  } on ArgumentError catch (error) {
    client.close();
    runApp(_ConfigurationErrorApp(details: '${error.message}'));
  }
}

class _ConfigurationErrorApp extends StatelessWidget {
  const _ConfigurationErrorApp({required this.details});

  final String details;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Achados e Perdidos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.settings_ethernet, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Configure o endereço público da API para iniciar o '
                    'aplicativo:',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'flutter run --dart-define=API_BASE_URL=https://...',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(details, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
