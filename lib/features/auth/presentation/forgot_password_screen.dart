import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialogs.dart';
import '../providers/auth_providers.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(_emailController.text);
      if (!mounted) return;
      showAppSnackBar(
        context,
        'If the address exists, a reset link is on its way.',
      );
      context.go('/sign-in');
    } catch (error) {
      if (!mounted) return;
      final message = error is AppException
          ? error.message
          : 'Could not send the reset email. Please try again.';
      showAppSnackBar(context, message, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
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
                    const Text(
                      'Enter the email address of your account and we will send '
                      'you a link to choose a new password.',
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      label: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Enter your email';
                        if (!text.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                      onSubmitted: (_) => _sendReset(),
                    ),
                    const SizedBox(height: 22),
                    AppButton(
                      label: 'Send reset link',
                      icon: Icons.send_outlined,
                      isLoading: _isLoading,
                      onPressed: _sendReset,
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      label: 'Back to sign in',
                      style: AppButtonStyle.text,
                      onPressed: () => context.go('/sign-in'),
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
