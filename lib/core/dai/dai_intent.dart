import '../security/permissions.dart';

/// What the user is asking for. One value per thing NIKSHA OS can actually do —
/// never a generic "search" catch-all, because the whole point of the DAI layer
/// is that the system *knows* what was meant before it moves.
enum DaiIntentKind {
  /// Fee defaulters / pending dues, optionally scoped to a class.
  feeDefaulters,

  /// Students under an attendance threshold ("below 75%").
  lowAttendance,

  /// Today's attendance position for the school / a class.
  attendanceToday,

  /// Open a specific person's dossier (student or staff).
  openPerson,

  /// A class's roster / overview ("Class 8A").
  openClass,

  /// A transport route or a specific bus.
  openTransport,

  /// Homework — pending, or the module itself.
  homework,

  /// Exam schedule / results.
  exams,

  /// A fee receipt by number.
  openReceipt,

  /// The signed-in user's own attendance (parent asks about their child).
  myAttendance,

  /// The signed-in user's own fee position.
  myFees,

  /// Nothing matched with enough confidence.
  unknown,
}

/// Who a person-shaped query refers to, when the query says so explicitly
/// ("Teacher Ravi" vs "Rohan").
enum DaiPersonHint { student, staff, any }

/// A resolved intent: what the user meant, what NIKSHA OS should show them, and
/// what to say while showing it.
///
/// Deliberately carries **no free text from a model**. [answer] is composed from
/// the resolved fields by [DaiResolver], so the sentence a user reads is always
/// reproducible from the query — auditable, and identical on every device.
class DaiIntent {
  const DaiIntent({
    required this.kind,
    required this.query,
    this.route,
    this.answer = '',
    this.personName,
    this.personHint = DaiPersonHint.any,
    this.className,
    this.section,
    this.threshold,
    this.routeNumber,
    this.receiptNumber,
    this.requiredPermission,
    this.confidence = 0,
  });

  const DaiIntent.unknown(this.query)
      : kind = DaiIntentKind.unknown,
        route = null,
        answer = '',
        personName = null,
        personHint = DaiPersonHint.any,
        className = null,
        section = null,
        threshold = null,
        routeNumber = null,
        receiptNumber = null,
        requiredPermission = null,
        confidence = 0;

  final DaiIntentKind kind;

  /// The raw query, kept for logging and for the "did you mean" fallback.
  final String query;

  /// Where to navigate. Null when the intent is understood but the caller must
  /// resolve an id first (e.g. [DaiIntentKind.openPerson] needs a directory
  /// lookup before it knows which dossier to open).
  final String? route;

  /// A short, natural sentence to show the user. Composed deterministically.
  final String answer;

  final String? personName;
  final DaiPersonHint personHint;

  /// Normalised class label, e.g. "10" or "8".
  final String? className;

  /// Section letter when the query carried one, e.g. "A" from "Class 8A".
  final String? section;

  /// Percentage threshold from queries like "below 75%".
  final int? threshold;

  /// Bus / transport route number.
  final int? routeNumber;

  final String? receiptNumber;

  /// Permission the destination requires. The caller must check this before
  /// navigating — the DAI layer resolves meaning, it does not grant access.
  final Permission? requiredPermission;

  /// 0–100. Below [DaiResolver.minConfidence] the resolver returns
  /// [DaiIntentKind.unknown] rather than guess.
  final int confidence;

  bool get isResolved => kind != DaiIntentKind.unknown;

  /// True when the caller still has to look up an entity id before navigating.
  bool get needsDirectoryLookup =>
      kind == DaiIntentKind.openPerson && route == null;

  @override
  String toString() =>
      'DaiIntent(${kind.name}, conf=$confidence, route=$route, '
      'person=$personName, class=$className$section, threshold=$threshold)';
}
