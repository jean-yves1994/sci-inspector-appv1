/// Backend permission constants for the INSPECTOR role (spec section 5).
class Permissions {
  const Permissions._();

  static const String branchesRead = 'branches.read';
  static const String propertiesRead = 'properties.read';
  static const String propertiesWrite = 'properties.write';
  static const String inspectionsRead = 'inspections.read';
  static const String inspectionsWrite = 'inspections.write';
  static const String inspectionsCreate = 'inspections.create';
  static const String reportsRead = 'reports.read';
  static const String templatesRead = 'templates.read';

  /// Reviewer/admin permissions an inspector must NEVER have. Listed so the
  /// UI can assert that reviewer affordances are never rendered.
  static const Set<String> reviewerOnly = <String>{
    'reviews.read',
    'reviews.decide',
    'inspections.assign',
    'reports.generate',
    'users.write',
    'roles.write',
    'templates.write',
  };
}

/// The authenticated inspector, exactly as returned by /auth/login and
/// /auth/me. Field names mirror the backend contract.
class User {
  const User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.organizationId,
    required this.roles,
    required this.permissions,
    this.branchId,
    this.branchScope,
    this.mustChangePassword = false,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String organizationId;
  final String? branchId;
  final String? branchScope;
  final bool mustChangePassword;
  final List<String> roles;
  final List<String> permissions;

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final result = '$f$l'.toUpperCase();
    return result.isEmpty ? '?' : result;
  }

  bool get isInspector => roles.contains('INSPECTOR');

  bool can(String permission) => permissions.contains(permission);

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String? ?? '',
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        organizationId: json['organizationId'] as String? ?? '',
        branchId: json['branchId'] as String?,
        branchScope: json['branchScope'] as String?,
        mustChangePassword: json['mustChangePassword'] as bool? ?? false,
        roles: (json['roles'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic e) => e.toString())
            .toList(),
        permissions: (json['permissions'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic e) => e.toString())
            .toList(),
      );
}
