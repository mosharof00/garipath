import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:garipath/app.dart';
import 'package:garipath/config/config_resolver.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // appFlavor is set by `flutter run --flavor <name>`.
  final config = resolveConfig(appFlavor);

  runApp(GariPathApp(config: config));
}
