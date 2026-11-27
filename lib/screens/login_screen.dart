import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';
import '../widgets/auth_layout.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import 'signup_screen.dart';

/// Sign in with e-mail and password.
///
/// Accounts must verify their e-mail address before using the app; that step
/// is handled by the auth gate right after sign-in.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onAuthSuccess});

  final VoidCallback onAuthSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _autovalidate = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autovalidate = true);
      return;
    }
    final auth = context.read<AuthState>();
    final ok = await auth.signIn(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      widget.onAuthSuccess();
    } else {
      showAppSnack(
        context,
        auth.error ?? 'Sign-in failed. Please try again.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.select<AuthState, bool>((a) => a.isBusy);
    return AuthLayout(
      title: 'Welcome back',
      subtitle: 'Sign in with your university e-mail to find or report items.',
      footer: AuthFooterLink(
        prompt: 'New to smartFind?',
        action: 'Create an account',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SignupScreen(onAuthSuccess: widget.onAuthSuccess),
          ),
        ),
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
                controller: _emailCtrl,
                label: 'E-mail',
                hint: 'you@ks.ac.kr',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: AppValidators.email,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _passwordCtrl,
                label: 'Password',
                hint: 'Your password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _signIn(),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter your password' : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamed(AppConstants.routeForgotPassword),
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: 'Sign in',
                isLoading: busy,
                onPressed: _signIn,
              ),
              const SizedBox(height: 4),
              Text(
                'Your e-mail is only used to sign in and to tell you about '
                'matches and messages.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
