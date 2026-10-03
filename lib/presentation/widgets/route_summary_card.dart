import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:garipath/core/util/formatters.dart';
import 'package:garipath/features/navigation/presentation/navigation_controller.dart';
import 'package:garipath/features/routing/domain/route_failure.dart';
import 'package:garipath/features/routing/presentation/route_controller.dart';
import 'package:garipath/presentation/widgets/navigation_controls.dart';

/// The bottom panel: hint, loading, route summary or route error. With a
/// route, it also holds the playback controls.
class RouteSummaryCard extends StatelessWidget {
  const RouteSummaryCard({
    super.key,
    required this.controller,
    required this.navigation,
  });

  final RouteController controller;
  final NavigationController navigation;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Obx(() {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _body(context),
                if (controller.status.value == RouteStatus.ready &&
                    !controller.pickingStart.value) ...[
                  const SizedBox(height: 8),
                  NavigationControls(controller: navigation),
                ],
                if (controller.manualStart.value != null &&
                    !controller.pickingStart.value)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ActionChip(
                      avatar: const Icon(Icons.my_location, size: 18),
                      label: const Text('Use my location as start'),
                      onPressed: controller.clearManualStart,
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (controller.pickingStart.value) {
      return _MessageRow(
        icon: Icons.touch_app,
        message: 'Long-press on the map to set the start point.',
        action: TextButton(
          onPressed: controller.cancelPickingStart,
          child: const Text('Cancel'),
        ),
      );
    }

    switch (controller.status.value) {
      case RouteStatus.idle:
        return const _MessageRow(
          icon: Icons.touch_app,
          message: 'Long-press on the map to choose a destination.',
        );
      case RouteStatus.waitingForStart:
        return _MessageRow(
          icon: Icons.hourglass_empty,
          message: 'Destination set. Waiting for your start location…',
          action: TextButton(
            onPressed: controller.startPickingStart,
            child: const Text('Pick start'),
          ),
        );
      case RouteStatus.loading:
      case RouteStatus.loadingSlow:
        final slow = controller.status.value == RouteStatus.loadingSlow;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(slow ? 'Still finding a route…' : 'Finding a route…'),
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
        );
      case RouteStatus.ready:
        final route = controller.route.value;
        if (route == null) return const SizedBox.shrink();
        return _MessageRow(
          icon: Icons.directions_car,
          message:
              '${Formatters.distance(route.distanceMeters)} · '
              '${Formatters.duration(route.durationSeconds)}',
          large: true,
          action: IconButton(
            tooltip: 'Clear route',
            onPressed: controller.clear,
            icon: const Icon(Icons.close),
          ),
        );
      case RouteStatus.error:
        final failure = controller.failure.value;
        if (failure == null) return const SizedBox.shrink();
        return _failureRow(failure);
    }
  }

  Widget _failureRow(RouteFailure failure) {
    final retry = TextButton(
      onPressed: controller.retry,
      child: const Text('Retry'),
    );

    return switch (failure) {
      RouteDestinationTooClose() => const _MessageRow(
        icon: Icons.info_outline,
        message: 'Destination is too close. Pick a point farther away.',
      ),
      RouteNoRoute() => const _MessageRow(
        icon: Icons.wrong_location,
        message: 'No drivable route to that point. Try somewhere on a road.',
      ),
      RouteNetworkFailure() => _MessageRow(
        icon: Icons.wifi_off,
        message: 'No internet connection.',
        action: retry,
      ),
      RouteTimeout() => _MessageRow(
        icon: Icons.timer_off,
        message: 'Routing server is slow to respond.',
        action: retry,
      ),
      RouteRateLimited() => const _MessageRow(
        icon: Icons.hourglass_top,
        message: 'Routing server is busy. Retrying shortly…',
      ),
      RouteServerError() => _MessageRow(
        icon: Icons.cloud_off,
        message: 'Routing server error.',
        action: retry,
      ),
      RouteInvalidResponse() => _MessageRow(
        icon: Icons.error_outline,
        message: 'Unexpected response from the routing server.',
        action: retry,
      ),
    };
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.icon,
    required this.message,
    this.action,
    this.large = false,
  });

  final IconData icon;
  final String message;
  final Widget? action;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final action = this.action;

    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: large ? textTheme.titleLarge : textTheme.bodyMedium,
          ),
        ),
        ?action, // added only when not null
      ],
    );
  }
}
