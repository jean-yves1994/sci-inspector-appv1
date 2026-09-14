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

  /// Reviewer/admin permissions an inspector must NEVER hold.
  static const Set<String> reviewerOnly = <String>{
    'reviews.read', 'reviews.decide', 'inspections.assign',
    'reports.generate', 'users.write', 'roles.write', 'templates.write',
  };
}

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
    final r = '$f$l'.toUpperCase();
    return r.isEmpty ? '?' : r;
  }

  bool get isInspector => roles.contains('INSPECTOR');
  bool can(String permission) => permissions.contains(permission);

  /// Returns a copy of this user with only the supplied fields changed.
  ///
  /// This is important for the first-login password flow: changing the
  /// password succeeds on the server and clears `mustChangePassword`, but the
  /// change-password endpoint does not need to return a complete user object.
  /// The existing authenticated user can therefore be updated locally without
  /// forcing another `/auth/me` request or another login.
  User copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? organizationId,
    String? branchId,
    String? branchScope,
    bool? mustChangePassword,
    List<String>? roles,
    List<String>? permissions,
  }) =>
      User(
        id: id ?? this.id,
        email: email ?? this.email,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        organizationId: organizationId ?? this.organizationId,
        branchId: branchId ?? this.branchId,
        branchScope: branchScope ?? this.branchScope,
        mustChangePassword: mustChangePassword ?? this.mustChangePassword,
        roles: roles ?? this.roles,
        permissions: permissions ?? this.permissions,
      );

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as String,
        email: j['email'] as String? ?? '',
        firstName: j['firstName'] as String? ?? '',
        lastName: j['lastName'] as String? ?? '',
        organizationId: j['organizationId'] as String? ?? '',
        branchId: j['branchId'] as String?,
        branchScope: j['branchScope'] as String?,
        mustChangePassword: j['mustChangePassword'] as bool? ?? false,
        roles: (j['roles'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic e) => e.toString())
            .toList(),
        permissions: (j['permissions'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic e) => e.toString())
            .toList(),
      );
}
