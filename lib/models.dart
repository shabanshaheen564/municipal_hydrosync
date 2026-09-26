class SessionUser {
  final int id;
  final String name;
  final String email;
  final List<String> roles;
  final List<String> permissions;

  SessionUser({
    required this.id,
    required this.name,
    required this.email,
    this.roles = const [],
    this.permissions = const [],
  });

  factory SessionUser.fromJson(Map<String, dynamic> j) {
    final rawRoles = j['roles'] as List? ?? const [];
    final roles = rawRoles
        .map((e) => e is Map ? '${e['name'] ?? ''}' : '${e}')
        .where((e) => e.trim().isNotEmpty)
        .toList();

    final rawPermissions = j['permissions'] as List? ?? const [];
    final permissions = rawPermissions
        .map((e) => e is Map ? '${e['name'] ?? ''}' : '${e}')
        .where((e) => e.trim().isNotEmpty)
        .toList();

    return SessionUser(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: '${j['name'] ?? ''}',
      email: '${j['email'] ?? ''}',
      roles: roles,
      permissions: permissions,
    );
  }
}

class ApiList {
  final List<Map<String, dynamic>> items;
  final int total;
  ApiList(this.items, this.total);
}
