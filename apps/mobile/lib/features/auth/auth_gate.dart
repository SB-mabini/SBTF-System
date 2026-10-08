import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../home/home_screen.dart';
import 'email_verification_screen.dart';
import 'login_screen.dart';
import 'session_guard.dart';

/// Maps the current session state onto the right screen.
///
/// The decision itself is pure logic in [evaluateSession]; this widget only
/// renders it. Profile loading and profile errors are shown here (with retry),
/// and each refusal is a card that names the reason rather than a blank screen.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Preview mode never touches a database: show the (disabled) sign-in screen.
    if (currentEnv.isDemoMode || !currentEnv.isConfigured) {
      return const LoginScreen();
    }

    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      loading: () => const _GateScaffold(child: _Loading()),
      error: (error, _) => _GateScaffold(
        child: _RefusalCard(
          icon: Icons.error_outline,
          title: 'Connection problem',
          message: 'Could not reach the authentication service. '
              'Check your connection and try again.',
        ),
      ),
      data: (state) {
        final session = state.session;
        final hasSession = session != null;
        final emailConfirmed = session?.user.emailConfirmedAt != null;

        final profileAsync = ref.watch(profileProvider);

        return profileAsync.when(
          loading: () => const _GateScaffold(child: _Loading()),
          error: (error, _) => _GateScaffold(
            child: _RefusalCard(
              icon: Icons.error_outline,
              title: 'Could not load your profile',
              message: '$error',
              onRetry: () => ref.invalidate(profileProvider),
            ),
          ),
          data: (profile) {
            final decision = evaluateSession(
              hasSession: hasSession,
              emailConfirmed: emailConfirmed,
              profile: profile,
            );
            return _screenFor(decision, email: session?.user.email);
          },
        );
      },
    );
  }

  Widget _screenFor(SessionDecision decision, {String? email}) {
    switch (decision) {
      case SessionDecision.requireLogin:
        return const LoginScreen();
      case SessionDecision.requireEmailVerification:
        return EmailVerificationScreen(email: email);
      case SessionDecision.profileMissing:
        return _GateScaffold(
          child: _RefusalCard(
            icon: Icons.person_off_outlined,
            title: 'No profile found',
            message: decisionReason(decision),
          ),
        );
      case SessionDecision.refuseNonDriver:
        return _GateScaffold(
          child: _RefusalCard(
            icon: Icons.desktop_windows_outlined,
            title: 'Use the web console',
            message: decisionReason(decision),
          ),
        );
      case SessionDecision.refuseSuspended:
        return _GateScaffold(
          child: _RefusalCard(
            icon: Icons.block_outlined,
            title: 'Account suspended',
            message: decisionReason(decision),
          ),
        );
      case SessionDecision.refuseInactive:
        return _GateScaffold(
          child: _RefusalCard(
            icon: Icons.pause_circle_outline,
            title: 'Account not active',
            message: decisionReason(decision),
          ),
        );
      case SessionDecision.allow:
        return const HomeScreen();
    }
  }
}

/// Centers gate content inside a plain scaffold.
class _GateScaffold extends StatelessWidget {
  const _GateScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: AppSpacing.sm),
        Text('Checking your session…',
            style: TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _RefusalCard extends StatelessWidget {
  const _RefusalCard({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: AppColors.textSecondary),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          message,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          textAlign: TextAlign.center,
        ),
        if (onRetry != null) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ],
    );
  }
}
