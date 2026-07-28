// ============================================================================
// STATUS: NOT WIRED. This composer has ZERO production call sites and is
//         deliberately NOT rendered in the v1.0 release. Do not "just hook it
//         up" — read the four gaps below first.
// ============================================================================
//
// The composition logic in this file is sound and proven: it is pure (no
// imports beyond route constants, no clock, no randomness, no I/O), so the same
// facts always compose the same brief, and that is pinned by a repeat-
// invocation test. What is missing is everything AROUND it.
//
// ## Why it is not surfaced in v1.0
//
// The principal already has a live, backend-scored surface that does this job:
// `AdaptivePriorityFeedSection` plus the priorities list in
// `lib/features/management/widgets/management_principal_overview_panel.dart`.
// Rendering this brief beside it would show pending approvals a THIRD time on
// one screen (priorities list · alert banner · brief). Two competing "what
// matters today" surfaces is worse than one that works.
//
// ## What must exist before it can be surfaced
//
// 1. A FACTS PRODUCER. `DaiBriefFacts` is 11 bare scalars and nothing computes
//    it. `ManagementDashboardData` can supply at most 5 (approvals count, the
//    three fee figures, admissions). The other 6 —`attendancePercentToday`,
//    `staffAbsentToday`, `atRiskStudents`, `unsubmittedMarksClasses`,
//    `expiringStaffDocuments` — live in attendance, HR, exams and intelligence,
//    each needing its own provider, RBAC scope and loading/error state. Until
//    then a rendered brief would silently omit most of its lines.
//
// 2. APPROVAL-STATE FILTERING. The stated requirement is that the brief must
//    not re-surface what the principal already acted on. `pendingApprovals` is
//    a bare `int` with no link to `ApprovalStatus` or
//    `ApprovalCenterService.listPending` (`lib/core/approvals/`). As written,
//    the brief would keep counting items that were approved minutes ago.
//
// 3. EXCEPTION-FIRST SEVERITY ORDERING. The design intent is exception-first,
//    but roughly half the current output is EVENTS, not exceptions: healthy
//    attendance, staff absence, admissions joined, and a "no defaulters" line
//    that fires precisely when nothing is wrong. A real severity rank — and a
//    decision on which of these earn a line at all — is still owed.
//
// 4. ROUTE REACHABILITY. Fixed here (see below), but the class of bug must stay
//    fixed: a principal is `UserRole.staff` WITHOUT `ErpRole.teacher`, so any
//    `/teacher/*` route bounces them to `/admin`. Every action route must be an
//    admin-ERP route; `dai_brief_test.dart` now asserts exactly that.
//
// Items 1–3 are feature work, not release hardening. See
// `docs/roadmap/RC_EXECUTION_LOG.md` for the RC decision and its rationale.

import '../../router/route_names.dart';

/// A single line in the principal's morning brief.
class DaiBriefLine {
  const DaiBriefLine({
    required this.text,
    required this.tone,
    this.actionLabel,
    this.actionRoute,
  });

  final String text;
  final DaiBriefTone tone;

  /// A next step, when there is an obvious one. Null when the line is purely
  /// informational — a brief that ends every sentence with a button is noise.
  final String? actionLabel;
  final String? actionRoute;

  bool get hasAction => actionLabel != null && actionRoute != null;
}

/// How urgently a line should read. Drives colour only — never invented.
enum DaiBriefTone { critical, warning, positive, neutral }

/// Facts the brief is composed from. Plain numbers, already computed by the
/// modules that own them — the composer does no arithmetic on money and no
/// inference. If a field is null the corresponding line is simply not written,
/// which is how the brief stays honest on a school that does not use a module.
class DaiBriefFacts {
  const DaiBriefFacts({
    this.pendingApprovals = 0,
    this.feeDefaulters = 0,
    this.feeCollectionRate,
    this.feeOutstanding,
    this.admissionsJoinedMtd,
    this.admissionsLeadsMtd,
    this.attendancePercentToday,
    this.staffAbsentToday,
    this.atRiskStudents = 0,
    this.unsubmittedMarksClasses = 0,
    this.expiringStaffDocuments = 0,
  });

  final int pendingApprovals;
  final int feeDefaulters;
  final String? feeCollectionRate;
  final String? feeOutstanding;
  final int? admissionsJoinedMtd;
  final int? admissionsLeadsMtd;
  final int? attendancePercentToday;
  final int? staffAbsentToday;
  final int atRiskStudents;
  final int unsubmittedMarksClasses;
  final int expiringStaffDocuments;
}

/// Composes the Principal's Morning Brief — deterministically.
///
/// **NOT WIRED IN v1.0 — no production caller. See the STATUS block at the top
/// of this file for the four gaps that must close before this is rendered.**
///
/// This is what an "AI briefing" should be in a school ERP: the system already
/// knows the numbers, so the intelligence is in **choosing what is worth saying
/// and in what order**, not in generating prose. Every sentence here is composed
/// from a typed fact by a rule you can read.
///
/// ## Why no LLM
///
/// A generated brief would cost money every morning for every principal, need a
/// connection at 8am, vary between two principals reading the same numbers, and
/// could — occasionally — state a figure the database does not contain. That
/// last failure mode is disqualifying: a brief that mis-states fee collection
/// once destroys trust in every brief after it.
///
/// The composer is pure: same facts in, same brief out, on every device and
/// every run. It never rounds, restates or re-derives a money figure — it prints
/// what finance computed.
///
/// ## Ordering
///
/// Lines come out in the order a principal should act on them: things that
/// block other people first (approvals), then money, then children at risk,
/// then operations. A brief sorted by module instead of by urgency is a report,
/// not a brief.
abstract final class DaiBriefComposer {
  /// Composes the brief. Returns an empty list when there is genuinely nothing
  /// worth saying — the UI then shows a calm "all clear", which is far more
  /// trustworthy than manufacturing filler.
  static List<DaiBriefLine> compose(DaiBriefFacts f) {
    final lines = <DaiBriefLine>[];

    // 1. Things blocking other people.
    if (f.pendingApprovals > 0) {
      lines.add(DaiBriefLine(
        text: f.pendingApprovals == 1
            ? '1 approval is waiting on you.'
            : '${f.pendingApprovals} approvals are waiting on you.',
        tone: f.pendingApprovals >= 5 ? DaiBriefTone.critical : DaiBriefTone.warning,
        actionLabel: 'Review',
        actionRoute: '/management/approvals',
      ));
    }

    if (f.unsubmittedMarksClasses > 0) {
      lines.add(DaiBriefLine(
        text: f.unsubmittedMarksClasses == 1
            ? '1 class has not submitted marks yet.'
            : '${f.unsubmittedMarksClasses} classes have not submitted marks yet.',
        tone: DaiBriefTone.warning,
        actionLabel: 'Open exams',
        actionRoute: '/school/exam-administration',
      ));
    }

    // 2. Money.
    if (f.feeDefaulters > 0) {
      final outstanding = f.feeOutstanding;
      lines.add(DaiBriefLine(
        text: outstanding != null && outstanding.isNotEmpty
            ? '${f.feeDefaulters} students have fees outstanding ($outstanding).'
            : '${f.feeDefaulters} students have fees outstanding.',
        tone: f.feeDefaulters >= 25 ? DaiBriefTone.critical : DaiBriefTone.warning,
        actionLabel: 'See defaulters',
        actionRoute: '/finance/defaulters',
      ));
    } else if (f.feeCollectionRate != null) {
      lines.add(DaiBriefLine(
        text: 'Fee collection is at ${f.feeCollectionRate}, with no defaulters.',
        tone: DaiBriefTone.positive,
      ));
    }

    // 3. Children.
    if (f.atRiskStudents > 0) {
      lines.add(DaiBriefLine(
        text: f.atRiskStudents == 1
            ? '1 student is flagged at risk.'
            : '${f.atRiskStudents} students are flagged at risk.',
        tone: DaiBriefTone.critical,
        actionLabel: 'Open list',
        actionRoute: '/sis/students',
      ));
    }

    final attendance = f.attendancePercentToday;
    if (attendance != null) {
      lines.add(DaiBriefLine(
        // The threshold wording is deliberate: "below the usual" is a
        // comparison the system can defend; "concerning" would be a judgement
        // it cannot.
        text: attendance >= 90
            ? "Attendance is $attendance% today."
            : 'Attendance is $attendance% today — below the usual range.',
        tone: attendance >= 90
            ? DaiBriefTone.positive
            : attendance >= 80
                ? DaiBriefTone.warning
                : DaiBriefTone.critical,
        actionLabel: attendance >= 90 ? null : 'Open attendance',
        // NOT `/teacher/attendance`: that is a teacher-persona route, and a
        // principal is `UserRole.staff` without `ErpRole.teacher`, so the router
        // would bounce them to `/admin` (app_router.dart `_canAccessRoute`).
        // School-wide attendance for a principal lives in management analytics —
        // the same destination the live overview panel's Attendance tile uses.
        actionRoute: attendance >= 90 ? null : RouteNames.managementAnalytics,
      ));
    }

    // 4. Operations.
    final absent = f.staffAbsentToday;
    if (absent != null && absent > 0) {
      lines.add(DaiBriefLine(
        text: absent == 1
            ? '1 staff member is absent today.'
            : '$absent staff members are absent today.',
        tone: absent >= 5 ? DaiBriefTone.warning : DaiBriefTone.neutral,
        // Substitutions DOES have a top-level route — RouteNames.substituteManager
        // (`/school/timetables/substitute`), registered via
        // substituteManagerRouteBuilder. The previous comment here claimed
        // otherwise and said it had been "verified against route_names, not
        // assumed"; it had not been, and it sent the principal to
        // `/teacher/timetable` instead. That is a teacher-shell route, and a
        // principal is UserRole.staff without ErpRole.teacher, so the router
        // would have silently bounced them to /admin — an action link that
        // quietly does nothing. Route to the surface that actually answers
        // "who is covering these periods?".
        actionLabel: 'Open substitutions',
        actionRoute: RouteNames.substituteManager,
      ));
    }

    if (f.expiringStaffDocuments > 0) {
      lines.add(DaiBriefLine(
        text: f.expiringStaffDocuments == 1
            ? '1 staff document expires within 30 days.'
            : '${f.expiringStaffDocuments} staff documents expire within 30 days.',
        tone: DaiBriefTone.warning,
        actionLabel: 'Open HR',
        actionRoute: '/hr/employees',
      ));
    }

    // 5. Good news last — a principal should not have to scroll past it to
    //    reach a problem, but it is worth saying.
    final joined = f.admissionsJoinedMtd;
    if (joined != null && joined > 0) {
      lines.add(DaiBriefLine(
        text: f.admissionsLeadsMtd != null && f.admissionsLeadsMtd! > 0
            ? '$joined admissions joined this month, from ${f.admissionsLeadsMtd} enquiries.'
            : '$joined admissions joined this month.',
        tone: DaiBriefTone.positive,
      ));
    }

    return lines;
  }

  /// A one-line summary for collapsed surfaces. Empty when the brief is empty.
  static String headline(List<DaiBriefLine> lines) {
    if (lines.isEmpty) return 'Nothing needs your attention this morning.';
    final urgent =
        lines.where((l) => l.tone == DaiBriefTone.critical).length;
    if (urgent > 0) {
      return urgent == 1
          ? '1 thing needs your attention'
          : '$urgent things need your attention';
    }
    return '${lines.length} update${lines.length == 1 ? '' : 's'} this morning';
  }
}
