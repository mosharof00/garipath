import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:garipath/app.dart';
import 'package:garipath/config/config_resolver.dart';
import 'package:garipath/features/location/data/method_channel_location_service.dart';
import 'package:garipath/features/location/domain/location_permission.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // appFlavor is set by `flutter run --flavor <name>`.
  final config = resolveConfig(appFlavor);

  runApp(GariPathApp(config: config));

  // TEMP DEBUG
  final service = MethodChannelLocationService();
  final permission = await service.requestPermission();
  debugPrint('GPDEBUG permission = $permission');
  if (permission.status == LocationPermissionStatus.deniedForever) {
    debugPrint('GPDEBUG openAppSettings = ${await service.openAppSettings()}');
    return;
  }
  if (!await service.isLocationServiceEnabled()) {
    debugPrint(
      'GPDEBUG openLocationSettings = ${await service.openLocationSettings()}',
    );
    return;
  }
  final stopwatch = Stopwatch()..start();
  try {
    final fix = await service.getCurrentLocation(
      timeout: const Duration(seconds: 10),
    );
    debugPrint(
      'GPDEBUG fix in ${stopwatch.elapsedMilliseconds}ms = '
      '${fix.latitude}, ${fix.longitude} ±${fix.accuracyMeters}m precise=${fix.isPrecise}',
    );
  } catch (e) {
    debugPrint('GPDEBUG error in ${stopwatch.elapsedMilliseconds}ms = $e');
  }
}
