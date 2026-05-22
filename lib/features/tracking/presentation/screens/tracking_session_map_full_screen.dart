import 'package:flutter/material.dart';

import '../widgets/session_route_map_preview.dart';

/// Full-screen route map (legacy app had a dedicated map page with zoom).
class TrackingSessionMapFullScreen extends StatelessWidget {
  const TrackingSessionMapFullScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session route'),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SessionRouteMapPreview(
              sessionId: sessionId,
              height: constraints.maxHeight,
              interactive: true,
            );
          },
        ),
      ),
    );
  }
}
