import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/communication/parent_communication_models.dart';
import '../../../core/i18n/content_localization.dart';
import '../../../core/i18n/supported_languages.dart';
import '../communication/parent_communication_inbox_provider.dart';
import '../exams/parent_exams_provider.dart';
import '../fees/fees_provider.dart';
import '../homework/parent_homework_provider.dart';
import '../parent_active_child_provider.dart';
import '../ptm/parent_ptm_provider.dart';

/// The kind of thing that needs a parent's action. Ordering here is the display
/// priority (fees + PTM first, per PAR-D4).
enum ParentActionKind { fee, ptm, form, homework, exam }

extension ParentActionKindX on ParentActionKind {
  /// Stable key used in QaTestKeys / analytics.
  String get key => name;

  IconData get icon => switch (this) {
        ParentActionKind.fee => Icons.payments_outlined,
        ParentActionKind.ptm => Icons.groups_outlined,
        ParentActionKind.form => Icons.assignment_turned_in_outlined,
        ParentActionKind.homework => Icons.assignment_outlined,
        ParentActionKind.exam => Icons.grading_outlined,
      };

  /// Deterministic catalog English phrase for this action's banner/inbox title.
  /// Localized via [ContentLocalization] (dictionary catalog) — NEVER an LLM.
  String get catalogTitle => switch (this) {
        ParentActionKind.fee => 'Fee payment is due',
        ParentActionKind.ptm => 'A parent-teacher meeting is scheduled',
        ParentActionKind.form => 'A message needs your acknowledgement',
        ParentActionKind.homework => 'Homework is due',
        ParentActionKind.exam => 'An exam is coming up',
      };

  /// Dashboard navigation action id this reminder routes to.
  String get navigationActionId => switch (this) {
        ParentActionKind.fee => 'fees',
        ParentActionKind.ptm => 'ptm',
        ParentActionKind.form => 'contact_teacher',
        ParentActionKind.homework => 'homework',
        ParentActionKind.exam => 'exams',
      };
}

/// A single "what needs my action" item for the active child. [title] is the
/// deterministic localized headline; [detail] is a factual, English-numeric
/// suffix (dates/amounts/counts) that is NOT translated (numbers/labels only).
@immutable
class ParentActionItem {
  const ParentActionItem({
    required this.id,
    required this.kind,
    required this.title,
    this.detail,
  });

  final String id;
  final ParentActionKind kind;
  final String title;
  final String? detail;
}

int _priority(ParentActionKind kind) => switch (kind) {
      ParentActionKind.fee => 0,
      ParentActionKind.ptm => 1,
      ParentActionKind.form => 2,
      ParentActionKind.homework => 3,
      ParentActionKind.exam => 4,
    };

/// Aggregated action items for the ACTIVE child, from REAL module data (fees,
/// PTM, communications-needing-ack, homework, exams). Titles come from the
/// deterministic content catalog in the parent's preferred language — no LLM.
///
/// Sorted fees + PTM first (PAR-D4). Powers both the PAR-5 dashboard banners
/// and the PAR-D4 action inbox.
final parentActiveChildActionsProvider =
    Provider<List<ParentActionItem>>((ref) {
  final child = ref.watch(parentActiveChildProvider);
  final language = child == null
      ? AksharaLanguage.english
      : ContentLocalization.languageForStudent(child.id);

  String localized(ParentActionKind kind) =>
      ContentLocalization.localize(kind.catalogTitle, language);

  final items = <ParentActionItem>[];

  // Fees — a real pending balance.
  final fees = ref.watch(parentFeesProvider);
  if (fees.hasPending) {
    items.add(ParentActionItem(
      id: 'fee',
      kind: ParentActionKind.fee,
      title: localized(ParentActionKind.fee),
      detail: '${formatInr(fees.pendingAmount)} · ${fees.dueLabel}',
    ));
  }

  // PTM — the next upcoming meeting (only when it still needs a response).
  final nextMeeting = ref.watch(parentNextMeetingProvider);
  if (nextMeeting != null && nextMeeting.rsvp == null) {
    items.add(ParentActionItem(
      id: 'ptm_${nextMeeting.id}',
      kind: ParentActionKind.ptm,
      title: localized(ParentActionKind.ptm),
      detail: nextMeeting.teacherName,
    ));
  }

  // Forms / messages needing acknowledgement (unread, not yet acknowledged).
  final inbox = ref.watch(parentCommunicationInboxProvider);
  final needsAck = inbox
      .where((item) =>
          item.isUnread &&
          item.deliveryStatus != ParentCommunicationDeliveryStatus.acknowledged)
      .toList(growable: false);
  if (needsAck.isNotEmpty) {
    items.add(ParentActionItem(
      id: 'form_${needsAck.first.id}',
      kind: ParentActionKind.form,
      title: localized(ParentActionKind.form),
      detail: needsAck.length == 1
          ? needsAck.first.reasonLabel
          : '${needsAck.length} messages',
    ));
  }

  // Homework — pending/overdue tasks.
  final homework = ref.watch(parentHomeworkDataProvider);
  final pendingHw = homework.pendingCount + homework.overdueCount;
  if (pendingHw > 0) {
    items.add(ParentActionItem(
      id: 'homework',
      kind: ParentActionKind.homework,
      title: localized(ParentActionKind.homework),
      detail: '$pendingHw pending',
    ));
  }

  // Exams — an upcoming exam.
  final exams = ref.watch(parentExamsProvider);
  if (exams.upcomingExams.isNotEmpty) {
    final next = exams.upcomingExams.first;
    items.add(ParentActionItem(
      id: 'exam_${next.id}',
      kind: ParentActionKind.exam,
      title: localized(ParentActionKind.exam),
      detail: '${next.subject} · ${next.dateLabel}',
    ));
  }

  items.sort((a, b) => _priority(a.kind).compareTo(_priority(b.kind)));
  return items;
});
