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
        actionRoute: attendance >= 90 ? null : '/teacher/attendance',
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
        // Substitutions has no top-level route of its own — it lives inside the
        // timetable hub — so send the principal to the hub rather than a link
        // that would 404. Verified against route_names, not assumed.
        actionLabel: 'Open timetable',
        actionRoute: '/teacher/timetable',
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
