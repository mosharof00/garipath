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

  // TEMP DEBUG
  final service = MethodChannelLocationService();
  debugPrint('GPDEBUG permission========${await service.checkPermission()}');
  debugPrint('GPDEBUG services=========${await service.isLocationServiceEnabled()}');

  runApp(GariPathApp(config: config));
}
