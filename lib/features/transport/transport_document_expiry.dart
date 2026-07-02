import 'transport_models.dart';

/// TRN-2/TRN-8 — client-side helpers for the document-expiry tracker.
///
/// Dates are ISO YYYY-MM-DD strings end-to-end (never migrated to DateTime).
/// Legacy free-text values (e.g. "Dec 2026") are simply skipped — only real ISO
/// dates are surfaced as tracked, sortable, colour-coded documents, matching the
/// backend's TRN-8 scan exactly.
abstract final class TransportDocumentExpiryScanner {
  static final RegExp _isoDateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Parses a strict ISO calendar date (YYYY-MM-DD). Returns null for malformed
  /// or non-ISO (legacy free-text) values, or impossible calendar dates.
  static DateTime? parseIso(String value) {
    if (!_isoDateRe.hasMatch(value)) return null;
    final parts = value.split('-');
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final dt = DateTime.utc(y, m, d);
    if (dt.year != y || dt.month != m || dt.day != d) return null;
    return dt;
  }

  /// Whole days from [from] (date only) to the ISO date [iso]; null if not ISO.
  static int? daysUntil(String iso, DateTime from) {
    final target = parseIso(iso);
    if (target == null) return null;
    final base = DateTime.utc(from.year, from.month, from.day);
    return target.difference(base).inDays;
  }

  /// Builds the tracked-document list from vehicles + drivers, keeping only rows
  /// with a real ISO expiry, sorted soonest-first (expired first).
  static List<TransportDocumentExpiry> scan({
    required List<TransportVehicle> vehicles,
    required List<TransportDriver> drivers,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final result = <TransportDocumentExpiry>[];

    void add(String subject, String document, String iso) {
      final days = daysUntil(iso, today);
      if (days == null) return;
      result.add(
        TransportDocumentExpiry(
          subject: subject,
          document: document,
          expiresOn: iso,
          daysUntil: days,
        ),
      );
    }

    for (final v in vehicles) {
      final label = v.busNumber.isNotEmpty ? v.busNumber : v.registration;
      add('Bus $label', 'Insurance', v.insuranceExpiry);
      add('Bus $label', 'Fitness', v.fitnessExpiry);
      add('Bus $label', 'PUC', v.pucExpiry);
      add('Bus $label', 'Permit', v.permitExpiry);
      add('Bus $label', 'Road tax', v.roadTaxExpiry);
    }
    for (final d in drivers) {
      add('Driver ${d.name}', 'Licence', d.licenseExpiry);
    }

    result.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
    return result;
  }
}
