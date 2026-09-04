/// Client-side validators exist purely for UX. The backend remains the
/// authority on every rule (spec section 4).
class Validators {
  const Validators._();

  static final RegExp _emailPattern =
      RegExp(r'^[\w.\-+]+@([\w\-]+\.)+[A-Za-z]{2,}$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!_emailPattern.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? Function(String?) required(String message) {
    return (value) =>
        (value == null || value.trim().isEmpty) ? message : null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Use at least 8 characters';
    return null;
  }

  static String? Function(String?) matches(
    String Function() other,
    String message,
  ) {
    return (value) => value == other() ? null : message;
  }
}
