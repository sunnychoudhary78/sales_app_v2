class LocationPoint {
  const LocationPoint({
    this.id,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.speed,
    this.heading,
    this.batteryPercent,
    required this.recordedAt,
    this.isSynced = 0,
  });

  final int? id;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final int? batteryPercent;
  final String recordedAt;
  final int isSynced;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'speed': speed,
      'heading': heading,
      'battery_percent': batteryPercent,
      'recordedAt': recordedAt,
      'isSynced': isSynced,
    };
  }

  factory LocationPoint.fromMap(Map<String, dynamic> map) {
    return LocationPoint(
      id: map['id'] as int?,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
      heading: (map['heading'] as num?)?.toDouble(),
      batteryPercent: (map['battery_percent'] as num?)?.toInt(),
      recordedAt: map['recordedAt']?.toString() ?? '',
      isSynced: (map['isSynced'] as num?)?.toInt() ?? 0,
    );
  }
}
