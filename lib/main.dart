import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:garipath/app.dart';
import 'package:garipath/config/config_resolver.dart';
import 'package:garipath/features/location/data/method_channel_location_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // appFlavor is set by `flutter run --flavor <name>`.
  final config = resolveConfig(appFlavor);

  runApp(GariPathApp(config: config));

  // TEMP DEBUG - do not commit
  final service = MethodChannelLocationService();
  debugPrint('GPDEBUG before request = ${await service.checkPermission()}');
  try {
    debugPrint('GPDEBUG request result = ${await service.requestPermission()}');
  } catch (e) {
    debugPrint('GPDEBUG request error = $e');
  }
  debugPrint('GPDEBUG after request  = ${await service.checkPermission()}');
}
