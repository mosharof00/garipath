import 'dart:async';

import 'package:logger/logger.dart';

/// Runs before every test file. Keeps test output clean of app logs.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Logger.level = Level.off;
  await testMain();
}
