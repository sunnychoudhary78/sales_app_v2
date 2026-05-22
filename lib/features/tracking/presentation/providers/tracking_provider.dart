import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/tracking_session_model.dart';
import '../../data/tracking_repository.dart';

class TrackingState {
  final bool isLoading;
  final bool isTracking;
  final String durationText;
  final List<TrackingSessionModel> history;

  const TrackingState({
    required this.isLoading,
    required this.isTracking,
    required this.durationText,
    required this.history,
  });

  const TrackingState.initial()
    : this(
        isLoading: false,
        isTracking: false,
        durationText: '00:00:00',
        history: const [],
      );

  TrackingState copyWith({
    bool? isLoading,
    bool? isTracking,
    String? durationText,
    List<TrackingSessionModel>? history,
  }) {
    return TrackingState(
      isLoading: isLoading ?? this.isLoading,
      isTracking: isTracking ?? this.isTracking,
      durationText: durationText ?? this.durationText,
      history: history ?? this.history,
    );
  }
}

class TrackingNotifier extends Notifier<TrackingState> {
  Timer? _timer;
  DateTime? _checkInTime;

  @override
  TrackingState build() {
    _init();
    ref.onDispose(() {
      _timer?.cancel();
    });
    return const TrackingState.initial();
  }

  Future<void> _init() async {
    await refreshStatus();
    await fetchHistory();
  }

  Future<void> refreshStatus() async {
    final repo = ref.read(trackingRepositoryProvider);
    final auth = ref.read(authProvider);
    final userId = auth.profile?.userId ?? auth.rawUser?['id']?.toString();
    await repo.tryRestoreActiveSessionFromServer(userId);

    final sessionId = await repo.getStoredSessionId();
    final checkInRaw = await repo.getStoredCheckInTime();
    _checkInTime = checkInRaw != null ? DateTime.tryParse(checkInRaw) : null;
    final tracking = sessionId != null && sessionId.isNotEmpty;
    state = state.copyWith(isTracking: tracking);
    if (tracking) {
      await repo.ensureBackgroundTrackingRunning();
      _startTimer();
    } else {
      _stopTimer();
      state = state.copyWith(durationText: '00:00:00');
    }
  }

  Future<void> fetchHistory() async {
    final list = await ref.read(trackingRepositoryProvider).fetchHistory();
    state = state.copyWith(history: list);
  }

  Future<void> checkIn() async {
    state = state.copyWith(isLoading: true);
    try {
      final started = await ref.read(trackingRepositoryProvider).checkIn();
      if (started) {
        _checkInTime = DateTime.now();
        state = state.copyWith(isTracking: true);
        _startTimer();
      }
      await fetchHistory();
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> checkOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await ref.read(trackingRepositoryProvider).checkOut();
      state = state.copyWith(isTracking: false, durationText: '00:00:00');
      _stopTimer();
      await fetchHistory();
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_checkInTime == null) return;
      final diff = DateTime.now().difference(_checkInTime!);
      state = state.copyWith(durationText: _formatDuration(diff));
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }
}

final trackingProvider = NotifierProvider<TrackingNotifier, TrackingState>(
  TrackingNotifier.new,
);
