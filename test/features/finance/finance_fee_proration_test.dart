// Cap 73 (owner decision #5) — mid-year admission fee proration.
// Dart-side mirror of the backend's exhaustive proration test suite
// (supabase/functions/_shared/finance/finance_fee_proration_test.ts); proves
// the mock-mode calculation (used by MockFinanceRepository) agrees with the
// same month-basis / no-paise-drift rules as the real API engine.

import 'package:akshara_erp/features/finance/finance_fee_proration.dart';
import 'package:akshara_erp/features/finance/finance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ay = FeeProrationYearBounds(startDate: '2026-04-01', endDate: '2027-03-31');
  const annual = 50000.0;

  test('full_annual charges the ENTIRE annual amount regardless of admission date', () {
    for (final referenceDate in ['2026-04-01', '2026-09-15', '2027-03-31', '2025-01-01']) {
      final result = computeFeeProration(
        policy: FeeProrationPolicy.fullAnnual,
        annualAmount: annual,
        referenceDate: referenceDate,
        yearBounds: ay,
      );
      expect(result.policy, FeeProrationPolicy.fullAnnual);
      expect(result.chargedAmount, annual);
      expect(result.fallbackReason, isNull);
    }
  });

  test('prorate_from_admission_month at the FIRST month of the academic year == full annual', () {
    final result = computeFeeProration(
      policy: FeeProrationPolicy.prorateFromAdmissionMonth,
      annualAmount: annual,
      referenceDate: '2026-04-01',
      yearBounds: ay,
    );
    expect(result.totalMonths, 12);
    expect(result.monthsCharged, 12);
    expect(result.chargedAmount, annual);
  });

  test('prorate_from_admission_month at the LAST month of the academic year == one month', () {
    final result = computeFeeProration(
      policy: FeeProrationPolicy.prorateFromAdmissionMonth,
      annualAmount: annual,
      referenceDate: '2027-03-15',
      yearBounds: ay,
    );
    expect(result.totalMonths, 12);
    expect(result.monthsCharged, 1);
    expect(result.chargedAmount, greaterThan(0));
    expect(result.chargedAmount, lessThan(annual / 11));
  });

  test('month boundary: 1st and last day of the SAME calendar month charge IDENTICALLY', () {
    final first = computeFeeProration(
      policy: FeeProrationPolicy.prorateFromAdmissionMonth,
      annualAmount: annual,
      referenceDate: '2026-09-01',
      yearBounds: ay,
    );
    final last = computeFeeProration(
      policy: FeeProrationPolicy.prorateFromAdmissionMonth,
      annualAmount: annual,
      referenceDate: '2026-09-30',
      yearBounds: ay,
    );
    expect(first.monthsCharged, last.monthsCharged);
    expect(first.chargedAmount, last.chargedAmount);
  });

  test('academic-year boundary: admission BEFORE the year starts still charges the full year', () {
    final result = computeFeeProration(
      policy: FeeProrationPolicy.prorateFromAdmissionMonth,
      annualAmount: annual,
      referenceDate: '2026-01-01',
      yearBounds: ay,
    );
    expect(result.monthsCharged, 12);
    expect(result.chargedAmount, annual);
  });

  test('academic-year boundary: admission AFTER the year ends still charges a minimum of one month', () {
    final result = computeFeeProration(
      policy: FeeProrationPolicy.prorateFromAdmissionMonth,
      annualAmount: annual,
      referenceDate: '2027-06-01',
      yearBounds: ay,
    );
    expect(result.monthsCharged, 1);
    expect(result.chargedAmount, greaterThan(0));
  });

  test('Feb (28/29) and 30- vs 31-day months charge IDENTICALLY under the month basis', () {
    const leapYearAy =
        FeeProrationYearBounds(startDate: '2027-04-01', endDate: '2028-03-31');
    final feb28 = computeFeeProration(
      policy: FeeProrationPolicy.prorateFromAdmissionMonth,
      annualAmount: annual,
      referenceDate: '2028-02-01',
      yearBounds: leapYearAy,
    );
    final feb29 = computeFeeProration(
      policy: FeeProrationPolicy.prorateFromAdmissionMonth,
      annualAmount: annual,
      referenceDate: '2028-02-29',
      yearBounds: leapYearAy,
    );
    expect(feb28.monthsCharged, feb29.monthsCharged);
    expect(feb28.chargedAmount, feb29.chargedAmount);
  });

  test('no paise drift: charged + skipped-complement reconcile EXACTLY to the annual total', () {
    final last = computeFeeProration(
      policy: FeeProrationPolicy.prorateFromAdmissionMonth,
      annualAmount: annual,
      referenceDate: '2027-03-15',
      yearBounds: ay,
    );
    final skipped = ((annual - last.chargedAmount) * 100).round() / 100;
    expect(((skipped + last.chargedAmount) * 100).round() / 100, annual);
    // Every result is already rounded to whole paise (no float remainder).
    expect((last.chargedAmount * 100).round() / 100, last.chargedAmount);
  });

  test('prorate_from_admission_month falls back to full_annual when year bounds are unavailable', () {
    final result = computeFeeProration(
      policy: FeeProrationPolicy.prorateFromAdmissionMonth,
      annualAmount: annual,
      referenceDate: '2026-09-15',
      yearBounds: null,
    );
    expect(result.policy, FeeProrationPolicy.fullAnnual);
    expect(result.chargedAmount, annual);
    expect(result.fallbackReason, 'academic_year_bounds_unavailable');
  });

  test('override fields are carried through exactly as given', () {
    final result = computeFeeProration(
      policy: FeeProrationPolicy.fullAnnual,
      annualAmount: annual,
      referenceDate: '2026-09-15',
      yearBounds: ay,
      isOverride: true,
      overrideReason: 'Owner-approved exception',
    );
    expect(result.isOverride, true);
    expect(result.overrideReason, 'Owner-approved exception');
  });

  test('FeeProrationOverrideReasonRequiredError message matches the server contract', () {
    expect(
      FeeProrationOverrideReasonRequiredError().toString(),
      contains('reason is required'),
    );
  });

  group('deriveAprilStartYearBounds', () {
    test('parses a "YYYY-YY" label into April-start bounds', () {
      final bounds = deriveAprilStartYearBounds('2026-27');
      expect(bounds, isNotNull);
      expect(bounds!.startDate, '2026-04-01');
      expect(bounds.endDate, '2027-03-31');
    });

    test('returns null for an unparseable label', () {
      expect(deriveAprilStartYearBounds('not-a-year'), isNull);
      expect(deriveAprilStartYearBounds(''), isNull);
    });
  });

  group('FeeProrationPolicy', () {
    test('apiValue round-trips through fromApiValue', () {
      for (final policy in FeeProrationPolicy.values) {
        expect(FeeProrationPolicy.fromApiValue(policy.apiValue), policy);
      }
    });

    test('fromApiValue falls back to fullAnnual on anything unrecognised', () {
      expect(FeeProrationPolicy.fromApiValue(null), FeeProrationPolicy.fullAnnual);
      expect(FeeProrationPolicy.fromApiValue(''), FeeProrationPolicy.fullAnnual);
      expect(FeeProrationPolicy.fromApiValue('bogus'), FeeProrationPolicy.fullAnnual);
    });
  });
}
