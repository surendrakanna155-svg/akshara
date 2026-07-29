import 'package:flutter/material.dart';

import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../copilot/widgets/bottom_nav_ai_scope.dart';
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
    // Reserve the raised centre AI button's band. The FAB is docked directly
    // above the bottom navigation, so without this it sits ON TOP of "Pay Now"
    // — the one control on this screen that moves money. Same reservation the
    // payment screen's CTA bar already makes; this bar was simply missed.
    //
    // The reserve is added to BOTH the height and the bottom padding, so the
    // content row keeps its original 72dp box and only the clear space below
    // it grows. Zero when no scope is present, leaving other hosts unchanged.
    final reserved = BottomNavAiScope.reservedHeightOf(context);

    return Material(
      color: colors.surface,
      elevation: 8,
      shadowColor: colors.onSurface.withValues(alpha: 0.12),
      child: Container(
        height: height + reserved,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: colors.outlineVariant),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: AksharaSpacing.s4,
            right: AksharaSpacing.s4,
            top: AksharaSpacing.s3,
            bottom: AksharaSpacing.s3 + reserved,
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
