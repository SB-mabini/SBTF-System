import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/l10n/app_localizations.dart';
import 'package:sbtf_mobile/core/l10n/translations_fil.dart';
import 'package:sbtf_mobile/core/ui.dart';

void main() {
  group('translation engine', () {
    test('English is returned untouched', () {
      const l10n = AppLocalizations('en');
      expect(l10n.t('Home'), 'Home');
      expect(l10n.t('Documents'), 'Documents');
    });

    test('exact UI strings translate', () {
      const l10n = AppLocalizations('fil');
      expect(l10n.t('Home'), 'Tahanan');
      expect(l10n.t('Settings'), 'Mga Setting');
      expect(l10n.t('Documents'), 'Mga Dokumento');
      expect(l10n.t('Log out'), 'Mag-logout');
      expect(l10n.t('Plate number'), 'Numero ng plaka');
    });

    test('interpolated strings keep their values', () {
      const l10n = AppLocalizations('fil');
      expect(l10n.t('Accepted 12 Nov 2026'), 'Tinanggap 12 Nob 2026');
      expect(l10n.t('Submitted 15 Oct 2026, 2:30 PM'),
          contains('Isinumite'));
      expect(l10n.t('Reference number: ENG-12345'),
          contains('ENG-12345'));
    });

    test('typographic punctuation still matches dictionary keys', () {
      expect(
        translateToFilipino('Step 1 of 3 \u2014 Language'),
        'Hakbang 1 ng 3 - Wika',
      );
    });

    test('long agreement paragraphs translate', () {
      const paragraph =
          'Access to the MTOP System is limited to drivers, operators and '
          'authorized Sangguniang Bayan personnel who need it for franchising '
          'and tricycle driver registration.';
      expect(
        translateToFilipino(paragraph),
        startsWith('Ang access sa MTOP System ay limitado'),
      );
    });

    test('unknown strings are left alone', () {
      expect(translateToFilipino('ABC 1234'), 'ABC 1234');
    });
  });

  group('context translator', () {
    testWidgets('Filipino locale renders Filipino text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fil'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.delegates,
          home: Scaffold(body: Text('Home')),
        ),
      );

      expect(find.text('Tahanan'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
    });

    testWidgets('bare MaterialApp keeps English', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Home'))),
      );

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('server content can opt out of translation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fil'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.delegates,
          home: Scaffold(
            body: Text('Documents', translate: false),
          ),
        ),
      );

      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Mga Dokumento'), findsNothing);
    });

    test('context-free helper follows the current language', () {
      addTearDown(() => currentLanguageCode.value = 'en');
      currentLanguageCode.value = 'fil';
      expect(tr('Settings'), 'Mga Setting');
      currentLanguageCode.value = 'en';
      expect(tr('Settings'), 'Settings');
    });
  });
}
