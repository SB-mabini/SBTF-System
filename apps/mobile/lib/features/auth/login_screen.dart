import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_banner.dart';
import 'email_verification_screen.dart';
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
        _error = _friendlyMessage(error.message);
      });

      // An unconfirmed e-mail is not a failure — route to verification.
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

  String _friendlyMessage(String message) {
    if (message.toLowerCase().contains('invalid login credentials')) {
      return 'The e-mail address or password is incorrect.';
    }
    if (message.toLowerCase().contains('email not confirmed')) {
      return 'Your e-mail address has not been confirmed yet.';
    }
    // Network / offline errors — Supabase wraps SocketException inside
    // AuthException on Android, so the raw OS error leaks into the message.
    if (message.toLowerCase().contains('socketexception') ||
        message.toLowerCase().contains('failed host lookup') ||
        message.toLowerCase().contains('no address associated') ||
        message.toLowerCase().contains('clientexception')) {
      return 'No internet connection. Please check your network and try again.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
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
                    const SizedBox(height: AppSpacing.xs),
                    // --- Municipal identity lockup ---
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              gradient: AppGradients.hero,
                              borderRadius: AppRadius.hero,
                              boxShadow: AppShadows.card,
                            ),
                            child: const Icon(
                              Icons.account_balance_outlined,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const Text(
                            'Municipality of Mabini',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkStrong,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Tricycle Franchising System',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_demo) ...[
                      const AppBanner(
                        tone: AppBannerTone.warning,
                        message: 'Preview mode — Supabase is not connected, so '
                            'sign-in is shown but disabled. The app runs '
                            'without a database.',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (_error != null) ...[
                      AppBanner(tone: AppBannerTone.danger, message: _error!),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    // --- E-mail label above field ---
                    const Text(
                      'E-mail address',
                      style: TextStyle(
                        color: AppColors.inkStrong,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.unit),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_demo,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
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
                    const SizedBox(height: AppSpacing.sm),
                    // --- Password label above field ---
                    const Text(
                      'Password',
                      style: TextStyle(
                        color: AppColors.inkStrong,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.unit),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_demo,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _signIn(),
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: Semantics(
                          label: _obscure ? 'Show password' : 'Hide password',
                          child: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: _demo
                                ? null
                                : () => setState(() => _obscure = !_obscure),
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
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: (_demo || _loading) ? null : _signIn,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: _demo
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RegistrationScreen(),
                                ),
                              ),
                      child: const Text('Create an account'),
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
