import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/lost_found/presentation/item_list_screen.dart';
import 'app_theme.dart';

class LostAndFoundApp extends StatelessWidget {
  const LostAndFoundApp({super.key});

  static const _brazilianPortuguese = Locale('pt', 'BR');

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
      home: const ItemListScreen(),
    );
  }
}
