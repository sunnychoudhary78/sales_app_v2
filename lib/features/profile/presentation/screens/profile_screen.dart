import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/providers/global_loading_provider.dart';
import '../../../../shared/utils/avatar_url_utils.dart';
import '../../../../shared/widgets/app_side_drawer.dart';
import '../../../../shared/widgets/premium_shell.dart';
import '../../../../shared/widgets/profile_avatar_image.dart';
import '../../../../shared/widgets/screen_accent_backdrop.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../home/presentation/widgets/home_dashboard_chrome.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploading = false;
  File? _pickedPreview;

  static String _initials(String name) {
    final t = name.trim();
    if (t.isEmpty) return 'U';
    final parts = t.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final a = parts.first.isNotEmpty ? parts.first[0] : '';
      final b = parts.last.isNotEmpty ? parts.last[0] : '';
      return ('$a$b').toUpperCase();
    }
    return t.substring(0, 1).toUpperCase();
  }

  Future<File> _compressProfileJpeg(File input) async {
    final tmp = await getTemporaryDirectory();
    final outPath = p.join(
      tmp.path,
      'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    final result = await FlutterImageCompress.compressAndGetFile(
      input.absolute.path,
      outPath,
      minWidth: 1024,
      minHeight: 1024,
      quality: 80,
      format: CompressFormat.jpeg,
      autoCorrectionAngle: true,
      keepExif: false,
    );
    return result != null ? File(result.path) : input;
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: source,
      imageQuality: source == ImageSource.camera ? 85 : 90,
    );
    if (x == null || !mounted) return;

    setState(() {
      _pickedPreview = File(x.path);
      _uploading = true;
    });

    try {
      final optimized = await _compressProfileJpeg(File(x.path));
      await ref.read(authProvider.notifier).uploadProfilePhoto(optimized);
      if (!mounted) return;
      setState(() => _pickedPreview = null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _pickedPreview = null);
      ref.read(globalLoadingProvider.notifier).showApiError(e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _showPhotoSheet() async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Profile photo',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Same upload as classic Sales App (JPEG, server-stored).',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: _uploading
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _pickAndUpload(ImageSource.camera);
                      },
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('Take photo'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _uploading
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _pickAndUpload(ImageSource.gallery);
                      },
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose from gallery'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);
    final user = auth.rawUser ?? const <String, dynamic>{};

    final name = (user['name'] ?? auth.profile?.name ?? 'User').toString();
    final email = (user['email'] ?? auth.profile?.email ?? '').toString();
    final mobile = (user['mobile'] ?? '').toString();
    final role = (user['role'] is Map ? user['role']['name'] : user['role_name'])
            ?.toString() ??
        '';
    final company = (user['company_name'] ?? '').toString();
    final initials = _initials(name);
    final avatarUrl = resolveAvatarUrl(user);
    final avatarUrls = resolveAvatarUrlCandidates(user);

    return Scaffold(
      drawer: const AppSideDrawer(),
      appBar: const SalesGlassAppBar(
        title: 'Profile',
        showDrawer: true,
      ),
      body: ScreenAccentBackdrop(
        spot: DrawerRouteAccents.profile,
        spot2: DrawerRouteAccents.trackingCyan,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              decoration: HomeDashboardChrome.panelDecoration(scheme),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  scheme.primary,
                                  scheme.tertiary,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: scheme.primary.withValues(alpha: 0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(3),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: scheme.surface,
                              ),
                              child: ClipOval(
                                child: _uploading
                                    ? ColoredBox(
                                        color: scheme.surfaceContainerHighest,
                                        child: Center(
                                          child: SizedBox(
                                            width: 28,
                                            height: 28,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: scheme.primary,
                                            ),
                                          ),
                                        ),
                                      )
                                    : _pickedPreview != null
                                        ? Image.file(
                                            _pickedPreview!,
                                            fit: BoxFit.cover,
                                          )
                                        : ProfileAvatarImage(
                                            urls: avatarUrls,
                                            version: avatarUrl ?? '',
                                            fallback: Center(
                                                child: Text(
                                                  initials,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: -0.5,
                                                    color: scheme.primary,
                                                  ),
                                                ),
                                              ),
                                          ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Material(
                              color: scheme.primary,
                              shape: const CircleBorder(),
                              elevation: 3,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _uploading ? null : _showPhotoSheet,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.camera_alt_rounded,
                                    size: 20,
                                    color: scheme.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                height: 1.15,
                                color: scheme.onSurface,
                              ),
                            ),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                email,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: _uploading ? null : _showPhotoSheet,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: Text(
                                _uploading ? 'Uploading…' : 'Change photo',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer
                                    .withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      scheme.primary.withValues(alpha: 0.22),
                                ),
                              ),
                              child: Text(
                                role.isEmpty ? 'Role not assigned' : role,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.35,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              decoration: HomeDashboardChrome.panelDecoration(scheme),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HomeDashboardChrome.sectionHeader(
                    context,
                    eyebrow: 'Account',
                    title: 'Your details',
                    subtitle:
                        'Profile photo is saved to your account. Other fields may require admin update.',
                    icon: Icons.badge_outlined,
                  ),
                  _ProfileDetailRow(
                    scheme: scheme,
                    icon: Icons.alternate_email_rounded,
                    label: 'Email',
                    value: email.isEmpty ? '—' : email,
                  ),
                  Divider(
                    height: 1,
                    indent: 52,
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                  _ProfileDetailRow(
                    scheme: scheme,
                    icon: Icons.smartphone_rounded,
                    label: 'Mobile',
                    value: mobile.isEmpty ? '—' : mobile,
                  ),
                  Divider(
                    height: 1,
                    indent: 52,
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                  _ProfileDetailRow(
                    scheme: scheme,
                    icon: Icons.apartment_rounded,
                    label: 'Company',
                    value: company.isEmpty ? '—' : company,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({
    required this.scheme,
    required this.icon,
    required this.label,
    required this.value,
  });

  final ColorScheme scheme;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary.withValues(alpha: 0.16),
                  scheme.tertiary.withValues(alpha: 0.1),
                ],
              ),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(icon, color: scheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: scheme.primary.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 5),
                SelectableText(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    letterSpacing: -0.2,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
