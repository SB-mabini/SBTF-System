import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../../core/theme.dart';

/// One-time-password sign-in for drivers and operators.
///
/// A driver who has lost their password does not use a recovery link. They ask
/// the server to e-mail a short numeric code (the "one-time password") and enter
/// it here. Supabase Auth mints and checks the code; [AuthGate] then routes the
/// confirmed session to the home screen.
class OtpLoginScreen extends StatefulWidget {
  const OtpLoginScreen({super.key});

  @override
  State<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

enum _OtpStep { request, verify }

class _OtpLoginScreenState extends State<OtpLoginScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _OtpStep _step = _OtpStep.request;
  bool _loading = false;
  String? _error;

  bool get _demo => currentEnv.isDemoMode;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim().toLowerCase();

  Future<void> _requestCode() async {
    if (_demo) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: _email,
        shouldCreateUser: false,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _step = _OtpStep.verify;
      });
    } on AuthException catch (error) {
      setState(() {
        _loading = false;
        _error = _friendly(error.message);
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Could not send the one-time password. Check your connection.';
      });
    }
  }

  Future<void> _verifyCode() async {
    if (_demo) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.email,
        email: _email,
        token: _codeController.text.trim(),
      );
      // On success the AuthGate re-evaluates and routes to the home screen.
    } on AuthException catch (error) {
      setState(() {
        _loading = false;
        _error = _friendly(error.message);
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Could not verify the code. Check your connection and try again.';
      });
    }
  }

  String _friendly(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('expired')) {
      return 'That code has expired. Request a new one.';
    }
    if (lower.contains('invalid') || lower.contains('token')) {
      return 'That code is not correct. Check the six digits and try again.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('One-time password')),
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
                    const SizedBox(height: AppSpacing.sm),
                    if (_demo) ...[
                      const _NoticeBanner(
                        icon: Icons.info_outline,
                        message:
                            'Preview mode — Supabase is not connected, so one-time '
                            'password sign-in is shown but disabled.',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (_error != null) ...[
                      _NoticeBanner(
                        icon: Icons.error_outline,
                        message: _error!,
                        danger: true,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    Text(
                      _step == _OtpStep.request
                          ? 'Enter the e-mail address registered with the SBTF '
                              'mobile app. We will e-mail a six-digit code that '
                              'signs you in once.'
                          : 'Enter the six-digit code sent to $_email. The code '
                              'expires after a few minutes.',
                      style: const TextStyle(color: AppColors.inkMuted, height: 1.4),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_step == _OtpStep.request) ...[
                      const Text(
                        'E-mail address',
                        style: TextStyle(
                          color: AppColors.inkStrong,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        enabled: !_demo,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          hintText: 'name@example.com',
                          prefixIcon: Icon(Icons.email_outlined, size: 20),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty || !email.contains('@')) {
                            return 'Enter a valid e-mail address.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton(
                        onPressed: (_demo || _loading) ? null : _requestCode,
                        child: _loading
                            ? const _ButtonSpinner()
                            : const Text('Send one-time password'),
                      ),
                    ] else ...[
                      const Text(
                        'One-time password',
                        style: TextStyle(
                          color: AppColors.inkStrong,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _codeController,
                        enabled: !_demo,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _verifyCode(),
                        decoration: const InputDecoration(
                          hintText: '123456',
                          prefixIcon: Icon(Icons.password_outlined, size: 20),
                        ),
                        validator: (value) {
                          final code = value?.trim() ?? '';
                          if (code.length < 6) {
                            return 'Enter the six-digit code.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton(
                        onPressed: (_demo || _loading) ? null : _verifyCode,
                        child: _loading
                            ? const _ButtonSpinner()
                            : const Text('Sign in'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() {
                                  _step = _OtpStep.request;
                                  _error = null;
                                  _codeController.clear();
                                }),
                        child: const Text('Use a different address'),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Back to password sign in'),
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

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({
    required this.icon,
    required this.message,
    this.danger = false,
  });

  final IconData icon;
  final String message;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.warning;
    final tint = danger ? AppColors.dangerTint : AppColors.accentTint;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: tint,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.unit),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
