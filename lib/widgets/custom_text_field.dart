import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Text input with an optional left icon, a password visibility toggle and the
/// label above the field (never inside it, so long labels cannot be clipped).
class CustomTextField extends StatefulWidget {
  const CustomTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.helper,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.onFieldSubmitted,
    this.onChanged,
    this.focusNode,
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.autofillHints,
    this.inputFormatters,
    this.autovalidateMode,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? helper;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final void Function(String)? onChanged;
  final FocusNode? focusNode;
  final int minLines;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final AutovalidateMode? autovalidateMode;

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscure = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _obscure,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      validator: widget.validator,
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
      minLines: widget.obscureText ? 1 : widget.minLines,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      enabled: widget.enabled,
      autofillHints: widget.autofillHints,
      inputFormatters: widget.inputFormatters,
      autovalidateMode: widget.autovalidateMode,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      style: AppTextStyles.body.copyWith(
        color: AppColors.textPrimaryOf(context),
      ),
      decoration: InputDecoration(
        hintText: widget.hint,
        helperText: widget.helper,
        counterText: widget.maxLength == null ? null : '',
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, size: 20)
            : null,
        suffixIcon:
            widget.suffixIcon ??
            (widget.obscureText ? _visibilityToggle() : null),
      ),
    );
    if (widget.label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            widget.label!,
            style: AppTextStyles.captionMedium.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ),
        field,
      ],
    );
  }

  Widget _visibilityToggle() {
    return IconButton(
      tooltip: _obscure ? 'Show password' : 'Hide password',
      icon: Icon(
        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
        color: AppColors.textTertiaryOf(context),
      ),
      onPressed: () => setState(() => _obscure = !_obscure),
    );
  }
}
