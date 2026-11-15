import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_error_dialog.dart';
import 'auth_messages.dart';

/// Finish the forgot-password flow.
///
/// Reached only after the recovery code was accepted. The recovery code created
/// a short-lived Supabase session, and `updateUser` changes the password on
/// that session. When it succeeds the driver stays signed in and the AuthGate
/// below shows the home screen.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  bool get _demo => currentEnv.isDemoMode;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_demo) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);

    try {
      final client = Supabase.instance.client;
      await client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );

      if (!mounted) return;
      // The recovery session is already signed in, so returning to the root
      // lets AuthGate route to the dashboard.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(
        friendlyAuthMessage(error.message),
        title: 'Password not saved',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(
        'Could not save the new password. Check your connection and try again.',
        title: 'Password not saved',
      );
    }
  }

  /// Reports a password failure in a dialog, not an inline banner.
  void _showError(String message, {String title = 'Please check this'}) {
    if (!mounted) return;
    showAppErrorDialog(context, message, title: title);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set a new password')),
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
                    const Text(
                      'Choose a new password for your account. Use at least 8 '
                      'characters.',
                      style: TextStyle(color: AppColors.inkMuted, height: 1.4),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'New password',
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
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'At least 8 characters',
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
                      validator: (value) => (value ?? '').length < 8
                          ? 'Password must be at least 8 characters.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Confirm new password',
                      style: TextStyle(
                        color: AppColors.inkStrong,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.unit),
                    TextFormField(
                      controller: _confirmController,
                      enabled: !_demo,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _save(),
                      decoration: const InputDecoration(
                        hintText: 'Re-enter the new password',
                      ),
                      validator: (value) => value != _passwordController.text
                          ? 'Passwords do not match.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: (_demo || _loading) ? null : _save,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save password and continue'),
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
