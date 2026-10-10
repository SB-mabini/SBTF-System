import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/env.dart';
import '../core/theme.dart';

/// Shown when the app was built without `--dart-define` configuration.
///
/// Rather than crashing or showing a blank screen, the app explains exactly what
/// is missing and prints the precise run command, so the developer can copy it
/// and re-run. This is a development/diagnostic screen, never shown in a
/// correctly configured build.
class ConfigMissingScreen extends StatelessWidget {
  const ConfigMissingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuration required')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.md),
                  const Icon(Icons.build_circle_outlined,
                      size: 40, color: AppColors.inkMuted),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Supabase is not configured',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkStrong,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'This build has no Supabase project URL or publishable key, '
                    'so it cannot connect to the database. Pass both values at '
                    'build time with --dart-define. Only publishable values are '
                    'needed; the anon key is safe to ship because Row Level '
                    'Security enforces access.',
                    style: TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.greyFill,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppSpacing.unit),
                    ),
                    child: SelectableText(
                      runCommand,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: AppColors.inkStrong,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: runCommand));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle_outlined,
                                  color: Colors.white, size: 20),
                              SizedBox(width: AppSpacing.xs),
                              Text('Run command copied'),
                            ],
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('Copy run command'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Where to find the values:\n'
                    '• SUPABASE_URL — Supabase Dashboard → Project Settings → API\n'
                    '• SUPABASE_ANON_KEY — the publishable (anon) key on the same page',
                    style: TextStyle(
                      color: AppColors.inkMuted,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
