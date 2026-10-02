import 'package:garipath/config/app_config.dart';
import 'package:garipath/config/dev_config.dart';
import 'package:garipath/config/prod_config.dart';

/// Picks the config that matches the native build flavor.
///
/// [flavorName] comes from Flutter's `appFlavor`, which is set automatically by
/// `flutter run --flavor dev` or `--flavor prod`.
AppConfig resolveConfig(String? flavorName) {
  switch (flavorName) {
    case 'dev':
      return devConfig;
    case 'prod':
      return prodConfig;
    case null:
      throw StateError(
        'No flavor set. Run with --flavor dev or --flavor prod.',
      );
    default:
      throw StateError('Unknown flavor "$flavorName". Use dev or prod.');
  }
}
