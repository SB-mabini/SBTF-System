import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/branding.dart';
import '../../core/env.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_banner.dart';
import '../../core/widgets/brand_mark.dart';
import 'auth_messages.dart';
import 'email_verification_screen.dart';
import 'forgot_password_screen.dart';
import 'registration_screen.dart';

/// Sign-in for drivers and operators.
///
/// In preview/demo mode the real form is rendered but disabled under an
/// explanatory banner — it is never hidden, because a hidden sign-in reads as
/// "not implemented".
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  String? _error;
  bool _obscure = true;

  bool get _demo => currentEnv.isDemoMode;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_demo) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      await client.auth.signInWithPassword(
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text,
      );
      // On success the AuthGate re-evaluates and routes to the home screen.
    } on AuthException catch (error) {
      setState(() {
        _loading = false;
        _error = friendlyAuthMessage(error.message);
      });

      // An unconfirmed e-mail is not a failure — route to the OTP screen.
      if (error.message.toLowerCase().contains('email not confirmed')) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EmailVerificationScreen(
                email: _emailController.text.trim().toLowerCase(),
              ),
            ),
          );
        }
      }
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Could not sign in. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.hero),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.maxHeight;
              // The purple band above the white wave holds the office lockup.
              final headerHeight =
                  math.min(math.max(height * 0.15, 88.0), 112.0);
              const footerHeight = 78.0;

              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _WavePanelPainter(
                        top: headerHeight,
                        bottom: height - footerHeight,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      SizedBox(
                        height: headerHeight,
                        child: const _OfficeLockup(),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, viewport) {
                            final topPadding = math.min(
                              88.0,
                              viewport.maxHeight * 0.16,
                            );
                            final verticalPadding = topPadding + 24;
                            return SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                28,
                                topPadding,
                                28,
                                24,
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: math.min(
                                    viewport.maxWidth - 56,
                                    420,
                                  ),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: math.max(
                                        0,
                                        viewport.maxHeight - verticalPadding,
                                      ),
                                    ),
                                    child: IntrinsicHeight(
                                      child: Form(
                                        key: _formKey,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            if (_demo) ...[
                                              const AppBanner(
                                                tone: AppBannerTone.warning,
                                                message:
                                                    'Preview mode — Supabase is not '
                                                    'connected, so sign-in is shown '
                                                    'but disabled. The app runs '
                                                    'without a database.',
                                              ),
                                              const SizedBox(
                                                  height: AppSpacing.sm),
                                            ],
                                            if (_error != null) ...[
                                              AppBanner(
                                                tone: AppBannerTone.danger,
                                                message: _error!,
                                              ),
                                              const SizedBox(
                                                  height: AppSpacing.sm),
                                            ],
                                            const Text(
                                              'Hello',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: AppColors.inkStrong,
                                                fontSize: 28,
                                                fontWeight: FontWeight.w800,
                                                height: 1.15,
                                                letterSpacing: -0.6,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            const Text(
                                              'Sign into your Account',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: AppColors.inkMuted,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 34),
                                            const Spacer(),
                                            const _FieldLabel(
                                                'E-mail address *'),
                                            const SizedBox(height: 2),
                                            TextFormField(
                                              controller: _emailController,
                                              enabled: !_demo,
                                              keyboardType:
                                                  TextInputType.emailAddress,
                                              textInputAction:
                                                  TextInputAction.next,
                                              autocorrect: false,
                                              enableSuggestions: false,
                                              decoration: _fieldDecoration(
                                                hintText: 'name@example.com',
                                              ),
                                              validator: (value) {
                                                final email =
                                                    value?.trim() ?? '';
                                                if (email.isEmpty ||
                                                    !email.contains('@')) {
                                                  return 'Enter a valid e-mail address.';
                                                }
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 22),
                                            const _FieldLabel('Password *'),
                                            const SizedBox(height: 2),
                                            TextFormField(
                                              controller: _passwordController,
                                              enabled: !_demo,
                                              obscureText: _obscure,
                                              textInputAction:
                                                  TextInputAction.done,
                                              onFieldSubmitted: (_) =>
                                                  _signIn(),
                                              decoration: _fieldDecoration(
                                                hintText: 'Enter your password',
                                                suffixIcon: Semantics(
                                                  label: _obscure
                                                      ? 'Show password'
                                                      : 'Hide password',
                                                  child: IconButton(
                                                    icon: Icon(
                                                      _obscure
                                                          ? Icons
                                                              .visibility_outlined
                                                          : Icons
                                                              .visibility_off_outlined,
                                                      size: 20,
                                                    ),
                                                    onPressed: _demo
                                                        ? null
                                                        : () => setState(
                                                              () => _obscure =
                                                                  !_obscure,
                                                            ),
                                                  ),
                                                ),
                                              ),
                                              validator: (value) {
                                                if ((value ?? '').isEmpty) {
                                                  return 'Enter your password.';
                                                }
                                                return null;
                                              },
                                            ),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton(
                                                onPressed: _demo
                                                    ? null
                                                    : () =>
                                                        Navigator.of(context)
                                                            .push(
                                                          MaterialPageRoute(
                                                            builder: (_) =>
                                                                ForgotPasswordScreen(
                                                              initialEmail:
                                                                  _emailController
                                                                      .text
                                                                      .trim(),
                                                            ),
                                                          ),
                                                        ),
                                                style: TextButton.styleFrom(
                                                  minimumSize:
                                                      const Size(0, 40),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 4,
                                                  ),
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  foregroundColor:
                                                      AppColors.primary,
                                                  textStyle: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                child: const Text(
                                                  'Forgot your password?',
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 14),
                                            const Spacer(),
                                            Center(
                                              child: FilledButton(
                                                onPressed: (_demo || _loading)
                                                    ? null
                                                    : _signIn,
                                                style: FilledButton.styleFrom(
                                                  minimumSize:
                                                      const Size(160, 46),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 48,
                                                  ),
                                                  shape: const StadiumBorder(),
                                                ),
                                                child: _loading
                                                    ? const SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    : const Text('Login'),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(
                        height: footerHeight,
                        child: Center(
                          child: TextButton(
                            key: const Key('login-register-link'),
                            onPressed: _demo
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const RegistrationScreen(),
                                      ),
                                    ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white54,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Don\'t have an account? ',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.75),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: 'Register Now',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      filled: false,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      suffixIcon: suffixIcon,
      suffixIconColor: AppColors.inkMuted,
      border: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.borderStrong),
      ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.borderStrong),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.primary, width: 1.6),
      ),
      errorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.danger, width: 1.6),
      ),
    );
  }
}

/// The municipal identity at the top of the purple header.
class _OfficeLockup extends StatelessWidget {
  const _OfficeLockup();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const BrandMark(size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppBranding.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  AppBranding.officeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small field label matching the reference's quiet, underlined form.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.inkStrong,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Draws the white organic panel that sits between the purple header and
/// footer. Both edges are soft curves, so the form reads as a sheet floating on
/// the brand colour rather than a plain rectangle.
class _WavePanelPainter extends CustomPainter {
  const _WavePanelPainter({required this.top, required this.bottom});

  final double top;
  final double bottom;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final path = Path()
      ..moveTo(0, top + 34)
      ..cubicTo(
        width * 0.14,
        top - 16,
        width * 0.34,
        top + 10,
        width * 0.54,
        top - 14,
      )
      ..cubicTo(
        width * 0.72,
        top - 34,
        width * 0.9,
        top + 16,
        width,
        top + 8,
      )
      ..lineTo(width, bottom - 8)
      ..cubicTo(
        width * 0.8,
        bottom + 22,
        width * 0.62,
        bottom - 24,
        width * 0.4,
        bottom - 2,
      )
      ..cubicTo(
        width * 0.22,
        bottom + 20,
        width * 0.08,
        bottom - 20,
        0,
        bottom + 6,
      )
      ..close();

    canvas.drawPath(path, Paint()..color = AppColors.surface);
  }

  @override
  bool shouldRepaint(covariant _WavePanelPainter oldDelegate) =>
      oldDelegate.top != top || oldDelegate.bottom != bottom;
}
