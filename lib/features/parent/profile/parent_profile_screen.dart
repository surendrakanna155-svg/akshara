import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../auth/auth_logout.dart';
import '../../auth/auth_provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../parent_active_child_provider.dart';
import 'parent_profile_provider.dart';
import 'profile_models.dart';
import 'widgets/profile_child_row.dart';
import 'widgets/profile_info_row.dart';
import '../../../theme/breakpoints.dart';

/// Parent profile — PA-09.
class ParentProfileScreen extends ConsumerWidget {
  const ParentProfileScreen({
    super.key,
    this.onNotificationsTap,
    this.onSettingsTap,
    this.onReceiptsTap,
    this.onLeaveTap,
  });

  final VoidCallback? onNotificationsTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onReceiptsTap;
  final VoidCallback? onLeaveTap;

  static const double _tabletBreakpoint = AksharaBreakpoints.tabletMinWidth;
  static const double _tabletMaxContentWidth = AksharaBreakpoints.compactContentMaxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(parentProfileProvider);
    final isLoading = ref.watch(parentProfileLoadingProvider);
    final hasError = ref.watch(parentProfileErrorProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Profile',
        subtitle: data.schoolName,
        unreadNotifications: data.unreadNotifications,
        trailingPadding: true,
        onNotificationsTap: onNotificationsTap,
      ),
      body: isLoading
          ? const AksharaLoadingState(semanticLabel: 'Loading profile')
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load your profile right now.',
                  onRetry: () => ref
                      .read(parentProfileErrorProvider.notifier)
                      .state = false,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet =
                        constraints.maxWidth >= _tabletBreakpoint;
                    final horizontalPadding = isTablet
                        ? AksharaSpacing.tabletMargin
                        : AksharaSpacing.mobileMargin;

                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isTablet
                              ? _tabletMaxContentWidth
                              : double.infinity,
                        ),
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            AksharaSpacing.s4,
                            horizontalPadding,
                            AksharaSpacing.s6,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ProfileHeroCard(data: data),
                              const SizedBox(height: AksharaSpacing.s4),
                              const AksharaSectionHeader(
                                title: 'Contact',
                                fixedHeight: false,
                                spacingBelow: AksharaSpacing.s3,
                              ),
                              ProfileInfoRow(
                                icon: Icons.phone_outlined,
                                label: 'Phone',
                                value: data.phoneLabel,
                              ),
                              const SizedBox(height: AksharaSpacing.s2),
                              ProfileInfoRow(
                                icon: Icons.email_outlined,
                                label: 'Email',
                                value: data.email,
                              ),
                              const SizedBox(height: AksharaSpacing.s4),
                              AksharaSectionHeader(
                                title: 'Children',
                                trailingLabel: '${data.childrenCount} linked',
                                fixedHeight: false,
                                spacingBelow: AksharaSpacing.s3,
                              ),
                              Column(
                                children: [
                                  for (var i = 0; i < data.children.length; i++) ...[
                                    ProfileChildRow(
                                      child: data.children[i],
                                      onTap: () async {
                                        final profileId = data.children[i].id;
                                        final authId =
                                            kProfileChildToAuthId[profileId] ?? profileId;
                                        final linked = ref
                                            .read(authProvider)
                                            .linkedChildren
                                            .where((c) => c.id == authId)
                                            .firstOrNull;
                                        if (linked != null) {
                                          await selectParentActiveChild(ref, linked);
                                        }
                                        ref.read(parentProfileActiveChildProvider.notifier).state =
                                            profileId;
                                        ref.invalidate(parentProfileFutureProvider);
                                      },
                                    ),
                                    if (i < data.children.length - 1)
                                      const SizedBox(height: AksharaSpacing.s2),
                                  ],
                                ],
                              ),
                              const SizedBox(height: AksharaSpacing.s4),
                              const AksharaSectionHeader(
                                title: 'School',
                                fixedHeight: false,
                                spacingBelow: AksharaSpacing.s3,
                              ),
                              ProfileInfoRow(
                                icon: Icons.school_outlined,
                                label: 'Institution',
                                value: data.schoolName,
                              ),
                              const SizedBox(height: AksharaSpacing.s4),
                              const AksharaSectionHeader(
                                title: 'Family services',
                                fixedHeight: false,
                                spacingBelow: AksharaSpacing.s3,
                              ),
                              ProfileInfoRow(
                                icon: Icons.receipt_long_outlined,
                                label: 'Fee receipts',
                                value: 'View and download payment receipts',
                                onTap: onReceiptsTap,
                              ),
                              const SizedBox(height: AksharaSpacing.s2),
                              ProfileInfoRow(
                                icon: Icons.beach_access_outlined,
                                label: 'Leave requests',
                                value: 'Apply leave and track approvals',
                                onTap: onLeaveTap,
                              ),
                              const SizedBox(height: AksharaSpacing.s4),
                              ProfileInfoRow(
                                key: QaTestKeys.aiAssistantSettingsLink,
                                icon: Icons.psychology_outlined,
                                label: 'AI Assistant',
                                value: 'Choose how AI appears in the app',
                                onTap: () => context.push(RouteNames.aiAssistantSettings),
                              ),
                              const SizedBox(height: AksharaSpacing.s4),
                              AksharaInsightCard(
                                message:
                                    'Manage notification preferences and app security from settings.',
                                actionLabel: 'Open settings',
                                onAction: onSettingsTap,
                              ),
                              const SizedBox(height: AksharaSpacing.s6),
                              OutlinedButton.icon(
                                key: QaTestKeys.logoutButton,
                                onPressed: () => confirmAndLogout(context, ref),
                                icon: Icon(
                                  Icons.logout,
                                  color: context.colors.error,
                                ),
                                label: Text(
                                  'Log out',
                                  style: TextStyle(
                                    color: context.colors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  side: BorderSide(
                                    color: context.colors.error.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AksharaRadius.button,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({required this.data});

  final ParentProfileData data;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Parent profile ${data.parentName}',
      child: Material(
        color: colors.surface,
        elevation: 1,
        shadowColor: colors.onSurface.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: AksharaRadius.card,
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: colors.primaryContainer,
                child: Text(
                  data.initials,
                  style: text.titleMedium.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: AksharaSpacing.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.parentName,
                      style: text.titleMedium.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AksharaSpacing.s1),
                    Text(
                      'Parent · ${data.childrenCount} children',
                      style: text.bodySmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
