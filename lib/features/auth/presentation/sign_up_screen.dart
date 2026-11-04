import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialogs.dart';
import '../providers/auth_providers.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      final hasSession = await ref.read(authRepositoryProvider).signUp(
            email: _emailController.text,
            password: _passwordController.text,
            displayName: _nameController.text,
          );

      if (!mounted) return;
      if (hasSession) {
        context.go('/splash');
      } else {
        showAppSnackBar(
          context,
          'Account created. Check your inbox to confirm the address, then sign in.',
        );
        context.go('/sign-in');
      }
    } catch (error) {
      if (!mounted) return;
      final message = error is AppException
          ? error.message
          : 'Could not create the account. Please try again.';
      showAppSnackBar(context, message, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      label: 'Full name',
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Enter your name'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Enter your email';
                        if (!text.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Password',
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      validator: (value) => (value == null || value.length < 6)
                          ? 'Use at least 6 characters'
                          : null,
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      label: 'Confirm password',
                      controller: _confirmController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      validator: (value) => value != _passwordController.text
                          ? 'Passwords do not match'
                          : null,
                      onSubmitted: (_) => _signUp(),
                    ),
                    const SizedBox(height: 22),
                    AppButton(
                      label: 'Create account',
                      icon: Icons.person_add_alt,
                      isLoading: _isLoading,
                      onPressed: _signUp,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already registered?'),
                        TextButton(
                          onPressed: () => context.go('/sign-in'),
                          child: const Text('Sign in'),
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
