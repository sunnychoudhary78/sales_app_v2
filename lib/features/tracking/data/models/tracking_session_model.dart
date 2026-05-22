class TrackingSessionModel {
  final String id;
  final String status;
  final String? checkInAt;
  final String? checkOutAt;
  final double totalDistanceKm;
  /// From history `user` (legacy app shows this for multi-user / manager views).
  final String? userDisplayName;

  const TrackingSessionModel({
    required this.id,
    required this.status,
    required this.checkInAt,
    required this.checkOutAt,
    required this.totalDistanceKm,
    this.userDisplayName,
  });

  bool get isActive {
    final s = status.toLowerCase();
    return s == 'open' || s == 'active' || s == 'running';
  }

  factory TrackingSessionModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    String? userName;
    if (user is Map) {
      final detail = user['UserDetail'];
      if (detail is Map && detail['name'] != null) {
        userName = detail['name'].toString();
      } else {
        userName = user['email']?.toString() ?? user['name']?.toString();
      }
    }
    return TrackingSessionModel(
      id: (json['id'] ?? json['session_id'] ?? '').toString(),
      status: (json['status'] ?? json['state'] ?? '').toString(),
      checkInAt: json['check_in_at']?.toString(),
      checkOutAt: json['check_out_at']?.toString(),
      totalDistanceKm:
          double.tryParse((json['total_distance_km'] ?? '0').toString()) ?? 0,
      userDisplayName: userName,
    );
  }
}

