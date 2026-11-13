import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/branding.dart';
import '../core/env.dart';
import '../core/theme.dart';
import '../features/onboarding/launch_gate.dart';
import 'config_missing_screen.dart';

/// The root widget. Chooses between the config-missing diagnostic screen and the
/// session-driven auth flow, and applies the shared theme.
///
/// [LaunchGate] shows the branded splash, then routes first-time drivers through
/// onboarding before [AuthGate]; returning drivers go straight to the existing
/// session/role routing.
class SbtfApp extends ConsumerWidget {
  const SbtfApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // With no configuration and no demo flag there is nothing to connect to, so
    // show the diagnosis screen instead of crashing on Supabase.initialize.
    final showConfigMissing =
        !currentEnv.isConfigured && !currentEnv.isDemoMode;

    return MaterialApp(
      title: AppBranding.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home:
          showConfigMissing ? const ConfigMissingScreen() : const LaunchGate(),
    );
  }
}
