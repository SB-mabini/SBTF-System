import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_banner.dart';
import 'auth_messages.dart';
import 'reset_password_screen.dart';

/// What the code in the e-mail is proving.
enum EmailOtpPurpose {
  /// Registration: confirming the address also signs the driver in.
  signup,

  /// Forgot password: the code unlocks the "set a new password" screen.
  recovery,
}

/// The one-time-password screen used by both registration and password reset.
///
/// Supabase Auth sends a numeric code (not a link) for both flows, so the app
/// asks for it here and calls `verifyOtp` with the matching [OtpType]. On a
/// successful signup verification Supabase creates the session itself, which
/// means the driver is signed in as soon as the code is accepted — no second
/// sign-in step.
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    this.email,
    this.purpose = EmailOtpPurpose.signup,
    this.codeWasSent = true,
  });

  final String? email;
  final EmailOtpPurpose purpose;

  /// False when the screen is opened from a sign-in attempt that failed with
  /// "email not confirmed": no code was just requested, so the resend button
  /// must be available immediately instead of waiting out the cooldown.
  final bool codeWasSent;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  bool _loading = false;
  bool _resending = false;
  String? _notice;
  String? _error;

  /// Supabase Auth throttles repeated sends for the same address
  /// (`max_frequency`, 60 s on the hosted project). Asking again inside that
  /// window fails with a 429 and no message, so the button is disabled until
  /// the window has passed. A code is sent right before this screen opens, so
  /// the countdown starts immediately.
  Timer? _cooldownTimer;
  int _secondsUntilResend = 0;

  static const int _resendCooldownSeconds = 60;

  bool get _demo => currentEnv.isDemoMode;
  bool get _isRecovery => widget.purpose == EmailOtpPurpose.recovery;

  String get _email => (widget.email ?? '').trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    if (widget.codeWasSent) {
      _startCooldown();
    } else {
      _notice = 'No code has been sent yet. Tap “Send a new code” below.';
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    if (!mounted) return;
    setState(() => _secondsUntilResend = _resendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsUntilResend <= 1) {
        timer.cancel();
        setState(() => _secondsUntilResend = 0);
        return;
      }
      setState(() => _secondsUntilResend--);
    });
  }

  Future<void> _verify() async {
    if (_demo) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_email.isEmpty) {
      setState(() {
        _error = 'No e-mail address is linked to this request. Return to sign '
            'in and start again.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _notice = null;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      await client.auth.verifyOTP(
        type: _isRecovery ? OtpType.recovery : OtpType.signup,
        email: _email,
        token: _codeController.text.trim(),
      );

      if (!mounted) return;

      if (_isRecovery) {
        // verifyOtp created a short-lived recovery session. The next screen
        // uses it to set the new password; the driver stays signed in after.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const ResetPasswordScreen(),
          ),
        );
        return;
      }

      // Registration OTP verified: the session now exists, so popping back to
      // the AuthGate lets it route straight to the home screen.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (error) {
      setState(() {
        _loading = false;
        _error = friendlyAuthMessage(error.message);
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Could not verify the code. Check your connection and try '
            'again.';
      });
    }
  }

  Future<void> _resend() async {
    if (_demo) return;

    if (_email.isEmpty) {
      setState(() {
        _error = 'No e-mail address is linked to this request, so nothing can '
            'be resent. Return to sign in and try again.';
      });
      return;
    }

    if (_secondsUntilResend > 0) {
      setState(() {
        _notice = null;
        _error = 'Please wait $_secondsUntilResend seconds before requesting '
            'another code.';
      });
      return;
    }

    setState(() {
      _resending = true;
      _notice = null;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      if (_isRecovery) {
        await client.auth.resetPasswordForEmail(_email);
      } else {
        await client.auth.resend(type: OtpType.signup, email: _email);
      }
      if (!mounted) return;
      setState(() {
        _resending = false;
        _notice = 'A new 6-digit code is on its way. Check your inbox and '
            'spam folder.';
      });
      _startCooldown();
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _error = friendlyAuthMessage(error.message);
      });
      // A confirmed address cannot be resent a signup code. Supabase reports
      // "User already registered"; the friendly message already points at
      // signing in, so leave the button usable in case the driver mistyped.
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _error = 'Could not resend the code. Try again shortly.';
      });
    }
  }

  Future<void> _backToSignIn() async {
    // Clear any partial session left over from registration or recovery so the
    // sign-in screen starts clean.
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
    final title = _isRecovery ? 'Reset your password' : 'Confirm your e-mail';
    final heading = _email.isEmpty
        ? 'Enter your code'
        : _isRecovery
            ? 'Code sent to $_email'
            : 'Code sent to $_email';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryTint,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isRecovery
                              ? Icons.lock_reset_outlined
                              : Icons.mark_email_read_outlined,
                          size: 34,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      heading,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkStrong,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _isRecovery
                          ? 'Enter the 6-digit code from the e-mail to choose '
                              'a new password. The code expires in 10 minutes.'
                          : 'Enter the 6-digit code from the e-mail to confirm '
                              'your account. You will be signed in '
                              'automatically.',
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_notice != null) ...[
                      AppBanner(tone: AppBannerTone.success, message: _notice!),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (_error != null) ...[
                      AppBanner(tone: AppBannerTone.danger, message: _error!),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    const Text(
                      '6-digit code',
                      style: TextStyle(
                        color: AppColors.inkStrong,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.unit),
                    TextFormField(
                      controller: _codeController,
                      enabled: !_demo && !_loading,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 8,
                        color: AppColors.inkStrong,
                      ),
                      decoration: const InputDecoration(
                        counterText: '',
                        hintText: '123456',
                        hintStyle: TextStyle(
                          fontSize: 20,
                          letterSpacing: 6,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      onFieldSubmitted: (_) => _verify(),
                      validator: (value) {
                        final code = (value ?? '').trim();
                        if (!RegExp(r'^\d{6}$').hasMatch(code)) {
                          return 'Enter the 6-digit code from the e-mail.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: (_demo || _loading) ? null : _verify,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isRecovery
                                  ? 'Verify code'
                                  : 'Verify and sign in',
                            ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      onPressed:
                          (_demo || _resending || _secondsUntilResend > 0)
                              ? null
                              : _resend,
                      child: _resending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _secondsUntilResend > 0
                                  ? 'Send a new code (${_secondsUntilResend}s)'
                                  : 'Send a new code',
                            ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: _backToSignIn,
                      child: Text(
                        _isRecovery
                            ? 'Back to sign in'
                            : 'Use a different e-mail',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
