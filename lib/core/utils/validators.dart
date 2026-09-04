/// Client-side validation is UX only. The backend remains authoritative.
class Validators {
  const Validators._();

  static final RegExp _email = RegExp(r'^[\w.\-+]+@([\w\-]+\.)+[A-Za-z]{2,}$');

  static String? email(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Email is required';
    if (!_email.hasMatch(s)) return 'Enter a valid email address';
    return null;
  }

  static String? Function(String?) required(String message) =>
      (v) => (v == null || v.trim().isEmpty) ? message : null;

  static String? password(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Password is required';
    if (s.length < 8) return 'Use at least 8 characters';
    return null;
  }

  static String? Function(String?) matches(
          String Function() other, String message) =>
      (v) => v == other() ? null : message;
}

/// Masks a national ID for display: only the last 4 digits remain visible.
String maskNationalId(String? id) {
  final s = id?.trim() ?? '';
  if (s.isEmpty) return '—';
  if (s.length <= 4) return '••••';
  return '${'•' * (s.length - 4)}${s.substring(s.length - 4)}';
}
