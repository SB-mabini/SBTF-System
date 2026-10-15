import 'package:url_launcher/url_launcher.dart';

/// Opens [url] with the platform's default handler.
typedef UrlLauncher = Future<bool> Function(Uri url);

/// The default launcher: hands the URL to the system browser (or whichever app
/// registered the scheme).
///
/// `externalApplication` is deliberate — a certificate PDF and the public
/// verification page belong in the browser, not in an in-app web view.
Future<bool> launchInBrowser(Uri url) {
  return launchUrl(url, mode: LaunchMode.externalApplication);
}
