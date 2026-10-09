import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../../core/theme.dart';
import 'email_verification_screen.dart';

/// Self-registration for drivers and operators.
///
/// This is the only way a driver account comes into existence. The role is never
/// sent from the client as an authoritative value: the profiles trigger reads it
/// from `raw_app_meta_data`, which only the service role can write, so a
/// self-registered account is always a `driver`. First/last name and contact
/// number ride in user metadata purely so that trigger can provision the profile.
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  bool get _demo => currentEnv.isDemoMode;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_demo) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _emailController.text.trim().toLowerCase();

    try {
      final client = Supabase.instance.client;
      await client.auth.signUp(
        email: email,
        password: _passwordController.text,
        data: {
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'contact_number': _contactController.text.trim(),
        },
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(email: email),
        ),
      );
    } on AuthException catch (error) {
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Registration failed. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create your account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Register as a tricycle driver or operator. Your role is '
                      'assigned automatically on the server — it cannot be '
                      'chosen here.',
                      style:
                          TextStyle(color: AppColors.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBE9E9),
                          border: Border.all(color: AppColors.danger),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.unit),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    TextFormField(
                      controller: _firstNameController,
                      enabled: !_demo,
                      textCapitalization: TextCapitalization.words,
                      decoration:
                          const InputDecoration(labelText: 'First name'),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'First name is required.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _lastNameController,
                      enabled: !_demo,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Last name'),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Last name is required.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _contactController,
                      enabled: !_demo,
                      keyboardType: TextInputType.phone,
                      decoration:
                          const InputDecoration(labelText: 'Contact number'),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Contact number is required.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_demo,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          const InputDecoration(labelText: 'E-mail address'),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty || !email.contains('@')) {
                          return 'Enter a valid e-mail address.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_demo,
                      obscureText: _obscure,
                      decoration: const InputDecoration(
                          labelText: 'Password (at least 8 characters)'),
                      validator: (value) => (value ?? '').length < 8
                          ? 'Password must be at least 8 characters.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _confirmController,
                      enabled: !_demo,
                      obscureText: _obscure,
                      decoration: const InputDecoration(
                          labelText: 'Confirm password'),
                      validator: (value) =>
                          value != _passwordController.text
                              ? 'Passwords do not match.'
                              : null,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _demo
                              ? null
                              : () => setState(() => _obscure = !_obscure),
                          child: Text(_obscure ? 'Show' : 'Hide'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.icon(
                      onPressed: (_demo || _loading) ? null : _register,
                      icon: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add_alt_1),
                      label: const Text('Create account'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: _demo ? null : () => Navigator.of(context).pop(),
                      child: const Text('Back to sign in'),
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
