import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../parent/profile/widgets/profile_info_row.dart';
import 'profile_models.dart';
import 'student_profile_provider.dart';
import '../../../theme/breakpoints.dart';

/// Student profile — ST-07.
class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({
    super.key,
    this.onNotificationsTap,
    this.onSettingsTap,
  });

  final VoidCallback? onNotificationsTap;
  final VoidCallback? onSettingsTap;

  static const double _tabletBreakpoint = AksharaBreakpoints.tabletMinWidth;
  static const double _tabletMaxContentWidth = AksharaBreakpoints.compactContentMaxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(studentProfileLoadingProvider);
    final hasError = ref.watch(studentProfileErrorProvider);

    if (isLoading) {
      return Scaffold(
        backgroundColor: context.colors.surfaceContainerLow,
        appBar: _buildAppBar(context, schoolName: 'Akshara International School'),
        body: const AksharaLoadingState(semanticLabel: 'Loading profile'),
      );
    }

    if (hasError) {
      return Scaffold(
        backgroundColor: context.colors.surfaceContainerLow,
        appBar: _buildAppBar(context, schoolName: 'Akshara International School'),
        body: AksharaErrorState(
          message: 'Unable to load your profile right now.',
          onRetry: () =>
              ref.read(studentProfileErrorProvider.notifier).state = false,
        ),
      );
    }

    final data = ref.watch(studentProfileProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: _buildAppBar(context, schoolName: data.schoolName, unread: data.unreadNotifications),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= _tabletBreakpoint;
          final horizontalPadding = isTablet
              ? AksharaSpacing.tabletMargin
              : AksharaSpacing.mobileMargin;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    isTablet ? _tabletMaxContentWidth : double.infinity,
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
                      title: 'Student details',
                      fixedHeight: false,
                      spacingBelow: AksharaSpacing.s3,
                    ),
                    ProfileInfoRow(
                      icon: Icons.badge_outlined,
                      label: 'Roll number',
                      value: data.rollNo,
                    ),
                    const SizedBox(height: AksharaSpacing.s2),
                    ProfileInfoRow(
                      icon: Icons.numbers_outlined,
                      label: 'Admission no.',
                      value: data.admissionNo,
                    ),
                    const SizedBox(height: AksharaSpacing.s2),
                    ProfileInfoRow(
                      icon: Icons.cake_outlined,
                      label: 'Date of birth',
                      value: data.dateOfBirth,
                    ),
                    const SizedBox(height: AksharaSpacing.s2),
                    ProfileInfoRow(
                      icon: Icons.bloodtype_outlined,
                      label: 'Blood group',
                      value: data.bloodGroup,
                    ),
                    const SizedBox(height: AksharaSpacing.s4),
                    const AksharaSectionHeader(
                      title: 'Parent details',
                      fixedHeight: false,
                      spacingBelow: AksharaSpacing.s3,
                    ),
                    for (var i = 0; i < data.parentContacts.length; i++) ...[
                      _ParentContactCard(contact: data.parentContacts[i]),
                      if (i < data.parentContacts.length - 1)
                        const SizedBox(height: AksharaSpacing.s2),
                    ],
                    const SizedBox(height: AksharaSpacing.s4),
                    const AksharaSectionHeader(
                      title: 'Academic summary',
                      fixedHeight: false,
                      spacingBelow: AksharaSpacing.s3,
                    ),
                    for (var i = 0; i < data.academicSummary.length; i++) ...[
                      ProfileInfoRow(
                        icon: Icons.school_outlined,
                        label: data.academicSummary[i].label,
                        value: data.academicSummary[i].value,
                      ),
                      if (i < data.academicSummary.length - 1)
                        const SizedBox(height: AksharaSpacing.s2),
                    ],
                    const SizedBox(height: AksharaSpacing.s4),
                    const AksharaSectionHeader(
                      title: 'Settings',
                      fixedHeight: false,
                      spacingBelow: AksharaSpacing.s3,
                    ),
                    ProfileInfoRow(
                      key: QaTestKeys.appearanceSettingsLink,
                      icon: Icons.brightness_6_outlined,
                      label: 'Appearance',
                      value: 'Light, dark, or match your device',
                      onTap: () => context.push(RouteNames.appearanceSettings),
                    ),
                    const SizedBox(height: AksharaSpacing.s2),
                    Semantics(
                      button: true,
                      label: 'App settings, coming soon',
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: AksharaRadius.card,
                          side: BorderSide(
                            color: context.colors.outlineVariant,
                          ),
                        ),
                        tileColor: context.colors.surface,
                        leading: Icon(
                          Icons.settings_outlined,
                          color: context.colors.onSurfaceVariant,
                        ),
                        title: Text(
                          'App settings',
                          style: context.aksharaText.bodyLarge,
                        ),
                        subtitle: Text(
                          'Notifications, language, and privacy — coming soon',
                          style: context.aksharaText.bodySmall.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: context.colors.onSurfaceVariant,
                        ),
                        onTap: onSettingsTap,
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

  PreferredSizeWidget _buildAppBar(
    BuildContext context, {
    required String schoolName,
    int unread = 0,
  }) {
    return AksharaAppBar(
      titleText: 'Profile',
      subtitle: schoolName,
      unreadNotifications: unread,
      trailingPadding: true,
      onNotificationsTap: onNotificationsTap,
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({required this.data});

  final StudentProfileData data;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: 'Student ${data.studentName}, class ${data.classLabel}',
      child: Material(
        color: colors.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: AksharaRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: colors.primary,
                child: Text(
                  data.initials,
                  style: text.titleLarge.copyWith(color: colors.onPrimary),
                ),
              ),
              const SizedBox(width: AksharaSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.studentName,
                      style: text.titleMedium.copyWith(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Class ${data.classLabel}',
                      style: text.bodyMedium.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      data.schoolName,
                      style: text.bodySmall.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

class _ParentContactCard extends StatelessWidget {
  const _ParentContactCard({required this.contact});

  final ParentContact contact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.aksharaText;

    return Semantics(
      container: true,
      label: '${contact.relation} ${contact.name}',
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AksharaRadius.card,
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${contact.name} · ${contact.relation}',
                style: text.titleSmall.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: AksharaSpacing.s1),
              Text(
                contact.phoneLabel,
                style: text.bodySmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              Text(
                contact.email,
                style: text.bodySmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
