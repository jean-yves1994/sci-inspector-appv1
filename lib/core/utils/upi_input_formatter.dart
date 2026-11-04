import 'package:flutter/services.dart';

class UpiInputFormatter extends TextInputFormatter {
  static const List<int> _segmentLengths = [1, 2, 2, 2, 9];

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    // Keep all digits from 0 to 9.
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Rwanda UPI contains 16 digits in total.
    final limitedDigits =
    digits.length > 16 ? digits.substring(0, 16) : digits;

    final result = StringBuffer();
    var offset = 0;

    for (final segmentLength in _segmentLengths) {
      if (offset >= limitedDigits.length) break;

      if (result.isNotEmpty) {
        result.write('/');
      }

      final end = (offset + segmentLength)
          .clamp(0, limitedDigits.length);

      result.write(limitedDigits.substring(offset, end));
      offset = end;
    }

    final formatted = result.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: formatted.length,
      ),
      composing: TextRange.empty,
    );
  }
}