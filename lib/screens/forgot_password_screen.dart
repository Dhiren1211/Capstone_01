import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import '../theme/app_colors.dart';
import '../utils/validators.dart';
import '../widgets/auth_layout.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/info_banner.dart';
import '../widgets/primary_button.dart';

/// Sends a password-reset e-mail and confirms on the same page.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _sending = false;
  bool _autovalidate = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autovalidate = true);
      return;
    }
    setState(() => _sending = true);
    final error = await context.read<AuthState>().sendPasswordReset(
      _emailCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = error == null;
    });
    if (error != null) showAppSnack(context, error, error: true);
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      showBack: true,
      title: 'Reset password',
      subtitle: 'Enter your e-mail and we will send you a link to choose a new password.',
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
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                onFieldSubmitted: (_) => _submit(),
                validator: AppValidators.email,
              ),
              const SizedBox(height: 20),
              if (_sent) ...[
                const InfoBanner(
                  tone: BannerTone.success,
                  title: 'Link sent',
                  message:
                      'If an account exists for this address, the e-mail is on '
                      'its way. Check the spam folder if you do not see it.',
                ),
                const SizedBox(height: 16),
              ],
              PrimaryButton(
                label: _sent ? 'Send again' : 'Send reset link',
                isLoading: _sending,
                onPressed: _submit,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondaryOf(context),
                ),
                child: const Text('Back to sign in'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
