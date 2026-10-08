import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../../core/theme.dart';

/// Prompt shown after registration (or when a sign-in is attempted with an
/// unconfirmed e-mail). The account exists but cannot sign in until the address
/// is confirmed. Offers a resend and a way back to the sign-in screen.
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key, this.email});

  final String? email;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _resending = false;
  String? _notice;
  String? _error;

  bool get _demo => currentEnv.isDemoMode;

  Future<void> _resend() async {
    if (_demo) return;
    setState(() {
      _resending = true;
      _notice = null;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      await client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );
      setState(() {
        _resending = false;
        _notice = 'Verification e-mail sent. Check your inbox.';
      });
    } on AuthException catch (error) {
      setState(() {
        _resending = false;
        _error = error.message;
      });
    } catch (_) {
      setState(() {
        _resending = false;
        _error = 'Could not resend the e-mail. Try again shortly.';
      });
    }
  }

  Future<void> _backToSignIn() async {
    // Clear any partial session left over from registration so the sign-in
    // screen starts clean.
    if (!_demo) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {
        // Signing out a session that never existed is not an error here.
      }
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm your e-mail')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.mark_email_read_outlined,
                      size: 56, color: AppColors.primary),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    widget.email == null || widget.email!.isEmpty
                        ? 'Check your inbox'
                        : 'Check ${widget.email}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'We sent a confirmation link to your e-mail address. Your '
                    'account is created, but you cannot sign in until the '
                    'address is confirmed.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_notice != null) ...[
                    Text(
                      _notice!,
                      style: const TextStyle(color: AppColors.success),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.danger),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  FilledButton.icon(
                    onPressed: (_demo || _resending) ? null : _resend,
                    icon: _resending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Resend confirmation e-mail'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: _backToSignIn,
                    child: const Text('Back to sign in'),
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
