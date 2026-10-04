import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:garipath/config/app_config.dart';
import 'package:garipath/presentation/bindings/navigation_binding.dart';
import 'package:garipath/presentation/map_screen.dart';
import 'package:garipath/presentation/widgets/dev_banner.dart';

class GariPathApp extends StatelessWidget {
  const GariPathApp({super.key, required this.config});

  static const _deepGreen = Color(0xFF1B5E20);
  static const _lightGreenBackground = Color(0xFFF1F8F2);

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: config.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _deepGreen,
          primary: _deepGreen,
          surface: _lightGreenBackground,
        ),
      ),
      // The app has a single screen. Its binding creates the controllers with
      // the page and disposes them (onClose) when the page is removed.
      initialRoute: '/',
      getPages: [
        GetPage(
          name: '/',
          page: () => const MapScreen(),
          binding: NavigationBinding(config),
        ),
      ],
      builder: (context, child) => DevBanner(
        enabled: config.showDevBanner,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
