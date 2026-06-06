import 'package:flutter/material.dart';

import '../../../../theme/radius.dart';
import '../../../../theme/spacing.dart';
import '../../../../theme/theme_extensions.dart';
import '../payment_models.dart';

/// Payment method picker for PA-10.
class PaymentMethodSelector extends StatelessWidget {
  const PaymentMethodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Payment method selector',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final method in PaymentMethod.values) ...[
            Semantics(
              button: true,
              selected: selected == method,
              label: method.label,
              child: Material(
                color: colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: AksharaRadius.card,
                  side: BorderSide(
                    color: selected == method
                        ? colors.primary
                        : colors.outlineVariant,
                  ),
                ),
                child: InkWell(
                  onTap: () => onChanged(method),
                  borderRadius: AksharaRadius.card,
                  child: SizedBox(
                    height: 56,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AksharaSpacing.s4,
                      ),
                      child: Row(
                        children: [
                          Icon(method.icon, color: colors.primary),
                          const SizedBox(width: AksharaSpacing.s3),
                          Expanded(
                            child: Text(
                              method.label,
                              style: text.bodyMedium.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            selected == method
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: selected == method
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (method != PaymentMethod.values.last)
              const SizedBox(height: AksharaSpacing.s2),
          ],
        ],
      ),
    );
  }
}
