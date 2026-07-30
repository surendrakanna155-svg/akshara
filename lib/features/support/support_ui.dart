import 'package:flutter/material.dart';

import '../../theme/theme_extensions.dart';
import 'domain/support_delivery_failure.dart';
import 'domain/support_models.dart';

/// Presentation helpers for the support surface — status/severity tones, compact
/// timestamps and timeline labels. Kept out of the screens so all three share
/// exactly one visual language.

KpiAccent supportStatusTone(SupportStatus status) => switch (status) {
      SupportStatus.newIncident => KpiAccent.neutral,
      SupportStatus.triaging => KpiAccent.indigo,
      SupportStatus.inProgress => KpiAccent.primary,
      SupportStatus.awaitingCustomer => KpiAccent.warning,
      SupportStatus.resolved => KpiAccent.success,
      SupportStatus.closed => KpiAccent.neutral,
    };

KpiAccent supportSeverityTone(SupportSeverity severity) => switch (severity) {
      SupportSeverity.sev1 => KpiAccent.error,
      SupportSeverity.sev2 => KpiAccent.warning,
      SupportSeverity.sev3 => KpiAccent.primary,
      SupportSeverity.sev4 => KpiAccent.neutral,
    };

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Compact relative timestamp ("just now", "5m ago", "3h ago", "2d ago", else a
/// short date) — no `intl` dependency required.
String supportRelativeTime(DateTime at, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final diff = ref.difference(at);
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${at.day} ${_months[at.month - 1]}';
}

/// Absolute short date-time, e.g. `12 Jul 2026, 14:30`.
String supportDateTime(DateTime at) {
  final hh = at.hour.toString().padLeft(2, '0');
  final mm = at.minute.toString().padLeft(2, '0');
  return '${at.day} ${_months[at.month - 1]} ${at.year}, $hh:$mm';
}

/// Icon for a timeline event type.
IconData supportEventIcon(String eventType) => switch (eventType) {
      'created' => Icons.flag_outlined,
      'evidence_collected' => Icons.fact_check_outlined,
      'status_changed' => Icons.sync_alt,
      'assigned' => Icons.person_add_alt,
      'escalated' => Icons.priority_high,
      'ai_analyzed' => Icons.auto_awesome_outlined,
      'message_posted' => Icons.forum_outlined,
      'attachment_added' => Icons.attach_file,
      'resolved' => Icons.check_circle_outline,
      _ => Icons.circle_outlined,
    };

/// Human-readable timeline label for an event.
String supportEventLabel(SupportIncidentEvent event) {
  switch (event.eventType) {
    case 'created':
      return 'Issue reported';
    case 'evidence_collected':
      return 'Technical details collected automatically';
    case 'status_changed':
      final to = event.toValue == null
          ? ''
          : ' → ${SupportStatus.fromWire(event.toValue).label}';
      return 'Status changed$to';
    case 'assigned':
      return 'Assigned to support';
    case 'escalated':
      return 'Escalated';
    case 'ai_analyzed':
      return 'Investigated';
    case 'message_posted':
      return 'Message posted';
    case 'attachment_added':
      return 'Attachment added';
    case 'resolved':
      return 'Marked resolved';
    default:
      return event.eventType.replaceAll('_', ' ');
  }
}

// ---------------------------------------------------------------------------
// Honest-failure copy for the support WRITE path.
//
// One rule governs every string below: none of them may imply that NIKSHA
// Support received anything, and none of them is ever accompanied by a
// reference number. `reason == null` means the failure was not a recognised
// [SupportDeliveryFailure] — we genuinely do not know what happened, so we say
// exactly that rather than guessing in either direction.
// ---------------------------------------------------------------------------

/// Headline for a failed "Report an issue" submit.
String supportReportFailureHeadline(SupportDeliveryFailureReason? reason) {
  switch (reason) {
    case SupportDeliveryFailureReason.notConfigured:
      return 'Not sent — no support channel in this build';
    case SupportDeliveryFailureReason.notDelivered:
      return 'Not sent — we could not reach NIKSHA Support';
    case null:
      return 'Not sent — we could not confirm this reached NIKSHA Support';
  }
}

/// Body copy for a failed "Report an issue" submit. Says three things, in this
/// order: it was not sent, there is no ticket, your words are safe.
String supportReportFailureDetail(SupportDeliveryFailureReason? reason) {
  switch (reason) {
    case SupportDeliveryFailureReason.notConfigured:
      return 'This build has no live connection to NIKSHA Support, so your '
          'report was not sent and no ticket was created. What you typed is '
          'saved on this device.';
    case SupportDeliveryFailureReason.notDelivered:
      return 'Your report was not sent and no ticket was created. What you '
          'typed is saved on this device — check your internet connection and '
          'try again.';
    case null:
      return 'Something went wrong, so we are not showing you a reference '
          'number we cannot stand behind. Treat this report as not sent. What '
          'you typed is saved on this device — please try again.';
  }
}

/// Message for a failed reply on an existing incident.
String supportReplyFailureMessage(SupportDeliveryFailureReason? reason) {
  switch (reason) {
    case SupportDeliveryFailureReason.notConfigured:
      return 'Not sent. This build has no live connection to NIKSHA Support, '
          'so your message was not delivered.';
    case SupportDeliveryFailureReason.notDelivered:
      return 'Not sent. We could not reach NIKSHA Support. Your message is '
          'still here — check your connection and try again.';
    case null:
      return 'Not sent. We could not confirm NIKSHA Support received your '
          'message. Your message is still here — please try again.';
  }
}

/// The reason behind [error] when it is a [SupportDeliveryFailure], else null
/// (an unrecognised failure — see the `null` cases above).
SupportDeliveryFailureReason? supportFailureReasonOf(Object? error) =>
    error is SupportDeliveryFailure ? error.reason : null;
