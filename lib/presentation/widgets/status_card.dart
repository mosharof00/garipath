import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:garipath/features/location/domain/location_exception.dart';
import 'package:garipath/features/location/presentation/location_controller.dart';

/// The card at the top of the map that explains the location state and
/// offers the action that fixes it.
class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.controller,
    this.onPickStartOnMap,
  });

  final LocationController controller;

  /// "Pick start on map" fallback. The button is hidden while this is null.
  final VoidCallback? onPickStartOnMap;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final content = _contentFor(
        controller.status.value,
        controller.error.value,
        isPrecise: controller.isPrecise.value,
      );
      if (content == null) return const SizedBox.shrink();
      return _CardView(content: content, onPickStartOnMap: onPickStartOnMap);
    });
  }

  _CardContent? _contentFor(
    LocationStatus status,
    LocationException? error, {
    required bool isPrecise,
  }) {
    switch (status) {
      case LocationStatus.idle:
        return null;
      case LocationStatus.needsPermission:
        return _CardContent(
          icon: Icons.location_on_outlined,
          message: 'GariPath uses your location as the trip start.',
          primary: _CardAction('Use my location', controller.requestAndLocate),
        );
      case LocationStatus.requesting:
        return null; // the system dialog is showing
      case LocationStatus.acquiring:
        return const _CardContent(
          message: 'Finding your location…',
          showSpinner: true,
        );
      case LocationStatus.ready:
        if (isPrecise) return null;
        return _CardContent(
          icon: Icons.info_outline,
          message: 'Approximate location. The start may be inaccurate.',
          primary: _CardAction(
            'Use precise location',
            controller.requestAndLocate,
          ),
        );
      case LocationStatus.error:
        return error == null ? null : _errorContent(error);
    }
  }

  _CardContent _errorContent(LocationException error) {
    return switch (error) {
      LocationPermissionDenied() => _CardContent(
        icon: Icons.location_disabled,
        message: 'Location permission denied.',
        primary: _CardAction('Try again', controller.retry),
      ),
      LocationPermissionPermanentlyDenied() => _CardContent(
        icon: Icons.block,
        message: 'Location is blocked for GariPath.',
        primary: _CardAction('Open Settings', controller.openSettings),
      ),
      LocationServicesDisabled() => _CardContent(
        icon: Icons.location_off,
        message: 'Location services are turned off.',
        primary: _CardAction('Open Location Settings', controller.openSettings),
      ),
      LocationTimeout() || LocationUnavailable() => _CardContent(
        icon: Icons.gps_not_fixed,
        message: "Couldn't get a GPS fix. Move near a window or try again.",
        primary: _CardAction('Retry', controller.retry),
      ),
      LocationNotSupported() => const _CardContent(
        icon: Icons.location_disabled,
        message: "Device location isn't supported on this platform yet.",
      ),
      LocationRequestInProgress() ||
      LocationActivityUnavailable() ||
      LocationUnknownError() => _CardContent(
        icon: Icons.error_outline,
        message: 'Something went wrong while getting your location.',
        primary: _CardAction('Try again', controller.retry),
      ),
    };
  }
}

class _CardAction {
  const _CardAction(this.label, this.onPressed);

  final String label;
  final VoidCallback onPressed;
}

class _CardContent {
  const _CardContent({
    required this.message,
    this.icon,
    this.primary,
    this.showSpinner = false,
  });

  final String message;
  final IconData? icon;
  final _CardAction? primary;
  final bool showSpinner;
}

class _CardView extends StatelessWidget {
  const _CardView({required this.content, this.onPickStartOnMap});

  final _CardContent content;
  final VoidCallback? onPickStartOnMap;

  @override
  Widget build(BuildContext context) {
    final primary = content.primary;
    final pickStart = onPickStartOnMap;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (content.showSpinner)
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (content.icon != null)
                  Icon(content.icon),
                const SizedBox(width: 12),
                Expanded(child: Text(content.message)),
              ],
            ),
            if (primary != null || pickStart != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (pickStart != null)
                      TextButton(
                        onPressed: pickStart,
                        child: const Text('Pick start on map'),
                      ),
                    if (primary != null)
                      FilledButton(
                        onPressed: primary.onPressed,
                        child: Text(primary.label),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
