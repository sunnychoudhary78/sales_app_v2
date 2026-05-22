import '../../core/network/api_constants.dart';

/// Builds a displayable profile image URL from [user] (same rules as Profile screen).
String? resolveAvatarUrl(Map<String, dynamic>? user) {
  final urls = resolveAvatarUrlCandidates(user);
  return urls.isEmpty ? null : urls.first;
}

/// Returns all likely display URLs for a profile image.
///
/// The backend can store profile pictures as:
/// - a full URL (`http://.../api/uploads/userProfile/file.jpg`)
/// - a filename (`file.jpg`)
/// - a mounted path (`/api/uploads/...` or `/uploads/...`)
/// - nested `UserDetail.profile_picture`
List<String> resolveAvatarUrlCandidates(Map<String, dynamic>? user) {
  if (user == null) return const [];
  final raw = _firstAvatarValue(user);
  if (raw == null || raw.isEmpty) return const [];

  final normalizedRaw = raw.replaceAll('\\', '/').trim();
  final urls = <String>[];
  void add(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return;
    if (!urls.contains(v)) urls.add(v);
  }

  try {
    final base = Uri.parse(ApiConstants.baseUrl);
    final origin =
        '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';
    final apiMount = base.path.endsWith('/api')
        ? base.path.substring(0, base.path.length - 4)
        : base.path;

    void addMountedUploadPath(String path) {
      final cleanPath = path.startsWith('/') ? path : '/$path';
      add('$origin$cleanPath');
      if (cleanPath.startsWith('/api/uploads/')) {
        add('$origin$apiMount$cleanPath');
      } else if (cleanPath.startsWith('/uploads/')) {
        add('$origin$apiMount/api$cleanPath');
        add('$origin/api$cleanPath');
      }
    }

    if (normalizedRaw.startsWith('http://') ||
        normalizedRaw.startsWith('https://')) {
      add(normalizedRaw);
      final uri = Uri.tryParse(normalizedRaw);
      final path = uri?.path;
      if (path != null && path.contains('/uploads/')) {
        addMountedUploadPath(path);
      }
      return urls;
    }

    if (normalizedRaw.startsWith('/')) {
      addMountedUploadPath(normalizedRaw);
      return urls;
    }

    add('$origin$apiMount/api/uploads/userProfile/$normalizedRaw');
    add('$origin/api/uploads/userProfile/$normalizedRaw');
    return urls;
  } catch (_) {
    add(normalizedRaw);
    return urls;
  }
}

String? _firstAvatarValue(Map<String, dynamic> user) {
  const keys = [
    'profile_picture',
    'profilePicture',
    'image_url',
    'imageUrl',
    'photo_url',
    'photoUrl',
    'avatar',
  ];

  for (final key in keys) {
    final value = user[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }

  for (final nestedKey in const ['UserDetail', 'userDetail', 'user_detail']) {
    final nested = user[nestedKey];
    if (nested is Map) {
      final value = _firstAvatarValue(Map<String, dynamic>.from(nested));
      if (value != null && value.isNotEmpty) return value;
    }
  }

  return null;
}
