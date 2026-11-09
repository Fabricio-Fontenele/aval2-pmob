import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/auth/domain/auth_repository.dart';
import '../features/auth/presentation/auth_session_notifier.dart';
import '../features/lost_found/domain/item_repository.dart';
import '../features/lost_found/presentation/item_list_screen.dart';
import 'app_theme.dart';

/// Application shell: it receives the assembled dependencies and opens the
/// public listing while the stored session is restored in the background.
class LostAndFoundApp extends StatefulWidget {
  const LostAndFoundApp({
    super.key,
    required this.authRepository,
    required this.itemRepository,
    required this.sessionNotifier,
  });

  final AuthRepository authRepository;
  final ItemRepository itemRepository;
  final AuthSessionNotifier sessionNotifier;

  @override
  State<LostAndFoundApp> createState() => _LostAndFoundAppState();
}

class _LostAndFoundAppState extends State<LostAndFoundApp> {
  static const _brazilianPortuguese = Locale('pt', 'BR');

  @override
  void initState() {
    super.initState();
    // Restoring the session is independent from the public listing, so it never
    // delays the first frame. Its dependencies are owned by the entry point.
    widget.sessionNotifier.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Achados e Perdidos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // The interface is only offered in Brazilian Portuguese, so Material
      // widgets must use it regardless of the device language.
      locale: _brazilianPortuguese,
      supportedLocales: const [_brazilianPortuguese],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: ItemListScreen(
        itemRepository: widget.itemRepository,
        authRepository: widget.authRepository,
        sessionNotifier: widget.sessionNotifier,
      ),
    );
  }
}
