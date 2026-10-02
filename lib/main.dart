import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:garipath/app.dart';
import 'package:garipath/config/config_resolver.dart';
import 'package:garipath/core/logging/app_logger.dart';
import 'package:logger/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Change to Level.trace to also see every location stream fix.
  Logger.level = Level.debug;

  // appFlavor is set by `flutter run --flavor <name>`.
  final config = resolveConfig(appFlavor);
  appLogger.i('Starting ${config.appName} (${config.flavor.name} flavor)');

  runApp(GariPathApp(config: config));
}
