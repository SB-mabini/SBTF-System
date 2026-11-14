import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'branding.dart';

/// The build that is actually installed on this phone.
///
/// Read from the APK itself (`package_info_plus`) rather than a hardcoded
/// constant, so Settings can tell the driver whether they are current.
class InstalledApp {
  const InstalledApp({required this.version, required this.build});

  final String version;
  final int build;

  String get label => build > 0 ? '$version (build $build)' : version;
}

/// The newest published release, read from the install page manifest that
/// `scripts/publish-install-release.mjs` writes.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.build,
    this.released,
    this.pageUrl = AppUpdateService.installPageUrl,
  });

  final String version;
  final int build;
  final String? released;
  final String pageUrl;

  bool isNewerThan(InstalledApp installed) => build > installed.build;
}

/// Update awareness without a store account.
///
/// The APK is distributed from the public install page, so there is no Play
/// Store in-app update API. Instead the app compares its own build number with
/// `/install/release.json` once per launch. Every failure is silent: the app
/// must remain fully usable offline, and an update prompt is never worth an
/// error dialog.
abstract final class AppUpdateService {
  /// Kept in one place so the install page URL and the manifest cannot drift.
  static const String manifestUrl =
      'https://sbtf-application.vercel.app/install/release.json';
  static const String installPageUrl =
      'https://sbtf-application.vercel.app/install/';

  static const String _dismissedKey = 'app_update_dismissed_build';

  /// Falls back to the compiled-in version when the platform channel is
  /// unavailable (widget tests, unsupported platforms).
  static Future<InstalledApp> installed() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final code = int.tryParse(info.buildNumber) ?? 0;
      return InstalledApp(
        version: info.version.isNotEmpty ? info.version : AppBranding.version,
        build: normalizeBuildCode(code),
      );
    } catch (_) {
      return const InstalledApp(version: AppBranding.version, build: 0);
    }
  }

  /// Android reports the *version code*, and `flutter build apk
  /// --split-per-abi` prefixes that with an ABI digit: build 3 is installed as
  /// 1003 (32-bit), 2003 (arm64) or 4003 (x86_64). Settings and the update
  /// check must compare the pubspec build number (3) with `release.json`, not
  /// the prefixed code, so strip the ABI digit back off.
  ///
  /// Non-split builds (and every other platform) use the build number as-is.
  static int normalizeBuildCode(int code) {
    if (code >= 1000 && code < 10000) return code % 1000;
    return code;
  }

  /// Returns null when offline, when the manifest is malformed, or when the
  /// server answers anything other than 200. The caller simply shows nothing.
  static Future<AppRelease?> latest({http.Client? client}) async {
    final owned = client == null;
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient.get(
        Uri.parse(manifestUrl),
        headers: const {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      final version = decoded['version'];
      final build = int.tryParse('${decoded['build'] ?? ''}');
      final pageUrl = decoded['pageUrl'];
      final released = decoded['released'];

      if (version is! String || version.isEmpty || build == null) return null;

      return AppRelease(
        version: version,
        build: build,
        released: released is String ? released : null,
        pageUrl:
            pageUrl is String && pageUrl.isNotEmpty ? pageUrl : installPageUrl,
      );
    } catch (_) {
      return null;
    } finally {
      if (owned) httpClient.close();
    }
  }

  /// A driver who taps "Later" should not be nagged every launch for the same
  /// build; the next release asks once more.
  static Future<bool> isDismissed(int build) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_dismissedKey) == build;
    } catch (_) {
      return false;
    }
  }

  static Future<void> dismiss(int build) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_dismissedKey, build);
    } catch (_) {
      // Preference storage is best-effort; showing the prompt again is harmless.
    }
  }
}
