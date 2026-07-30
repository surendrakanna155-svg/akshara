import '../../router/route_names.dart';
import '../security/permissions.dart';
import 'dai_intent.dart';

/// Digital Academic Intelligence — the deterministic intent layer.
///
/// Turns what a person types into what NIKSHA OS should do, **without a single
/// network call or token spent**. "Show fee defaulters", "students below 75%
/// attendance", "bus 5", "class 8A" are all answered here, on-device, in
/// microseconds.
///
/// ## Why this is not an LLM
///
/// A school ERP's search vocabulary is small, closed and highly repetitive. The
/// same forty phrasings cover most of what a principal will ever type. Routing
/// those through a model would be slower, cost money per keystroke, fail
/// offline, and — worst — occasionally hallucinate a destination. A deterministic
/// resolver is faster, free, works on a bad connection, and is *explainable*:
/// every answer can be traced to the rule that produced it.
///
/// Cloud AI stays for what genuinely needs generation — drafting a circular,
/// summarising a term's performance in prose. Not for "open Ravi".
///
/// ## Contract
///
/// * **Pure and synchronous.** No I/O, no clock, no randomness. Same input →
///   same output, forever. That is what makes the golden corpus in
///   `test/core/dai/dai_resolver_test.dart` a real certification.
/// * **Never guesses.** Below [minConfidence] it returns
///   [DaiIntentKind.unknown] so the UI can fall back to plain directory search
///   instead of confidently opening the wrong screen.
/// * **Resolves meaning, not access.** Every intent carries the [Permission]
///   its destination needs; the caller enforces it. The resolver has no idea
///   who is asking.
abstract final class DaiResolver {
  /// Anything scoring below this is treated as not understood. Set so that a
  /// bare name ("Rohan", score 60) still resolves to a person lookup, but a
  /// stray word does not drag a query into a wrong module.
  static const int minConfidence = 55;

  static DaiIntent resolve(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) return DaiIntent.unknown(query);

    final q = _normalise(query);

    // Order matters: the most specific patterns are tried first, so
    // "grade 10 fee defaulters" resolves as defaulters-scoped-to-a-class rather
    // than as a bare class lookup.
    for (final rule in _rules) {
      final hit = rule(q, query);
      if (hit != null && hit.confidence >= minConfidence) return hit;
    }
    return DaiIntent.unknown(query);
  }

  // ── Normalisation ────────────────────────────────────────────────────────
  // Lower-case, strip punctuation that carries no meaning, collapse whitespace.
  // '%' is KEPT — "below 75%" depends on it.
  static String _normalise(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r"[^\w\s%]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static final List<DaiIntent? Function(String, String)> _rules = [
    _receipt,
    _feeDefaulters,
    _lowAttendance,
    _transport,
    _attendanceToday,
    _homework,
    _exams,
    _myAttendance,
    _myFees,
    _classLookup,
    _person,
  ];

  // ── Entity extraction ────────────────────────────────────────────────────

  /// "class 8a", "grade 10", "10th", "8 a" → (class, section)
  static ({String? className, String? section}) _classOf(String q) {
    final m = RegExp(r'\b(?:class|grade|std|standard)\s*(\d{1,2})\s*([a-e])?\b')
        .firstMatch(q);
    if (m != null) {
      return (className: m.group(1), section: m.group(2)?.toUpperCase());
    }
    final ord = RegExp(r'\b(\d{1,2})(?:st|nd|rd|th)\b').firstMatch(q);
    if (ord != null) return (className: ord.group(1), section: null);
    return (className: null, section: null);
  }

  /// "below 75%", "under 60", "less than 80 percent" → 75 / 60 / 80
  static int? _thresholdOf(String q) {
    final m = RegExp(
      r'\b(?:below|under|less than|lower than|<)\s*(\d{1,3})\s*(?:%|percent|pct)?\b',
    ).firstMatch(q);
    if (m != null) return int.tryParse(m.group(1)!);
    // "75% attendance" with no comparator still reads as a ceiling in practice.
    final bare = RegExp(r'\b(\d{1,3})\s*(?:%|percent)\b').firstMatch(q);
    return bare != null ? int.tryParse(bare.group(1)!) : null;
  }

  static bool _has(String q, List<String> words) =>
      words.any((w) => RegExp('\\b${RegExp.escape(w)}\\b').hasMatch(q));

  // ── Rules ────────────────────────────────────────────────────────────────

  /// "fee receipt 1023", "receipt no 1023"
  static DaiIntent? _receipt(String q, String raw) {
    if (!_has(q, ['receipt'])) return null;
    final m = RegExp(r'\b(?:receipt|no|number)\s*#?\s*(\w*\d[\w\d]*)\b').firstMatch(q);
    final number = m?.group(1);
    if (number == null) return null;
    return DaiIntent(
      kind: DaiIntentKind.openReceipt,
      query: raw,
      route: RouteNames.financeCollections,
      receiptNumber: number,
      requiredPermission: Permission.viewFinance,
      confidence: 92,
      answer: 'Opening fee collections to find receipt $number.',
    );
  }

  /// "show fee defaulters", "grade 10 fee defaulters", "pending fees"
  static DaiIntent? _feeDefaulters(String q, String raw) {
    final feeWord = _has(q, ['fee', 'fees', 'dues', 'due']);
    final riskWord = _has(q, ['defaulter', 'defaulters', 'pending', 'unpaid', 'outstanding', 'overdue']);
    if (!(feeWord && riskWord) && !_has(q, ['defaulter', 'defaulters'])) return null;
    // "has my child paid fees" is a parent question, not a defaulters report.
    if (_has(q, ['my', 'child'])) return null;

    final cls = _classOf(q);
    final scope = cls.className != null
        ? ' for Class ${cls.className}${cls.section ?? ''}'
        : '';
    return DaiIntent(
      kind: DaiIntentKind.feeDefaulters,
      query: raw,
      route: RouteNames.financeDefaulters,
      className: cls.className,
      section: cls.section,
      requiredPermission: Permission.viewFinance,
      confidence: cls.className != null ? 95 : 90,
      answer: 'Showing students with outstanding fees$scope.',
    );
  }

  /// "students below 75% attendance", "attendance below 75"
  static DaiIntent? _lowAttendance(String q, String raw) {
    if (!_has(q, ['attendance', 'present', 'absent'])) return null;
    final threshold = _thresholdOf(q);
    if (threshold == null) return null;

    final cls = _classOf(q);
    final scope = cls.className != null
        ? ' in Class ${cls.className}${cls.section ?? ''}'
        : '';
    return DaiIntent(
      kind: DaiIntentKind.lowAttendance,
      query: raw,
      route: RouteNames.sisStudents,
      className: cls.className,
      section: cls.section,
      threshold: threshold,
      requiredPermission: Permission.viewSis,
      confidence: 94,
      answer: 'Showing students below $threshold% attendance$scope.',
    );
  }

  /// "bus 5", "transport route 3", "route 12"
  static DaiIntent? _transport(String q, String raw) {
    if (!_has(q, ['bus', 'transport', 'route', 'vehicle'])) return null;
    final m = RegExp(r'\b(?:bus|route|vehicle)\s*(?:no|number)?\s*(\d{1,3})\b')
        .firstMatch(q);
    final number = m != null ? int.tryParse(m.group(1)!) : null;
    return DaiIntent(
      kind: DaiIntentKind.openTransport,
      query: raw,
      route: RouteNames.transportRoutes,
      routeNumber: number,
      requiredPermission: Permission.viewTransport,
      confidence: number != null ? 93 : 78,
      answer: number != null
          ? 'Opening transport route $number.'
          : 'Opening transport routes.',
    );
  }

  /// "today's attendance", "attendance today"
  static DaiIntent? _attendanceToday(String q, String raw) {
    if (!_has(q, ['attendance'])) return null;
    if (!_has(q, ['today', 'todays', 'now', 'current'])) return null;
    if (_has(q, ['my'])) return null; // handled by _myAttendance

    final cls = _classOf(q);
    return DaiIntent(
      kind: DaiIntentKind.attendanceToday,
      query: raw,
      route: RouteNames.teacherAttendance,
      className: cls.className,
      section: cls.section,
      requiredPermission: Permission.viewAttendance,
      confidence: 90,
      answer: cls.className != null
          ? "Opening today's attendance for Class ${cls.className}${cls.section ?? ''}."
          : "Opening today's attendance.",
    );
  }

  /// "pending homework", "show homework", "homework pending"
  static DaiIntent? _homework(String q, String raw) {
    if (!_has(q, ['homework', 'assignment', 'assignments'])) return null;
    final pending = _has(q, ['pending', 'due', 'unsubmitted', 'not submitted', 'incomplete']);
    return DaiIntent(
      kind: DaiIntentKind.homework,
      query: raw,
      route: RouteNames.teacherHomework,
      // No dedicated view permission exists for homework — the teacher shell
      // guards the route by persona, so leave requiredPermission null rather
      // than invent a permission that RBAC does not know about.
      confidence: pending ? 92 : 85,
      answer: pending ? 'Showing pending homework.' : 'Opening homework.',
    );
  }

  /// "exam schedule", "my exam schedule", "exam results"
  static DaiIntent? _exams(String q, String raw) {
    if (!_has(q, ['exam', 'exams', 'test', 'result', 'results', 'marks'])) {
      return null;
    }
    final own = _has(q, ['my']);
    return DaiIntent(
      kind: DaiIntentKind.exams,
      query: raw,
      route: own ? RouteNames.studentExams : RouteNames.examAdministration,
      requiredPermission: own ? null : Permission.viewExams,
      confidence: 88,
      answer: own ? 'Opening your exam schedule.' : 'Opening exams.',
    );
  }

  /// "my attendance"
  static DaiIntent? _myAttendance(String q, String raw) {
    if (!_has(q, ['attendance'])) return null;
    if (!_has(q, ['my', 'mine'])) return null;
    return DaiIntent(
      kind: DaiIntentKind.myAttendance,
      query: raw,
      route: RouteNames.studentAttendance,
      confidence: 90,
      answer: 'Opening your attendance record.',
    );
  }

  /// "has my child paid fees", "my fees"
  static DaiIntent? _myFees(String q, String raw) {
    if (!_has(q, ['fee', 'fees', 'dues', 'paid', 'payment'])) return null;
    if (!_has(q, ['my', 'child', 'mine', 'ward'])) return null;
    return DaiIntent(
      kind: DaiIntentKind.myFees,
      query: raw,
      route: RouteNames.parentFees,
      confidence: 90,
      answer: 'Opening your fee summary and payment history.',
    );
  }

  /// "class 8a", "grade 10"
  static DaiIntent? _classLookup(String q, String raw) {
    final cls = _classOf(q);
    if (cls.className == null) return null;
    // A class number alone is only a class lookup when nothing else claimed it.
    return DaiIntent(
      kind: DaiIntentKind.openClass,
      query: raw,
      route: RouteNames.sisStudents,
      className: cls.className,
      section: cls.section,
      requiredPermission: Permission.viewSis,
      confidence: 82,
      answer:
          'Opening Class ${cls.className}${cls.section ?? ''} students.',
    );
  }

  /// "Rohan", "Teacher Ravi", "open teacher Ravi", "staff Priya"
  ///
  /// Returns an intent with a null route: the caller resolves the name against
  /// the directory (which is RBAC-scoped) and then opens the right dossier. The
  /// DAI layer deliberately does not hold a name index.
  static DaiIntent? _person(String q, String raw) {
    final staffWord = _has(q, ['teacher', 'staff', 'employee', 'sir', 'madam', 'principal']);
    final studentWord = _has(q, ['student', 'child', 'pupil']);

    var name = q
        .replaceAll(
          RegExp(r'\b(open|show|find|search|for|the|teacher|staff|employee|'
              r'student|child|pupil|sir|madam|principal|profile|details?)\b'),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (name.isEmpty) return null;
    // Reject anything with digits or more than three words — a person query is
    // short and alphabetic. This is what stops "grade 10 fee defaulters" from
    // being mistaken for a name once the earlier rules have declined it.
    if (RegExp(r'\d').hasMatch(name)) return null;
    final words = name.split(' ');
    if (words.length > 3) return null;
    if (name.length < 2) return null;
    // A bare two-word phrase is otherwise indistinguishable from a real name
    // ("Ravi Kumar"), so `DROP TABLE students` — which strips down to
    // "drop table" — was being offered as a person. Reject any query carrying a
    // token that cannot appear in a person's name. Caught by the fuzz suite.
    if (words.any(_nonNameTokens.contains)) return null;

    final hint = staffWord
        ? DaiPersonHint.staff
        : studentWord
            ? DaiPersonHint.student
            : DaiPersonHint.any;

    // An explicit qualifier ("teacher Ravi") is a much stronger signal than a
    // bare token, which might just be a word we do not know.
    final confidence = staffWord || studentWord ? 88 : 60;

    return DaiIntent(
      kind: DaiIntentKind.openPerson,
      query: raw,
      personName: _titleCase(name),
      personHint: hint,
      confidence: confidence,
      answer: 'Looking for ${_titleCase(name)}…',
    );
  }

  /// Tokens that can never be part of a person's name. Query-language and
  /// markup words are here because an unqualified two-word phrase is otherwise
  /// indistinguishable from a real name, and offering "Drop Table" as a person
  /// is both wrong and alarming to anyone watching a demo.
  static const Set<String> _nonNameTokens = {
    'drop', 'table', 'select', 'insert', 'delete', 'update', 'union', 'where',
    'from', 'script', 'alert', 'null', 'undefined', 'true', 'false',
    'and', 'or', 'not',
  };

  static String _titleCase(String s) => s
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}
