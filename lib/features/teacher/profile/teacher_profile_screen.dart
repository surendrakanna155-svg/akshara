import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../router/route_names.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/radius.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../auth/auth_provider.dart';
import '../../parent/profile/widgets/profile_info_row.dart';
import '../communication/teacher_teaching_context_provider.dart';

/// Teacher profile — a dedicated identity screen for the teacher persona
/// (previously only a Settings screen existed, so a teacher had nowhere to see
/// their own profile). Shows the teaching identity resolved from HR/SIS data and
/// links to the shared device preferences.
///
/// NOTE: a full teacher *profile* data model (employee ID, designation,
/// qualifications, emergency contact) does not exist yet — those fields arrive
/// with the HR backend. This screen surfaces every identity field available
/// today and is structured so the extra fields drop in without a rewrite.
class TeacherProfileScreen extends ConsumerWidget {
  const TeacherProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teaching = ref.watch(resolvedTeacherTeachingContextProvider);
    final auth = ref.watch(authProvider);
    final colors = context.colors;
    final text = context.aksharaText;

    final name = teaching.teacherName;
    final roleLabel =
        teaching.isClassTeacher ? 'Class Teacher' : 'Subject Teacher';
    final initials = _initials(name);
    final classTeacherOf = teaching.classTeacherClassLabel;
    final classesTaught = teaching.teachingClassLabels.isEmpty
        ? '—'
        : teaching.teachingClassLabels.join(', ');

    return Scaffold(
      key: QaTestKeys.teacherProfileScreen,
      backgroundColor: colors.surfaceContainerLow,
      appBar: const AksharaAppBar(
        titleText: 'My Profile',
        subtitle: 'Your teaching identity',
        trailingPadding: true,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AksharaSpacing.mobileMargin,
              AksharaSpacing.s4,
              AksharaSpacing.mobileMargin,
              AksharaSpacing.s6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Identity header.
                Material(
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
                          radius: 32,
                          backgroundColor: colors.primaryContainer,
                          child: Text(
                            initials,
                            style: text.titleLarge.copyWith(
                              color: colors.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: AksharaSpacing.s4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: text.titleLarge
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: AksharaSpacing.s1),
                              Text(
                                '$roleLabel · ${teaching.primarySubject}',
                                style: text.bodyMedium
                                    .copyWith(color: colors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AksharaSpacing.s4),
                const AksharaSectionHeader(
                  title: 'Teaching details',
                  fixedHeight: false,
                  spacingBelow: AksharaSpacing.s3,
                ),
                ProfileInfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Teacher ID',
                  value: teaching.teacherId,
                ),
                const SizedBox(height: AksharaSpacing.s2),
                ProfileInfoRow(
                  icon: Icons.menu_book_outlined,
                  label: 'Primary subject',
                  value: teaching.primarySubject,
                ),
                if (classTeacherOf != null) ...[
                  const SizedBox(height: AksharaSpacing.s2),
                  ProfileInfoRow(
                    icon: Icons.groups_outlined,
                    label: 'Class teacher of',
                    value: 'Class $classTeacherOf',
                  ),
                ],
                const SizedBox(height: AksharaSpacing.s2),
                ProfileInfoRow(
                  icon: Icons.class_outlined,
                  label: 'Classes taught',
                  value: classesTaught,
                ),
                if (auth.phoneNumber != null &&
                    auth.phoneNumber!.isNotEmpty) ...[
                  const SizedBox(height: AksharaSpacing.s2),
                  ProfileInfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: auth.phoneNumber!,
                  ),
                ],
                const SizedBox(height: AksharaSpacing.s4),
                const AksharaSectionHeader(
                  title: 'Account',
                  fixedHeight: false,
                  spacingBelow: AksharaSpacing.s3,
                ),
                ProfileInfoRow(
                  key: QaTestKeys.teacherProfileSettingsLink,
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  value: 'Appearance, AI Assistant',
                  onTap: () => context.push(RouteNames.teacherSettings),
                ),
                const SizedBox(height: AksharaSpacing.s2),
                ProfileInfoRow(
                  icon: Icons.gavel_outlined,
                  label: 'Terms & Policies',
                  value: 'Review the terms you accepted',
                  onTap: () => context.push(RouteNames.legalAcceptance),
                ),
                const SizedBox(height: AksharaSpacing.s3),
                Text(
                  'More profile details (designation, qualifications, '
                  'emergency contact) will appear here once HR records are '
                  'connected.',
                  style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
