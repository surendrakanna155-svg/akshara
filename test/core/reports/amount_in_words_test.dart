import 'package:akshara_erp/core/reports/amount_in_words.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rupeesInWords (Indian numbering, FIN-3)', () {
    test('zero', () {
      expect(rupeesInWords(0), 'Rupees Zero Only');
    });

    test('sub-hundred and teens', () {
      expect(rupeesInWords(5), 'Rupees Five Only');
      expect(rupeesInWords(15), 'Rupees Fifteen Only');
      expect(rupeesInWords(40), 'Rupees Forty Only');
      expect(rupeesInWords(99), 'Rupees Ninety Nine Only');
    });

    test('hundreds', () {
      expect(rupeesInWords(100), 'Rupees One Hundred Only');
      expect(rupeesInWords(305), 'Rupees Three Hundred Five Only');
    });

    test('thousands', () {
      expect(rupeesInWords(5000), 'Rupees Five Thousand Only');
      expect(rupeesInWords(12500), 'Rupees Twelve Thousand Five Hundred Only');
    });

    test('lakhs (Indian grouping)', () {
      expect(rupeesInWords(100000), 'Rupees One Lakh Only');
      expect(
        rupeesInWords(125000),
        'Rupees One Lakh Twenty Five Thousand Only',
      );
    });

    test('crores', () {
      expect(rupeesInWords(10000000), 'Rupees One Crore Only');
      expect(
        rupeesInWords(12345678),
        'Rupees One Crore Twenty Three Lakh Forty Five Thousand Six Hundred Seventy Eight Only',
      );
    });

    test('negative amount is prefixed Minus', () {
      expect(rupeesInWords(-500), 'Minus Rupees Five Hundred Only');
    });
  });
}
