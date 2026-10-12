// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/branding/app_logo.dart';
import '../../core/branding/build_integrity.dart';
import '../../core/branding/credit_footer.dart';
import '../../data/repositories/auth_repository.dart';
import '../../providers/providers.dart';
import '../shared/ui_kit.dart';

/// Email/password sign-in.
///
/// The error text is derived from the auth exception rather than a generic
/// message: "account deactivated" and "no profile row" are the two conditions
/// a field user can actually act on, and hiding them wastes a support call.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    // Integrity call site 2 of 3. Re-checked here rather than only at startup
    // because an attacker who disables the startup guard must not gain a path
    // through the login button. The About page (call site 3) reports the same
    // verdict to the user.
    final integrity = await BuildIntegrity.evaluate();
    if (!integrity.isUntampered && mounted) {
      setState(() {
        _submitting = false;
        _error = 'This build failed its integrity check and cannot sign in. '
            'See About for details.';
      });
      return;
    }

    final result = await ref.read(authRepositoryProvider).signInWithPassword(
          email: _email.text,
          password: _password.text,
        );

    if (!mounted) return;

    switch (result) {
      case AuthSuccess(:final profile):
        ref.read(profileProvider.notifier).adopt(profile);
      case AuthFailure(:final message):
        setState(() {
          _submitting = false;
          _error = message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppLogo(size: 88)),
                  const SizedBox(height: 18),
                  const SizedBox(height: 24),
                  Text(
                    'SafeDepot Pro',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Depot safety and workflow management',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 36),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter your password.' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    InlineError(_error!),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Sign in'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Accounts are created by an administrator. If sign-in '
                    'succeeds but the app reports a missing profile, ask an '
                    'administrator to complete your account.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const CreditFooter(),
        ],
      ),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter your email address.';
    if (!value.contains('@') || !value.contains('.')) return 'Enter a valid email address.';
    return null;
  }
}
