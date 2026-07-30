// Cap 73 (owner decision #5) — mid-year admission fee proration.
//
// Dart-side mirror of supabase/functions/_shared/finance/finance_fee_proration.ts
// (the SERVER remains the source of truth for every real money computation —
// see that file's header for the full policy/basis/no-drift rationale). This
// port exists so [MockFinanceRepository] (offline/demo mode) can honour the
// SAME policy + override contract instead of silently only ever doing
// full_annual, keeping the four Dart repository layers consistent with each
// other. The two implementations are intentionally IDENTICAL in algorithm
// (month-basis index, "round every share, last absorbs the remainder" split)
// so a demo session and a real API session never disagree on what a given
// admission date/policy would charge.

import '../../core/repositories/academic/academic_year_label.dart';
import 'finance_models.dart';

class FeeProrationYearBounds {
  const FeeProrationYearBounds({required this.startDate, required this.endDate});

  /// 'YYYY-MM-DD'.
  final String startDate;

  /// 'YYYY-MM-DD'.
  final String endDate;
}

class FeeProrationResult {
  const FeeProrationResult({
    required this.policy,
    required this.totalMonths,
    required this.monthsCharged,
    required this.referenceDate,
    required this.annualAmount,
    required this.chargedAmount,
    required this.isOverride,
    this.fallbackReason,
    this.overrideReason,
  });

  final FeeProrationPolicy policy;
  final int totalMonths;
  final int monthsCharged;
  final String referenceDate;
  final double annualAmount;
  final double chargedAmount;
  final bool isOverride;
  final String? fallbackReason;
  final String? overrideReason;
}

/// Thrown when a caller supplies [prorationPolicyOverride] with no
/// [prorationOverrideReason] — mirrors the server's
/// FeeProrationOverrideReasonRequiredError exactly (message included).
class FeeProrationOverrideReasonRequiredError extends Error {
  @override
  String toString() =>
      'A reason is required when overriding the mid-year admission fee proration policy';
}

double _round2(double n) => (n * 100).round() / 100;

({int year, int month}) _yearMonthOf(String isoDate) {
  final parts = isoDate.length >= 7 ? isoDate.substring(0, 7).split('-') : const [];
  final year = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
  final month = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
  return (year: year, month: month);
}

int _monthIndexWithin(String dateStr, String startStr) {
  final d = _yearMonthOf(dateStr);
  final s = _yearMonthOf(startStr);
  return (d.year - s.year) * 12 + (d.month - s.month) + 1;
}

int _totalMonthsBetween(FeeProrationYearBounds bounds) {
  final idx = _monthIndexWithin(bounds.endDate, bounds.startDate);
  return idx < 1 ? 1 : idx;
}

/// Splits [total] into [count] equal monthly shares whose SUM is EXACTLY
/// [total] (last share absorbs the rounding remainder) — same idiom as the
/// server's splitEvenly / buildInstallmentPlan.
List<double> _splitEvenly(double total, int count) {
  final per = _round2(total / count);
  final shares = <double>[];
  var allocated = 0.0;
  for (var i = 0; i < count; i++) {
    final isLast = i == count - 1;
    final amount = isLast ? _round2(total - allocated) : per;
    allocated = _round2(allocated + amount);
    shares.add(amount);
  }
  return shares;
}

/// Best-effort April-start academic-year bounds derived from a "YYYY-YY" (or
/// "YYYY-YYYY") label, e.g. "2026-27" → 2026-04-01..2027-03-31. Returns null
/// when the label doesn't parse — the caller then falls back to full_annual,
/// same fail-safe posture as the server when it can't resolve real bounds.
/// MOCK/DEMO-ONLY: the real backend always uses the school's actual
/// `academic_years` row; this is a convenience stand-in with no such catalog.
FeeProrationYearBounds? deriveAprilStartYearBounds(String academicYearLabel) {
  final normalized = normalizeAcademicYearLabel(academicYearLabel);
  final match = RegExp(r'^(\d{4})-(\d{2,4})$').firstMatch(normalized);
  if (match == null) return null;
  final startYear = int.tryParse(match.group(1)!);
  if (startYear == null) return null;
  return FeeProrationYearBounds(
    startDate: '$startYear-04-01',
    endDate: '${startYear + 1}-03-31',
  );
}

/// Computes the mid-year admission proration — see finance_fee_proration.ts
/// for the full month-basis / no-paise-drift rationale (identical here).
FeeProrationResult computeFeeProration({
  required FeeProrationPolicy policy,
  required double annualAmount,
  required String referenceDate,
  required FeeProrationYearBounds? yearBounds,
  bool isOverride = false,
  String? overrideReason,
}) {
  final annual = _round2(annualAmount);
  final resolvedOverrideReason = isOverride ? (overrideReason ?? '') : null;

  final wantsProration = policy == FeeProrationPolicy.prorateFromAdmissionMonth;
  final canProrate = wantsProration && yearBounds != null;
  final fallbackReason =
      wantsProration && !canProrate ? 'academic_year_bounds_unavailable' : null;

  if (!canProrate) {
    final totalMonths = yearBounds != null ? _totalMonthsBetween(yearBounds) : 1;
    return FeeProrationResult(
      policy: FeeProrationPolicy.fullAnnual,
      totalMonths: totalMonths,
      monthsCharged: totalMonths,
      referenceDate: referenceDate,
      annualAmount: annual,
      chargedAmount: annual,
      isOverride: isOverride,
      overrideReason: resolvedOverrideReason,
      fallbackReason: fallbackReason,
    );
  }

  final bounds = yearBounds;
  final totalMonths = _totalMonthsBetween(bounds);
  final rawIndex = _monthIndexWithin(referenceDate, bounds.startDate);
  final clampedIndex = rawIndex.clamp(1, totalMonths);
  final monthsCharged = totalMonths - clampedIndex + 1;

  final shares = _splitEvenly(annual, totalMonths);
  final skippedCount = totalMonths - monthsCharged;
  var chargedAmount = 0.0;
  for (final share in shares.skip(skippedCount)) {
    chargedAmount = _round2(chargedAmount + share);
  }

  return FeeProrationResult(
    policy: FeeProrationPolicy.prorateFromAdmissionMonth,
    totalMonths: totalMonths,
    monthsCharged: monthsCharged,
    referenceDate: referenceDate,
    annualAmount: annual,
    chargedAmount: chargedAmount,
    isOverride: isOverride,
    overrideReason: resolvedOverrideReason,
    fallbackReason: null,
  );
}
