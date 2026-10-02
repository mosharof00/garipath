import 'package:logger/logger.dart';

/// The single logger for the whole app.
///
/// The default filter only prints in debug builds, so release builds stay
/// silent and nothing (like coordinates) ends up in the device log.
///
/// Levels used:
/// - `i` (info): important events, e.g. "permission granted", "fix received".
/// - `w` (warning): expected failures, e.g. "location services off".
/// - `e` (error): unexpected failures.
/// - `t` (trace): very frequent events (every stream fix).
///
/// The minimum level shown is [Logger.level], set once in `main.dart`
/// (and turned off for tests in `test/flutter_test_config.dart`).
final Logger appLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    noBoxingByDefault: true,
    dateTimeFormat: DateTimeFormat.onlyTime,
  ),
);
