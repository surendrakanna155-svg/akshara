import 'package:flutter/material.dart';

/// Scrolls to the first invalid field in [formKey] after validation fails.
Future<void> scrollToFirstFormError({
  required GlobalKey<FormState> formKey,
  required ScrollController scrollController,
}) async {
  final valid = formKey.currentState?.validate() ?? false;
  if (valid) return;

  await Future<void>.delayed(Duration.zero);
  if (scrollController.hasClients) {
    await scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }
}

/// Chains focus nodes for keyboard "next" navigation.
void focusNextField(FocusNode current, FocusNode? next) {
  current.unfocus();
  next?.requestFocus();
}

/// Standard required-field validator.
String? requiredFieldValidator(String? value, {String fieldLabel = 'This field'}) {
  if (value == null || value.trim().isEmpty) {
    return '$fieldLabel is required';
  }
  return null;
}

/// Phone number validator (10+ digits).
String? phoneValidator(String? value) {
  final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
  if (digits.length < 10) {
    return 'Enter a valid 10-digit phone number';
  }
  return null;
}

/// Optional email validator.
String? emailValidator(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  if (!value.contains('@') || !value.contains('.')) {
    return 'Enter a valid email address';
  }
  return null;
}

/// Aadhaar validator (12 digits).
String? aadhaarValidator(String? value) {
  final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
  if (digits.length != 12) {
    return 'Aadhaar must be 12 digits';
  }
  return null;
}
