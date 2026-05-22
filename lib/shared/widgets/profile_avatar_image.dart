import 'package:flutter/material.dart';

class ProfileAvatarImage extends StatefulWidget {
  const ProfileAvatarImage({
    super.key,
    required this.urls,
    required this.fallback,
    this.size,
    this.version = '',
    this.fit = BoxFit.cover,
  });

  final List<String> urls;
  final Widget fallback;
  final double? size;
  final String version;
  final BoxFit fit;

  @override
  State<ProfileAvatarImage> createState() => _ProfileAvatarImageState();
}

class _ProfileAvatarImageState extends State<ProfileAvatarImage> {
  int _urlIndex = 0;

  @override
  void didUpdateWidget(covariant ProfileAvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.version != widget.version ||
        oldWidget.urls.join('|') != widget.urls.join('|')) {
      _urlIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls.where((url) => url.trim().isNotEmpty).toList();
    final index = urls.isEmpty
        ? 0
        : _urlIndex.clamp(0, urls.length - 1).toInt();
    final child = urls.isEmpty
        ? widget.fallback
        : Image.network(
            urls[index],
            key: ValueKey<String>(
              '${urls[index]}|${widget.version}',
            ),
            fit: widget.fit,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) {
              if (_urlIndex < urls.length - 1) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _urlIndex++);
                });
              }
              return widget.fallback;
            },
          );

    if (widget.size == null) return SizedBox.expand(child: child);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: child,
    );
  }
}
