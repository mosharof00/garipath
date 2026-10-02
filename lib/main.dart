import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const GariPathApp());
}

class GariPathApp extends StatelessWidget {
  const GariPathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'GariPath',
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: Text('GariPath'))),
    );
  }
}
