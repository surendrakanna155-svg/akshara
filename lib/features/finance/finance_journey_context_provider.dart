import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Last invoice created during fee assignment (mock journey traceability).
final financeLastInvoiceIdProvider = StateProvider<String?>((ref) => null);

/// Last receipt number from a collection mutation (Patrol assertions).
final financeLastReceiptNumberProvider = StateProvider<String?>((ref) => null);
