import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sales_tracking_v2/shared/widgets/premium_shell.dart';

import '../../../../core/auth/company_context.dart';
import '../../../../core/providers/global_loading_provider.dart';
import '../../../../shared/utils/avatar_url_utils.dart';
import '../../../../shared/widgets/app_side_drawer.dart';
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update Profile Photo',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose a source to upload your high-resolution avatar.',
                style: GoogleFonts.inter(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              _ImageOptionTile(
                icon: Icons.camera_enhance_rounded,
                title: 'Take Photo',
                subtitle: 'Use camera to snap a new picture',
                scheme: scheme,
                onTap: _uploading
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _pickAndUpload(ImageSource.camera);
                      },
              ),
              const SizedBox(height: 10),
              _ImageOptionTile(
                icon: Icons.photo_library_rounded,
                title: 'Choose from Gallery',
                subtitle: 'Select an existing image from photos',
                scheme: scheme,
                onTap: _uploading
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _pickAndUpload(ImageSource.gallery);
                      },
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
    final companyCtx = CompanyContext.fromUser(user);

    final name = (user['name'] ?? auth.profile?.name ?? 'User').toString();
    final email = (user['email'] ?? auth.profile?.email ?? '').toString();
    final mobile = (user['mobile'] ?? '').toString();
    final role = (user['role'] is Map ? user['role']['name'] : user['role_name'])
            ?.toString() ??
        '';
    final company = companyCtx.displayCompanyName.isNotEmpty
        ? companyCtx.displayCompanyName
        : (user['company_name'] ?? '').toString();
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            // Modern Profile Banner Card
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: HomeDashboardChrome.panelDecoration(scheme).copyWith(
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Decorative Gradient Header Accent
                  Container(
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primary.withValues(alpha: 0.85),
                          scheme.tertiary.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -42),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          // Avatar Stack with Quick Edit Action
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 104,
                                height: 104,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: scheme.surface,
                                  boxShadow: [
                                    BoxShadow(
                                      color: scheme.shadow.withValues(alpha: 0.12),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(4),
                                child: ClipOval(
                                  child: _uploading
                                      ? ColoredBox(
                                          color: scheme.surfaceContainerHighest,
                                          child: Center(
                                            child: SizedBox(
                                              width: 30,
                                              height: 30,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.8,
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
                                                    fontSize: 34,
                                                    fontWeight: FontWeight.w800,
                                                    color: scheme.primary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Material(
                                  color: scheme.primary,
                                  shape: const CircleBorder(),
                                  elevation: 4,
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: _uploading ? null : _showPhotoSheet,
                                    child: Padding(
                                      padding: const EdgeInsets.all(9),
                                      child: Icon(
                                        Icons.camera_alt_rounded,
                                        size: 18,
                                        color: scheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Primary Identity Info
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          const SizedBox(height: 12),
                          // Role Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: scheme.primary.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_user_rounded,
                                  size: 14,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  role.isEmpty ? 'Role Unassigned' : role,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Account Details Modern Card
            Container(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
              decoration: HomeDashboardChrome.panelDecoration(scheme),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HomeDashboardChrome.sectionHeader(
                    context,
                    eyebrow: 'Account Information',
                    title: 'Personal Details',
                    subtitle: 'Manage your verified user information.',
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 8),
                  _DetailCardTile(
                    scheme: scheme,
                    icon: Icons.alternate_email_rounded,
                    label: 'Email Address',
                    value: email.isEmpty ? 'Not Provided' : email,
                    onCopy: email.isNotEmpty
                        ? () => _copyToClipboard(context, email, 'Email copied')
                        : null,
                  ),
                  const SizedBox(height: 10),
                  _DetailCardTile(
                    scheme: scheme,
                    icon: Icons.smartphone_rounded,
                    label: 'Mobile Number',
                    value: mobile.isEmpty ? 'Not Provided' : mobile,
                    onCopy: mobile.isNotEmpty
                        ? () => _copyToClipboard(context, mobile, 'Mobile copied')
                        : null,
                  ),
                  const SizedBox(height: 10),
                  _DetailCardTile(
                    scheme: scheme,
                    icon: Icons.business_center_rounded,
                    label: 'Company',
                    value: company.isEmpty ? 'Not Assigned' : company,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _DetailCardTile extends StatelessWidget {
  const _DetailCardTile({
    required this.scheme,
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
  });

  final ColorScheme scheme;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: scheme.primary, size: 20),
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
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18),
              color: scheme.onSurfaceVariant,
              tooltip: 'Copy',
              onPressed: onCopy,
            ),
        ],
      ),
    );
  }
}

class _ImageOptionTile extends StatelessWidget {
  const _ImageOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.scheme,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme scheme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: scheme.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}