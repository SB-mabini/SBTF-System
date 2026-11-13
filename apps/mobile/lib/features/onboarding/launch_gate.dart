import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/onboarding/onboarding_state.dart';
import '../../core/providers.dart';
import '../auth/auth_gate.dart';
import 'branded_splash.dart';
import 'onboarding_flow.dart';

/// The first screen the Flutter app renders.
///
/// It shows the animated splash while the persisted onboarding state loads,
/// then routes to exactly one of:
/// - the onboarding flow (first run, or an updated User Agreement), or
/// - [AuthGate], which keeps the existing session/role/account routing intact.
///
/// Onboarding is deliberately *outside* the auth gate: a new driver must read
/// the terms and choose a language before signing in, and a returning driver
/// goes straight to the existing sign-in/dashboard path.
class LaunchGate extends ConsumerStatefulWidget {
  const LaunchGate({super.key});

  @override
  ConsumerState<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends ConsumerState<LaunchGate> {
  OnboardingState? _state;
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final store = ref.read(onboardingStoreProvider);
    final state = await store.load();
    if (!mounted) return;
    setState(() => _state = state);
  }

  void _handleSplashDone() {
    if (!mounted) return;
    setState(() => _splashDone = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_state == null || !_splashDone) {
      return BrandedSplash(onFinished: _handleSplashDone);
    }

    final store = ref.read(onboardingStoreProvider);
    if (_state!.needsOnboarding) {
      return OnboardingFlow(
        store: store,
        initialPage: _state!.resumeStep,
        onFinished: () {
          if (!mounted) return;
          setState(() => _state = store.state);
        },
      );
    }

    return const AuthGate();
  }
}
