import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/entitlements/entitlement_models.dart';
import '../../core/entitlements/entitlement_provider.dart';
import '../../core/repositories/repository_config.dart';
import '../../router/route_names.dart';
import '../../theme/spacing.dart';
import '../../theme/theme_extensions.dart';

/// Small read-only plan chip for the admin header. Tapping opens the
/// Plan & Entitlements screen. Renders nothing when the entitlement layer is
/// disabled, so the pre-B2 chrome is unchanged.
class PlanBadge extends ConsumerWidget {
  const PlanBadge({super.key, this.padding});

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(entitlementApiEnabledProvider)) {
      return const SizedBox.shrink();
    }
    final subscription = ref.watch(subscriptionProvider);
    final colors = context.colors;
    final scheme = _statusScheme(subscription.status, colors);

    return Padding(
      padding: padding ??
          const EdgeInsets.fromLTRB(
            AksharaSpacing.s4,
            AksharaSpacing.s2,
            AksharaSpacing.s4,
            AksharaSpacing.s1,
          ),
      child: Tooltip(
        message: 'View plan & entitlements',
        child: Material(
          color: scheme.background,
          shape: StadiumBorder(
            side: BorderSide(color: scheme.foreground.withValues(alpha: 0.35)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.go(RouteNames.planEntitlements),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AksharaSpacing.s3,
                vertical: AksharaSpacing.s1,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium_outlined,
                      size: 16, color: scheme.foreground),
                  const SizedBox(width: AksharaSpacing.s1),
                  Flexible(
                    child: Text(
                      subscription.planName,
                      overflow: TextOverflow.ellipsis,
                      style: context.aksharaText.labelMedium.copyWith(
                            color: scheme.foreground,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _BadgeScheme _statusScheme(SubscriptionStatus status, ColorScheme colors) {
    return switch (status) {
      SubscriptionStatus.suspended => _BadgeScheme(
          colors.errorContainer, colors.onErrorContainer),
      SubscriptionStatus.grace => _BadgeScheme(
          colors.tertiaryContainer, colors.onTertiaryContainer),
      _ => _BadgeScheme(
          colors.primaryContainer, colors.onPrimaryContainer),
    };
  }
}

class _BadgeScheme {
  const _BadgeScheme(this.background, this.foreground);
  final Color background;
  final Color foreground;
}
