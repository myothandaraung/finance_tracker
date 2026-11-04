import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialogs.dart';
import '../providers/auth_providers.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).signIn(
            email: _emailController.text,
            password: _passwordController.text,
          );
      if (mounted) context.go('/splash');
    } catch (error) {
      if (!mounted) return;
      final message = error is AppException
          ? error.message
          : 'Could not sign in. Please try again.';
      showAppSnackBar(context, message, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 46),
                    const SizedBox(height: 18),
                    Text(
                      'MTO Finance',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign in to manage your quotations, orders and finances',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    AppTextField(
                      label: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Password',
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      validator: (value) =>
                          (value == null || value.isEmpty) ? 'Enter your password' : null,
                      onSubmitted: (_) => _signIn(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.go('/forgot-password'),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Sign in',
                      icon: Icons.login,
                      isLoading: _isLoading,
                      onPressed: _signIn,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('No account yet?'),
                        TextButton(
                          onPressed: () => context.go('/sign-up'),
                          child: const Text('Create one'),
                        ),
                      ],
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
