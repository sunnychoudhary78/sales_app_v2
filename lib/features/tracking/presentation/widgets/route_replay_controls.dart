import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tracking_route_replay.dart';

/// Route replay bar — parity with SalesAdminpanel RouteReplayControls.
class RouteReplayControls extends StatelessWidget {
  const RouteReplayControls({
    super.key,
    required this.canReplay,
    required this.playing,
    required this.elapsedMs,
    required this.durationMs,
    required this.speed,
    required this.onToggle,
    required this.onReset,
    required this.onElapsedChanged,
    required this.onSpeedChanged,
  });

  final bool canReplay;
  final bool playing;
  final int elapsedMs;
  final int durationMs;
  final int speed;
  final VoidCallback onToggle;
  final VoidCallback onReset;
  final ValueChanged<int> onElapsedChanged;
  final ValueChanged<int> onSpeedChanged;

  @override
  Widget build(BuildContext context) {
    if (!canReplay) {
      return _NoReplayHint();
    }

    final scheme = Theme.of(context).colorScheme;
    final max = durationMs > 0 ? durationMs : 1;
    final value = elapsedMs.clamp(0, max);
    final progress = value / max;
    final step = math.max(100, max ~/ 500);
    final narrow = MediaQuery.sizeOf(context).width < 400;

    return Material(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      color: scheme.surface.withValues(alpha: 0.98),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + MediaQuery.paddingOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: onToggle,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: narrow ? 12 : 16,
                        vertical: 10,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 22,
                    ),
                    label: Text(
                      playing ? 'Pause' : 'Play',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (narrow)
                    IconButton.outlined(
                      onPressed: onReset,
                      tooltip: 'Reset',
                      icon: const Icon(Icons.replay_rounded, size: 20),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: onReset,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.replay_rounded, size: 18),
                      label: const Text('Reset'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Speed',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  ...replaySpeeds.map((s) => _SpeedChip(
                        speed: s,
                        selected: speed == s,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onSpeedChanged(s);
                        },
                      )),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress.isFinite ? progress : 0,
                  minHeight: 4,
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: value.toDouble(),
                  min: 0,
                  max: max.toDouble(),
                  divisions: max > step ? (max / step).round().clamp(1, 500) : null,
                  onChanged: (v) => onElapsedChanged(v.round()),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${formatReplayClock(elapsedMs)} / ${formatReplayClock(durationMs)}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                    ),
                  ),
                  if (!narrow)
                    Text(
                      'Road-synced',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({
    required this.speed,
    required this.selected,
    required this.onTap,
  });

  final int speed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            '$speed×',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoReplayHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: scheme.onSurfaceVariant, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Not enough route data to replay. Need at least two GPS fixes in this session.',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
