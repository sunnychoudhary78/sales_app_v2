bool hasPermission(
  Map<String, dynamic>? user,
  String permission,
) {
  if (user == null) return false;
  final permissions = user['permissions'];
  if (permissions is! List) return false;
  final target = permission.toLowerCase();
  for (final p in permissions) {
    if (p is String && p.toLowerCase() == target) return true;
    if (p is Map && (p['name']?.toString().toLowerCase() == target)) return true;
  }
  return false;
}

bool hasAnyPermission(
  Map<String, dynamic>? user,
  List<String> permissions,
) {
  for (final p in permissions) {
    if (hasPermission(user, p)) return true;
  }
  return false;
}

