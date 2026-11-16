import 'package:sbtf_mobile/core/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/branding.dart';
import '../../core/onboarding/language.dart';
import '../../core/onboarding/onboarding_state.dart';
import '../../core/onboarding/onboarding_store.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/update_service.dart';
import '../../core/widgets/brand_mark.dart';
import '../onboarding/full_agreement_screen.dart';
import '../onboarding/onboarding_flow.dart';

/// Settings: language, User Agreement status, and app information.
///
/// Language and agreement acceptance are device preferences owned by
/// [OnboardingStore]; this screen reads and writes the same store the onboarding
/// flow uses, so a change here is reflected on the next launch.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late OnboardingStore _store;
  late OnboardingState _state;
  bool _loaded = false;
  String _versionLabel = AppBranding.version;
  bool _checkingUpdates = false;

  @override
  void initState() {
    super.initState();
    _store = ref.read(onboardingStoreProvider);
    _state = _store.state;
    _load();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final installed = await AppUpdateService.installed();
    if (!mounted) return;
    setState(() => _versionLabel = installed.label);
  }

  /// Manual counterpart to the home-screen prompt: tells the driver whether a
  /// newer build exists and opens the install page when it does.
  Future<void> _checkForUpdates() async {
    if (_checkingUpdates) return;
    setState(() => _checkingUpdates = true);
    try {
      final installed = await AppUpdateService.installed();
      final latest = await AppUpdateService.latest();
      if (!mounted) return;

      final l10n = ref.read(appLocalizationsProvider);

      if (latest == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.settingsCouldNotCheckUpdates),
          ),
        );
        return;
      }

      if (!latest.isNewerThan(installed)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.latestVersionLabel(installed.label)),
          ),
        );
        return;
      }

      final open = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.settingsUpdateAvailable),
          content: Text(
            l10n.updateAvailableContent(latest.version, latest.build),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.settingsLater),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.settingsOpenInstallPage),
            ),
          ],
        ),
      );

      if (open != true) return;
      await launchUrl(
        Uri.parse(latest.pageUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      if (!mounted) return;
      final l10n = ref.read(appLocalizationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsCouldNotCheckUpdatesShort)),
      );
    } finally {
      if (mounted) setState(() => _checkingUpdates = false);
    }
  }

  Future<void> _load() async {
    final state = await _store.load();
    if (!mounted) return;
    setState(() {
      _state = state;
      _loaded = true;
    });
  }

  Future<void> _setLanguage(String code) async {
    await _store.setLanguage(code);
    if (!mounted) return;
    setState(() => _state = _store.state);
    // Update the reactive provider so the entire app re-renders immediately.
    ref.read(languageCodeProvider.notifier).state = code;
  }

  void _openAgreement() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const FullAgreementScreen()),
    );
  }

  Future<void> _reviewOutdatedAgreement() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OnboardingFlow(
          store: _store,
          initialPage: OnboardingStep.agreement,
          onFinished: () {
            if (!mounted) return;
            setState(() => _state = _store.state);
            Navigator.of(context).maybePop();
          },
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _state = _store.state);
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // The AuthGate re-evaluates on the next auth event regardless.
    }
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final acceptedAt = _state.agreementAcceptedAt?.toLocal();
    final l10n = ref.watch(appLocalizationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.sm),
              children: [
                // --- Identity ---
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Row(
                      children: [
                        const BrandMark(size: 52),
                        const SizedBox(width: AppSpacing.sm),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppBranding.appName,
                                style: TextStyle(
                                  color: AppColors.inkStrong,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                AppBranding.officeName,
                                style: TextStyle(
                                  color: AppColors.inkMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                _SectionLabel(l10n.settingsPreferences),
                const SizedBox(height: AppSpacing.xs),
                Card(
                  child: Column(
                    children: [
                      for (final language in AppLanguages.supported)
                        ListTile(
                          leading: const Icon(Icons.translate_outlined),
                          title: Text(language.displayName),
                          subtitle: Text(
                            language.code == _state.languageCode
                                ? l10n.settingsCurrentLanguage
                                : l10n.settingsTapToUse,
                          ),
                          trailing: language.code == _state.languageCode
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.primary,
                                )
                              : null,
                          onTap: language.code == _state.languageCode
                              ? null
                              : () => _setLanguage(language.code),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.settingsOnlyFullLanguages,
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                _SectionLabel(l10n.settingsUserAgreement),
                const SizedBox(height: AppSpacing.xs),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          _state.agreementIsCurrent
                              ? Icons.verified_user_outlined
                              : Icons.gpp_maybe_outlined,
                          color: _state.agreementIsCurrent
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                        title: Text(
                          'Version ${AppBranding.agreementVersion}',
                        ),
                        subtitle: Text(
                          _state.agreementIsCurrent
                              ? acceptedAt == null
                                  ? l10n.settingsAccepted
                                  : '${l10n.settingsAccepted} ${_formatDate(acceptedAt)}'
                              : l10n.settingsAcceptanceRequired,
                        ),
                        trailing: _state.agreementIsCurrent
                            ? const Icon(
                                Icons.check_circle,
                                color: AppColors.success,
                              )
                            : const Icon(
                                Icons.chevron_right,
                                color: AppColors.inkMuted,
                              ),
                        onTap: _state.agreementIsCurrent
                            ? _openAgreement
                            : _reviewOutdatedAgreement,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.menu_book_outlined),
                        title: Text(l10n.settingsReadAgreement),
                        subtitle: const Text(
                          'Effective ${AppBranding.agreementEffectiveDate}',
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.inkMuted,
                        ),
                        onTap: _openAgreement,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                _SectionLabel(l10n.settingsAbout),
                const SizedBox(height: AppSpacing.xs),
                Card(
                  child: Column(
                    children: [
                      const ListTile(
                        leading: Icon(Icons.account_balance_outlined),
                        title: Text(AppBranding.officeName),
                        subtitle: Text(AppBranding.location),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: Text(l10n.settingsAppVersion),
                        subtitle: Text(
                          _versionLabel +
                              (_loaded
                                  ? ' · ${_state.language.toUpperCase()}'
                                  : ''),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: _checkingUpdates
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.system_update_alt),
                        title: Text(l10n.settingsCheckUpdates),
                        subtitle: Text(l10n.settingsCheckUpdatesSubtitle),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.inkMuted,
                        ),
                        onTap: _checkingUpdates ? null : _checkForUpdates,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.public_outlined),
                        title: Text(l10n.settingsWebAddress),
                        subtitle: const Text(AppBranding.publicUrl),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  AppBranding.longName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 11.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout, size: 18),
                  label: Text(l10n.settingsLogOut),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(
                      color: AppColors.danger.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.inkMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

String _formatDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}
