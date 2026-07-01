/// Indian-system amount-to-words for receipts / financial documents (FIN-3).
///
/// Converts an integer rupee amount into words using the Indian numbering
/// system (thousand → lakh → crore), e.g. 125000 → "Rupees One Lakh Twenty
/// Five Thousand Only". English-only by product decision (see English-first).
library;

const List<String> _ones = [
  'Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight',
  'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen',
  'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen',
];

const List<String> _tens = [
  '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty',
  'Ninety',
];

/// Words for a number 0–99.
String _twoDigits(int n) {
  if (n < 20) return _ones[n];
  final tens = _tens[n ~/ 10];
  final ones = n % 10;
  return ones == 0 ? tens : '$tens ${_ones[ones]}';
}

/// Words for a number 0–999.
String _threeDigits(int n) {
  final hundreds = n ~/ 100;
  final rest = n % 100;
  final parts = <String>[];
  if (hundreds > 0) parts.add('${_ones[hundreds]} Hundred');
  if (rest > 0) parts.add(_twoDigits(rest));
  return parts.join(' ');
}

/// Converts [amount] rupees to Indian-system words, wrapped as a full receipt
/// phrase: `Rupees <words> Only`. Negative amounts are prefixed "Minus".
String rupeesInWords(int amount) {
  if (amount == 0) return 'Rupees Zero Only';
  final negative = amount < 0;
  var n = amount.abs();

  // Indian grouping: crore, lakh, thousand, then the trailing 0-999.
  final crore = n ~/ 10000000;
  n %= 10000000;
  final lakh = n ~/ 100000;
  n %= 100000;
  final thousand = n ~/ 1000;
  n %= 1000;
  final rest = n;

  final parts = <String>[];
  if (crore > 0) parts.add('${numberInWords(crore)} Crore');
  if (lakh > 0) parts.add('${_twoDigits(lakh)} Lakh');
  if (thousand > 0) parts.add('${_twoDigits(thousand)} Thousand');
  if (rest > 0) parts.add(_threeDigits(rest));

  final words = parts.join(' ');
  return '${negative ? 'Minus ' : ''}Rupees $words Only';
}

/// Bare number-in-words (no "Rupees…Only" wrapper) for the crore group and any
/// other caller that just needs the digits spelled out. Handles arbitrarily
/// large crore counts recursively.
String numberInWords(int n) {
  if (n < 0) return 'Minus ${numberInWords(-n)}';
  if (n < 1000) return _threeDigits(n) == '' ? _ones[n] : _threeDigits(n);
  final crore = n ~/ 10000000;
  var rem = n % 10000000;
  final lakh = rem ~/ 100000;
  rem %= 100000;
  final thousand = rem ~/ 1000;
  rem %= 1000;
  final parts = <String>[];
  if (crore > 0) parts.add('${numberInWords(crore)} Crore');
  if (lakh > 0) parts.add('${_twoDigits(lakh)} Lakh');
  if (thousand > 0) parts.add('${_twoDigits(thousand)} Thousand');
  if (rem > 0) parts.add(_threeDigits(rem));
  return parts.join(' ');
}
