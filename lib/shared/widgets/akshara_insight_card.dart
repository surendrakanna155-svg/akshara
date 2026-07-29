import 'package:flutter/material.dart';

import '../../theme/theme_extensions.dart';
import 'premium/akshara_ai_suggestion_bar.dart';

/// AI insight strip shared across parent, teacher, student, and ERP dashboards.
///
/// Phase B (Premium School OS rollout): this now renders the premium
/// [AksharaAiSuggestionBar] — a brand-gradient "intelligent product" surface —
/// so every AI insight across the app shares one consistent premium look. The
/// constructor keeps its original parameters for source compatibility with the
/// ~57 call sites; [accent] and [icon] are retained for API compatibility but
/// the premium bar uses the canonical brand gradient + spark badge.
class AksharaInsightCard extends StatelessWidget {
  const AksharaInsightCard({
    super.key,
    required this.message,
    required this.actionLabel,
    this.onAction,
    this.accent = KpiAccent.primary,
    this.icon = Icons.psychology_outlined,
    this.semanticLabelPrefix = 'AI insight',
    this.eyebrow = 'NIKSHA SUGGESTS',
  });

  final String message;
  final String actionLabel;
  final VoidCallback? onAction;
  final KpiAccent accent;
  final IconData icon;
  final String semanticLabelPrefix;
  final String eyebrow;

  @override
  Widget build(BuildContext context) {
    return AksharaAiSuggestionBar(
      message: message,
      eyebrow: eyebrow,
      actionLabel: actionLabel.isEmpty ? null : actionLabel,
      onAction: onAction,
      semanticLabelPrefix: semanticLabelPrefix,
    );
  }
}
