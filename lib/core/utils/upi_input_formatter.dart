import 'package:flutter/services.dart';

/// Formats Rwanda UPI values as 1/02/09/04/1234 while the user types.
///
/// The slash is inserted as soon as each segment is complete. The final
/// segment contains four digits and does not receive a trailing slash.
class UpiInputFormatter extends TextInputFormatter {
  static const List<int> _segmentLengths = <int>[1, 2, 2, 2, 4];

  static const int maxDigits = 11;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limitedDigits = digits.length > maxDigits
        ? digits.substring(0, maxDigits)
        : digits;

    final formatted = StringBuffer();
    var digitOffset = 0;

    for (var i = 0; i < _segmentLengths.length; i++) {
      if (digitOffset >= limitedDigits.length) break;

      if (i > 0) formatted.write('/');

      final segmentLength = _segmentLengths[i];
      final remaining = limitedDigits.length - digitOffset;
      final take = remaining < segmentLength ? remaining : segmentLength;

      formatted.write(
        limitedDigits.substring(digitOffset, digitOffset + take),
      );
      digitOffset += take;

      // Show the separator immediately after a completed segment, including
      // while the next segment is still empty.
      if (take == segmentLength && i < _segmentLengths.length - 1) {
        formatted.write('/');
      }
    }

    final text = formatted.toString();

    int mapOffset(int originalOffset) {
      final safeOffset = originalOffset.clamp(0, newValue.text.length);
      final digitsBeforeCaret = newValue.text
          .substring(0, safeOffset)
          .replaceAll(RegExp(r'[^0-9]'), '')
          .length
          .clamp(0, limitedDigits.length);

      if (digitsBeforeCaret == 0) return 0;

      var seenDigits = 0;
      for (var i = 0; i < text.length; i++) {
        if (RegExp(r'[0-9]').hasMatch(text[i])) {
          seenDigits++;
          if (seenDigits == digitsBeforeCaret) {
            // Keep the caret after an automatically inserted separator.
            return i + 1 < text.length && text[i + 1] == '/'
                ? i + 2
                : i + 1;
          }
        }
      }
      return text.length;
    }

    final selection = newValue.selection;
    final baseOffset = mapOffset(selection.baseOffset);
    final extentOffset = mapOffset(selection.extentOffset);

    return TextEditingValue(
      text: text,
      selection: selection.isValid
          ? TextSelection(
              baseOffset: baseOffset,
              extentOffset: extentOffset,
              affinity: selection.affinity,
              isDirectional: selection.isDirectional,
            )
          : TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }
}
