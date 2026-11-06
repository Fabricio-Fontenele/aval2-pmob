import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_and_found/app/lost_and_found_app.dart';
import 'package:lost_and_found/features/lost_found/presentation/item_list_screen.dart';

void main() {
  testWidgets('opens the item list screen as the home route', (tester) async {
    await tester.pumpWidget(const LostAndFoundApp());

    expect(find.byType(ItemListScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Achados e Perdidos'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('uses Material 3 with Brazilian Portuguese localization', (
    tester,
  ) async {
    await tester.pumpWidget(const LostAndFoundApp());

    final context = tester.element(find.byType(ItemListScreen));
    expect(Theme.of(context).useMaterial3, isTrue);
    expect(Localizations.localeOf(context), const Locale('pt', 'BR'));
    expect(MaterialLocalizations.of(context).backButtonTooltip, 'Voltar');
  });
}
