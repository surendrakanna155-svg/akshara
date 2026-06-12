import 'package:flutter/material.dart';

import '../../theme/spacing.dart';

/// Shared labeled form field with required indicator, hint, and inline error.
class AksharaFormField extends StatelessWidget {
  const AksharaFormField({
    super.key,
    required this.label,
    this.required = false,
    this.hint,
    this.helperText,
    this.errorText,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.textInputAction,
    this.focusNode,
    this.onFieldSubmitted,
    this.readOnly = false,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.suffixIcon,
    this.prefixIcon,
    this.semanticLabel,
    this.autovalidateMode,
    this.validator,
  });

  final String label;
  final bool required;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;
  final bool readOnly;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? minLines;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final String? semanticLabel;
  final AutovalidateMode? autovalidateMode;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final decorationLabel = required ? '$label *' : label;

    return Semantics(
      label: semanticLabel ?? decorationLabel,
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        focusNode: focusNode,
        readOnly: readOnly,
        keyboardType: keyboardType,
        maxLines: maxLines,
        minLines: minLines,
        textInputAction: textInputAction,
        autovalidateMode: autovalidateMode,
        validator: validator ??
            (errorText != null && errorText!.isNotEmpty
                ? (_) => errorText
                : null),
        decoration: InputDecoration(
          labelText: decorationLabel,
          hintText: hint,
          helperText: helperText,
          errorText: errorText,
          suffixIcon: suffixIcon,
          prefixIcon: prefixIcon,
          alignLabelWithHint: maxLines > 1,
        ),
        onChanged: onChanged,
        onFieldSubmitted: onFieldSubmitted,
      ),
    );
  }
}

/// Consistent vertical spacing between form fields.
class AksharaFormSection extends StatelessWidget {
  const AksharaFormSection({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          if (subtitle != null) ...[
            const SizedBox(height: AksharaSpacing.s1),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AksharaSpacing.s4),
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(height: AksharaSpacing.s4),
          ],
        ],
      ),
    );
  }
}
