/// Null-safe, type-tolerant JSON readers.
///
/// The SCI API returns some numeric columns as JSON **strings**:
///
///     "plotSizeSqm": "300"        not  300
///
/// Prisma does this for `Decimal` fields — they serialise as strings to avoid
/// the precision loss of IEEE-754 doubles. So `valueNumber`, `marketValue`,
/// `latitude`, `accuracyM` and similar arrive quoted.
///
/// Every `as num?` cast against those throws:
///
///     type 'String' is not a subtype of type 'num?'
///
/// These helpers accept whichever form arrives. Use them for EVERY numeric,
/// boolean and date read in a `fromJson`, not just the ones known to break —
/// which columns are Decimal is a server-side detail that can change.
class J {
  const J._();

  /// Reads a double from a num, a numeric String, or null.
  static double? asDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  /// Reads an int from a num, a numeric String, or null.
  ///
  /// Truncates a decimal String ("4.0" -> 4) rather than returning null.
  static int? asInt(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    if (v is String) {
      final s = v.trim();
      return int.tryParse(s) ?? double.tryParse(s)?.toInt();
    }
    return null;
  }

  /// Reads a bool from a bool, "true"/"false", or 1/0.
  static bool? asBool(Object? v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'no') return false;
    }
    return null;
  }

  /// Reads a String from anything printable, without casting.
  static String? asString(Object? v) {
    if (v == null) return null;
    if (v is String) return v;
    if (v is num || v is bool) return v.toString();
    return null;
  }

  /// Reads a DateTime from an ISO string or epoch milliseconds.
  static DateTime? asDate(Object? v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v.trim());
    if (v is num) {
      return DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
    }
    return null;
  }

  /// Reads a list of strings from a JSON array of any element type.
  ///
  /// `raw is List<String>` is false for a `List<dynamic>`, which is what
  /// `jsonDecode` always produces — that check silently discarded
  /// multi-select values.
  static List<String>? asStringList(Object? v) {
    if (v is! List) return null;
    return v
        .map((dynamic e) => asString(e as Object?) ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Reads a nested object, or null if the key is absent or not a map.
  static Map<String, dynamic>? asMap(Object? v) =>
      v is Map<String, dynamic> ? v : null;
}
