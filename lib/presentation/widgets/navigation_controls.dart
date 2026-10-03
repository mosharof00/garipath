import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:garipath/core/navigation/route_animator.dart';
import 'package:garipath/core/util/formatters.dart';
import 'package:garipath/features/navigation/presentation/navigation_controller.dart';

/// Live trip stats plus Start / Pause / Resume / Reset and the 1x/2x/5x
/// speed selector. Shown under the route summary when a route is ready.
class NavigationControls extends StatelessWidget {
  const NavigationControls({super.key, required this.controller});

  static const speedOptions = [1, 2, 5];

  final NavigationController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LiveStats(controller: controller),
        const SizedBox(height: 8),
        Obx(() => _buttons(controller.playback.value)),
      ],
    );
  }

  Widget _buttons(PlaybackState state) {
    final primary = switch (state) {
      PlaybackState.idle => FilledButton.icon(
        onPressed: controller.start,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start'),
      ),
      PlaybackState.playing => FilledButton.icon(
        onPressed: controller.pause,
        icon: const Icon(Icons.pause),
        label: const Text('Pause'),
      ),
      PlaybackState.paused => FilledButton.icon(
        onPressed: controller.resume,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Resume'),
      ),
      PlaybackState.finished => FilledButton.icon(
        onPressed: controller.start,
        icon: const Icon(Icons.replay),
        label: const Text('Restart'),
      ),
    };

    // Wrap: on a narrow phone the speed selector moves to a second line
    // instead of overflowing.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            primary,
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Reset',
              // Nothing to reset before the car has moved.
              onPressed: state == PlaybackState.idle ? null : controller.reset,
              icon: const Icon(Icons.restart_alt),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<DriveMode>(
              showSelectedIcon: false,
              style: _compact,
              segments: [
                const ButtonSegment(
                  value: DriveMode.simulated,
                  label: Text('Sim'),
                  tooltip: 'Simulated drive',
                ),
                ButtonSegment(
                  value: DriveMode.live,
                  label: const Text('Live'),
                  tooltip: 'Follow my real GPS position',
                  // Live needs a device location.
                  enabled: controller.canUseLive,
                ),
              ],
              selected: {controller.mode.value},
              onSelectionChanged: (selection) =>
                  controller.setMode(selection.first),
            ),
            const SizedBox(width: 8),
            SegmentedButton<int>(
              showSelectedIcon: false,
              style: _compact,
              segments: [
                for (final speed in speedOptions)
                  ButtonSegment(value: speed, label: Text('${speed}x')),
              ],
              selected: {controller.multiplier.value},
              // Real driving has no speed multiplier.
              onSelectionChanged: controller.mode.value == DriveMode.live
                  ? null
                  : (selection) => controller.setMultiplier(selection.first),
            ),
          ],
        ),
      ],
    );
  }

  static const _compact = ButtonStyle(
    visualDensity: VisualDensity.compact,
    padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
  );
}

/// "Remaining 1.2 km · 1 min", or "Arrived" at the end. Listens to the
/// throttled `hud` value, so it rebuilds about 5 times a second, not 60.
class _LiveStats extends StatelessWidget {
  const _LiveStats({required this.controller});

  final NavigationController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = controller.playback.value;
      final hud = controller.hud.value;
      if (state == PlaybackState.idle || hud == null) {
        return const SizedBox.shrink();
      }

      if (state == PlaybackState.finished) {
        return const Row(
          children: [
            Icon(Icons.flag, color: Colors.green),
            SizedBox(width: 8),
            Text('Arrived'),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Remaining ${Formatters.distance(hud.remainingMeters)} · '
            '${Formatters.duration(hud.remainingSeconds)}',
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: hud.progress),
        ],
      );
    });
  }
}
