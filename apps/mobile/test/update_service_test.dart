import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sbtf_mobile/core/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('normalizeBuildCode', () {
    test('leaves a plain build number alone', () {
      expect(AppUpdateService.normalizeBuildCode(3), 3);
      expect(AppUpdateService.normalizeBuildCode(0), 0);
    });

    test('strips the ABI digit from split-APK version codes', () {
      // flutter build apk --split-per-abi prefixes the pubspec build number.
      expect(AppUpdateService.normalizeBuildCode(1003), 3);
      expect(AppUpdateService.normalizeBuildCode(2003), 3);
      expect(AppUpdateService.normalizeBuildCode(4003), 3);
    });
  });

  group('AppRelease', () {
    const installed = InstalledApp(version: '0.1.0', build: 3);

    test('is newer only when the build number grows', () {
      expect(
        const AppRelease(version: '0.1.0', build: 4).isNewerThan(installed),
        isTrue,
      );
      expect(
        const AppRelease(version: '0.1.0', build: 3).isNewerThan(installed),
        isFalse,
      );
      expect(
        const AppRelease(version: '0.1.0', build: 2).isNewerThan(installed),
        isFalse,
      );
    });
  });

  group('AppUpdateService.latest', () {
    test('parses the published manifest', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), AppUpdateService.manifestUrl);
        return http.Response(
          '{"version":"0.1.0","build":"4","released":"20 Nov 2026",'
          '"pageUrl":"https://example.test/install/"}',
          200,
        );
      });

      final release = await AppUpdateService.latest(client: client);
      expect(release, isNotNull);
      expect(release!.build, 4);
      expect(release.version, '0.1.0');
      expect(release.released, '20 Nov 2026');
      expect(release.pageUrl, 'https://example.test/install/');
    });

    test('keeps the install page default when pageUrl is absent', () async {
      final client = MockClient(
        (_) async => http.Response('{"version":"0.1.0","build":"4"}', 200),
      );

      final release = await AppUpdateService.latest(client: client);
      expect(release?.pageUrl, AppUpdateService.installPageUrl);
    });

    test('returns null for a non-200 response', () async {
      final client = MockClient((_) async => http.Response('nope', 503));
      expect(await AppUpdateService.latest(client: client), isNull);
    });

    test('returns null for malformed or incomplete JSON', () async {
      for (final body in ['not json', '[]', '{"version":"0.1.0"}']) {
        final client = MockClient((_) async => http.Response(body, 200));
        expect(
          await AppUpdateService.latest(client: client),
          isNull,
          reason: 'body: $body',
        );
      }
    });
  });

  group('dismissal', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('remembers the dismissed build only', () async {
      expect(await AppUpdateService.isDismissed(4), isFalse);
      await AppUpdateService.dismiss(4);
      expect(await AppUpdateService.isDismissed(4), isTrue);
      expect(await AppUpdateService.isDismissed(5), isFalse);
    });
  });
}
