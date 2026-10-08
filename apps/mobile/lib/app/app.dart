import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/env.dart';
import '../core/theme.dart';
import '../features/auth/auth_gate.dart';
import 'config_missing_screen.dart';

/// The root widget. Chooses between the config-missing diagnostic screen and the
/// session-driven [AuthGate], and applies the shared theme.
class SbtfApp extends ConsumerWidget {
  const SbtfApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // With no configuration and no demo flag there is nothing to connect to, so
    // show the diagnosis screen instead of crashing on Supabase.initialize.
    final showConfigMissing =
        !currentEnv.isConfigured && !currentEnv.isDemoMode;

    return MaterialApp(
      title: 'SBTF Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: showConfigMissing ? const ConfigMissingScreen() : const AuthGate(),
    );
  }
}
