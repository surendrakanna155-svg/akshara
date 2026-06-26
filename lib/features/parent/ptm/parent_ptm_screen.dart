import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../parent_meetings/parent_meeting_detail_screen.dart';
import '../parent_active_child_provider.dart';
import 'parent_ptm_provider.dart';
import '../../../core/errors/api_failure_mapper.dart';

/// Parent mobile PTM — upcoming meetings and summaries for the active child.
class ParentPtmScreen extends ConsumerWidget {
  const ParentPtmScreen({
    super.key,
    this.onNotificationsTap,
  });

  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(parentActiveChildProvider);
    final meetingsAsync = ref.watch(parentChildMeetingsProvider);

    return Scaffold(
      key: QaTestKeys.parentPtmScreen,
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Parent-Teacher Meetings',
        subtitle: child?.name ?? 'Your child',
        showAi: false,
        onNotificationsTap: onNotificationsTap,
      ),
      body: meetingsAsync.when(
        loading: () => const AksharaLoadingState(),
        error: (error, _) => AksharaErrorState.fromFailure(apiFailureMapper.fromException(error)),
        data: (meetings) {
          if (meetings.isEmpty) {
            return const AksharaEmptyState(
              message: 'No scheduled meetings. Check school notices for PTM dates.',
              icon: Icons.groups_outlined,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AksharaSpacing.s4),
            itemCount: meetings.length,
            separatorBuilder: (_, __) => const SizedBox(height: AksharaSpacing.s3),
            itemBuilder: (context, index) {
              final meeting = meetings[index];
              return AksharaSurfaceCard(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ParentMeetingDetailScreen(meetingId: meeting.id),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meeting.teacherName,
                      style: context.aksharaText.titleMedium,
                    ),
                    const SizedBox(height: AksharaSpacing.s2),
                    Text(
                      meeting.meetingAt.toLocal().toString(),
                      style: context.aksharaText.bodyMedium,
                    ),
                    if (meeting.aiSummary?.isNotEmpty == true) ...[
                      const SizedBox(height: AksharaSpacing.s2),
                      Text(
                        meeting.aiSummary!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.aksharaText.bodySmall,
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
