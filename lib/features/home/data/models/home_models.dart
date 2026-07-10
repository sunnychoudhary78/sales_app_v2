// API payloads for [GET /tracking/my-home/performance] and [GET /tracking/my-home/timeline].

class HomePerformanceData {
  final String rangeFromIso;
  final String rangeToIso;
  final int maxRangeDays;
  final PerformanceTotals totals;
  final List<DailyChartPoint> byDay;
  final TrackingLiveSummary live;

  const HomePerformanceData({
    required this.rangeFromIso,
    required this.rangeToIso,
    required this.maxRangeDays,
    required this.totals,
    required this.byDay,
    required this.live,
  });

  factory HomePerformanceData.empty() {
    return HomePerformanceData(
      rangeFromIso: '',
      rangeToIso: '',
      maxRangeDays: 90,
      totals: PerformanceTotals.empty(),
      byDay: const [],
      live: TrackingLiveSummary.empty(),
    );
  }

  factory HomePerformanceData.fromJson(Map<String, dynamic> json) {
    final range = json['range'];
    final r = range is Map ? Map<String, dynamic>.from(range) : <String, dynamic>{};
    final totalsRaw = json['totals'];
    final chart = json['chart'];
    final chartMap = chart is Map ? Map<String, dynamic>.from(chart) : <String, dynamic>{};
    final byDayRaw = chartMap['by_day'];
    final list = byDayRaw is List
        ? byDayRaw
            .map((e) => DailyChartPoint.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <DailyChartPoint>[];
    final trackingRaw = json['tracking'];
    return HomePerformanceData(
      rangeFromIso: r['from']?.toString() ?? '',
      rangeToIso: r['to']?.toString() ?? '',
      maxRangeDays: int.tryParse(r['max_days']?.toString() ?? '') ?? 90,
      totals: totalsRaw is Map
          ? PerformanceTotals.fromJson(Map<String, dynamic>.from(totalsRaw))
          : PerformanceTotals.empty(),
      byDay: list,
      live: trackingRaw is Map
          ? TrackingLiveSummary.fromJson(Map<String, dynamic>.from(trackingRaw))
          : TrackingLiveSummary.empty(),
    );
  }
}

class PerformanceTotals {
  final double distanceKm;
  final double productiveHours;
  final int sessions;
  final int sessionsClosed;
  final int visits;
  final int newVisits;
  final int followupVisits;
  final double avgVisitsPerActiveDay;

  const PerformanceTotals({
    required this.distanceKm,
    required this.productiveHours,
    required this.sessions,
    required this.sessionsClosed,
    required this.visits,
    required this.newVisits,
    required this.followupVisits,
    required this.avgVisitsPerActiveDay,
  });

  factory PerformanceTotals.empty() {
    return const PerformanceTotals(
      distanceKm: 0,
      productiveHours: 0,
      sessions: 0,
      sessionsClosed: 0,
      visits: 0,
      newVisits: 0,
      followupVisits: 0,
      avgVisitsPerActiveDay: 0,
    );
  }

  factory PerformanceTotals.fromJson(Map<String, dynamic> json) {
    double numOr(dynamic v) => v == null ? 0.0 : (num.tryParse(v.toString())?.toDouble() ?? 0);
    int intOr(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

    return PerformanceTotals(
      distanceKm: numOr(json['distance_km']),
      productiveHours: numOr(json['productive_hours']),
      sessions: intOr(json['sessions']),
      sessionsClosed: intOr(json['sessions_closed']),
      visits: intOr(json['visits']),
      newVisits: intOr(json['new_visits']),
      followupVisits: intOr(json['followup_visits']),
      avgVisitsPerActiveDay: numOr(json['avg_visits_per_active_day']),
    );
  }
}

class DailyChartPoint {
  final String date;
  final double distanceKm;
  final double productiveHours;
  final int visits;
  final int newVisits;
  final int followupVisits;

  const DailyChartPoint({
    required this.date,
    required this.distanceKm,
    required this.productiveHours,
    required this.visits,
    required this.newVisits,
    required this.followupVisits,
  });

  factory DailyChartPoint.fromJson(Map<String, dynamic> json) {
    double numOr(dynamic v) => v == null ? 0.0 : (num.tryParse(v.toString())?.toDouble() ?? 0);
    int intOr(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

    return DailyChartPoint(
      date: json['date']?.toString() ?? '',
      distanceKm: numOr(json['distance_km']),
      productiveHours: numOr(json['productive_hours']),
      visits: intOr(json['visits']),
      newVisits: intOr(json['new_visits']),
      followupVisits: intOr(json['followup_visits']),
    );
  }
}

class TrackingLiveSummary {
  final bool isLive;
  final String? sessionId;
  final DateTime? checkInAt;
  final String status;
  final double totalDistanceKm;
  final DateTime? lastHeartbeatAt;
  final String? locationOffReason;
  final String? inactivityReason;

  const TrackingLiveSummary({
    required this.isLive,
    this.sessionId,
    this.checkInAt,
    required this.status,
    required this.totalDistanceKm,
    this.lastHeartbeatAt,
    this.locationOffReason,
    this.inactivityReason,
  });

  factory TrackingLiveSummary.empty() {
    return const TrackingLiveSummary(
      isLive: false,
      status: '',
      totalDistanceKm: 0,
    );
  }

  factory TrackingLiveSummary.fromJson(Map<String, dynamic> json) {
    final sess = json['session'];
    final m = sess is Map ? Map<String, dynamic>.from(sess) : <String, dynamic>{};
    final isLive = json['is_live'] == true;

    double km(dynamic v) => v == null ? 0.0 : (num.tryParse(v.toString())?.toDouble() ?? 0);

    return TrackingLiveSummary(
      isLive: isLive,
      sessionId: m['id']?.toString(),
      checkInAt: m['check_in_at'] != null ? DateTime.tryParse(m['check_in_at'].toString()) : null,
      status: m['status']?.toString() ?? '',
      totalDistanceKm: km(m['total_distance_km']),
      lastHeartbeatAt: m['last_heartbeat_at'] != null
          ? DateTime.tryParse(m['last_heartbeat_at'].toString())
          : null,
      locationOffReason: m['location_off_reason']?.toString(),
      inactivityReason: m['inactivity_reason']?.toString(),
    );
  }
}

// ——— Timeline ———

class HomeTimelineData {
  final List<TimelineEvent> events;

  const HomeTimelineData({required this.events});

  factory HomeTimelineData.empty() => const HomeTimelineData(events: []);

  factory HomeTimelineData.fromJson(Map<String, dynamic> json) {
    final raw = json['events'];
    if (raw is! List) return HomeTimelineData.empty();
    return HomeTimelineData(
      events: raw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return TimelineEvent.fromJson(m);
      }).toList(),
    );
  }
}

class TimelineEvent {
  final String type;
  final DateTime at;
  final String? sessionId;
  final String? visitId;
  final String label;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic> meta;

  const TimelineEvent({
    required this.type,
    required this.at,
    this.sessionId,
    this.visitId,
    required this.label,
    this.latitude,
    this.longitude,
    this.meta = const {},
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    final metaRaw = json['meta'];
    final meta = metaRaw is Map
        ? Map<String, dynamic>.from(metaRaw)
        : <String, dynamic>{};

    double? lat(dynamic v) =>
        v == null ? null : num.tryParse(v.toString())?.toDouble();
    final atStr = json['at']?.toString();
    final at = atStr != null ? DateTime.tryParse(atStr) ?? DateTime.now() : DateTime.now();

    return TimelineEvent(
      type: json['type']?.toString() ?? '',
      at: at,
      sessionId: json['session_id']?.toString(),
      visitId: json['visit_id']?.toString(),
      label: json['label']?.toString() ?? '',
      latitude: lat(json['latitude']),
      longitude: lat(json['longitude']),
      meta: meta,
    );
  }

  bool get isVisit => type == 'visit';
  bool get isCheckIn => type == 'tracking_check_in';
  bool get isCheckOut => type == 'tracking_check_out';
}

/// Bundle for the home UI: tracking insights + quick modules context.
class HomeDashboardContent {
  final bool insightsEnabled;
  final bool isCurrentMonthMtd;
  final HomePerformanceData performance;
  final HomeTimelineData timeline;
  final DateTime? displayRangeStart;
  final DateTime? displayRangeEnd;

  const HomeDashboardContent({
    required this.insightsEnabled,
    this.isCurrentMonthMtd = true,
    required this.performance,
    required this.timeline,
    this.displayRangeStart,
    this.displayRangeEnd,
  });

  factory HomeDashboardContent.noInsights() {
    return HomeDashboardContent(
      insightsEnabled: false,
      isCurrentMonthMtd: true,
      performance: HomePerformanceData.empty(),
      timeline: HomeTimelineData.empty(),
    );
  }
}
