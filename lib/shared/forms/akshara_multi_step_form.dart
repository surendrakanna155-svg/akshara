import 'package:flutter/material.dart';

import '../../theme/spacing.dart';
import 'akshara_step_indicator.dart';

/// Shared scaffold for a multi-step form wizard.
///
/// Generalized from the admissions enrollment screen (B.4d). It owns the
/// common layout every wizard repeats — a [Form] wrapping a scrollable
/// `[step indicator + step content]` region above a pinned footer with a
/// trailing primary action (Continue / Submit) and an optional leading Back
/// button. The host screen keeps ownership of state, validation and the
/// per-step content; this widget only standardizes the chrome.
///
/// The footer is laid out as `[ leading?  ──spacer──  trailing ]`, matching
/// the existing "Back … Continue/Submit" pattern.
class AksharaMultiStepForm extends StatelessWidget {
  const AksharaMultiStepForm({
    super.key,
    required this.stepLabels,
    required this.currentIndex,
    required this.child,
    required this.trailing,
    this.leading,
    this.scrollController,
    this.formKey,
    this.autovalidateMode = AutovalidateMode.disabled,
  });

  /// Ordered labels, one per step (drives [AksharaStepIndicator]).
  final List<String> stepLabels;

  /// Zero-based index of the active step.
  final int currentIndex;

  /// The active step's content.
  final Widget child;

  /// Primary footer action (e.g. Continue / Submit), pinned to the trailing
  /// edge.
  final Widget trailing;

  /// Optional leading footer action (e.g. Back); omitted on the first step.
  final Widget? leading;

  /// Scroll controller for the content region — pass the host's controller so
  /// scroll-to-first-error keeps working.
  final ScrollController? scrollController;

  /// Optional form key; when provided the content is wrapped in a [Form].
  final GlobalKey<FormState>? formKey;

  /// Autovalidate mode for the wrapped [Form] (ignored when [formKey] is null).
  final AutovalidateMode autovalidateMode;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AksharaStepIndicator(
                  stepLabels: stepLabels,
                  currentIndex: currentIndex,
                ),
                const SizedBox(height: AksharaSpacing.s6),
                child,
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.only(top: AksharaSpacing.s4),
          child: Row(
            children: [
              if (leading != null) leading!,
              const Spacer(),
              trailing,
            ],
          ),
        ),
      ],
    );

    if (formKey == null) return body;

    return Form(
      key: formKey,
      autovalidateMode: autovalidateMode,
      child: body,
    );
  }
}
