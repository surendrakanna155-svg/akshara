import 'package:flutter/material.dart';

import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'fees_provider.dart';

/// PA-03 sticky CTA bar fixed above bottom navigation (390×72).
class PayNowBottomBar extends StatelessWidget {
  const PayNowBottomBar({
    super.key,
    required this.amountDue,
    required this.onPayNow,
    this.enabled = true,
  });

  final int amountDue;
  final VoidCallback? onPayNow;
  final bool enabled;

  static const double height = 72;
  static const double buttonWidth = 160;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Material(
      color: colors.surface,
      elevation: 8,
      shadowColor: colors.onSurface.withValues(alpha: 0.12),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: colors.outlineVariant),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AksharaSpacing.s4,
            vertical: AksharaSpacing.s3,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Amount due',
                      style: text.bodySmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      formatInr(amountDue),
                      style: text.titleMedium.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: buttonWidth,
                height: 48,
                child: FilledButton(
                  onPressed: enabled && amountDue > 0 ? onPayNow : null,
                  child: Text(
                    'Pay Now',
                    style: text.labelLarge.copyWith(
                      color: colors.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
