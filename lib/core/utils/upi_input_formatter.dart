import 'package:flutter/services.dart';

/// Formats Rwanda UPI values as 1/02/04/01/<variable final segment>.
///
/// The first four groups have fixed lengths (1, 2, 2, 2). The final group is
/// variable-length; there is no fixed total digit count.
class UpiInputFormatter extends TextInputFormatter {
  static const List<int> _prefixSegmentLengths = <int>[1, 2, 2, 2];

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final input = newValue.text;
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    final selectionOffset =
        newValue.selection.extentOffset.clamp(0, input.length);
    final digitsBeforeCursor = input
        .substring(0, selectionOffset)
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;

    final formatted = StringBuffer();
    var digitOffset = 0;
    for (final segmentLength in _prefixSegmentLengths) {
      if (digitOffset >= digits.length) break;
      if (formatted.isNotEmpty) formatted.write('/');
      final end = (digitOffset + segmentLength).clamp(0, digits.length);
      formatted.write(digits.substring(digitOffset, end));
      digitOffset = end;
    }

    // All digits after the first seven belong to the variable final segment.
    if (digitOffset < digits.length) {
      if (formatted.isNotEmpty) formatted.write('/');
      formatted.write(digits.substring(digitOffset));
    }

    final text = formatted.toString();
    var cursor = 0;
    var seenDigits = 0;
    while (cursor < text.length && seenDigits < digitsBeforeCursor) {
      if (RegExp(r'[0-9]').hasMatch(text[cursor])) seenDigits++;
      cursor++;
    }
    if (seenDigits == digitsBeforeCursor &&
        cursor < text.length &&
        text[cursor] == '/' &&
        digitsBeforeCursor > 0) {
      cursor++;
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor.clamp(0, text.length)),
      composing: TextRange.empty,
    );
  }
}
