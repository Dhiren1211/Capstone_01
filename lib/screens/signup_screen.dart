import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../state/auth_state.dart';
import '../utils/validators.dart';
import '../widgets/auth_layout.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';

/// Create an account: name, student ID, university e-mail and a password.
///
/// Firebase then e-mails a verification link; the auth gate shows the
/// "Check your inbox" page until it has been opened.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, required this.onAuthSuccess});

  final VoidCallback onAuthSuccess;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _autovalidate = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _studentIdCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autovalidate = true);
      return;
    }
    final auth = context.read<AuthState>();
    final ok = await auth.register(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      displayName: _nameCtrl.text.trim(),
      studentId: _studentIdCtrl.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      widget.onAuthSuccess();
    } else {
      showAppSnack(
        context,
        auth.error ?? 'Registration failed. Please try again.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.select<AuthState, bool>((a) => a.isBusy);
    final domains = AppConfig.allowedEmailDomains;
    final emailHint = domains.isEmpty
        ? 'you@example.com'
        : 'you@${domains.first}';
    final emailLabel = domains.isEmpty ? 'E-mail' : 'University e-mail';

    return AuthLayout(
      showBack: true,
      title: 'Create account',
      subtitle:
          'We send a link to confirm your address. Open it and you are in.',
      footer: AuthFooterLink(
        prompt: 'Already registered?',
        action: 'Sign in',
        onTap: () => Navigator.of(context).maybePop(),
      ),
      children: [
        Form(
          key: _formKey,
          autovalidateMode: _autovalidate
              ? AutovalidateMode.always
              : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(
                controller: _nameCtrl,
                label: 'Full name',
                hint: 'Alex Johnson',
                prefixIcon: Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                validator: AppValidators.displayName,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _studentIdCtrl,
                label: 'Student ID',
                hint: '10 digits, for example 2020123456',
                prefixIcon: Icons.badge_outlined,
                keyboardType: TextInputType.number,
                validator: AppValidators.studentId,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _emailCtrl,
                label: emailLabel,
                hint: emailHint,
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: AppValidators.campusEmail,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _passwordCtrl,
                label: 'Password',
                hint: 'At least 8 characters',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                validator: AppValidators.password,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _confirmCtrl,
                label: 'Confirm password',
                hint: 'Repeat the password',
                prefixIcon: Icons.lock_reset_rounded,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _register(),
                validator: (v) =>
                    AppValidators.confirmPassword(v, _passwordCtrl.text),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Create account',
                isLoading: busy,
                onPressed: _register,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
