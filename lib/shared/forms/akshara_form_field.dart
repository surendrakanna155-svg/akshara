import 'package:flutter/material.dart';

import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';
import '../widgets/akshara_surface_card.dart';

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
    this.enabled = true,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.suffixIcon,
    this.prefixIcon,
    this.semanticLabel,
    this.autovalidateMode,
    this.validator,
    this.dense = false,
    this.maxLength,
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
  final bool enabled;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? minLines;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final String? semanticLabel;
  final AutovalidateMode? autovalidateMode;
  final FormFieldValidator<String>? validator;
  final bool dense;

  /// RT-32 — upper bound on characters a user can enter. Defaults are generous
  /// (1 000 single-line / 10 000 multi-line) so no realistic input is truncated,
  /// while preventing the unbounded-text entry the audit flagged. The counter is
  /// hidden so the bound is invisible until reached. The server `str()` reader
  /// is the hard backstop.
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final decorationLabel = required ? '$label *' : label;
    final verticalPadding = dense ? AksharaSpacing.s3 : AksharaSpacing.s4;
    final effectiveMaxLength = maxLength ?? (maxLines > 1 ? 10000 : 1000);

    return Semantics(
      label: semanticLabel ?? decorationLabel,
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        focusNode: focusNode,
        readOnly: readOnly,
        enabled: enabled,
        keyboardType: keyboardType,
        maxLines: maxLines,
        minLines: minLines,
        maxLength: effectiveMaxLength,
        // Hide the character counter so the bound stays invisible until hit.
        buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
            null,
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
          contentPadding: EdgeInsets.symmetric(
            horizontal: AksharaSpacing.s4,
            vertical: verticalPadding,
          ),
        ),
        onChanged: onChanged,
        onFieldSubmitted: onFieldSubmitted,
      ),
    );
  }
}

/// Grouped form section with executive surface card shell.
class AksharaFormSection extends StatelessWidget {
  const AksharaFormSection({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.inCard = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool inCard;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: text.titleSmall.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AksharaSpacing.s1),
          Text(
            subtitle!,
            style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: AksharaSpacing.s4),
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1) const SizedBox(height: AksharaSpacing.s4),
        ],
      ],
    );

    if (!inCard) {
      return body;
    }

    return AksharaSurfaceCard(
      padding: const EdgeInsets.all(AksharaSpacing.s5),
      child: body,
    );
  }
}

/// Sticky form action bar for wizard / full-page forms.
class AksharaFormActions extends StatelessWidget {
  const AksharaFormActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.primaryKey,
    this.isLoading = false,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Key? primaryKey;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.65)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Row(
            children: [
              if (secondaryLabel != null && onSecondary != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: isLoading ? null : onSecondary,
                    child: Text(secondaryLabel!),
                  ),
                ),
                const SizedBox(width: AksharaSpacing.s3),
              ],
              Expanded(
                child: FilledButton(
                  key: primaryKey,
                  onPressed: isLoading ? null : onPrimary,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(primaryLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
