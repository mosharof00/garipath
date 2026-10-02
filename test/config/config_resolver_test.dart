import 'package:flutter_test/flutter_test.dart';
import 'package:garipath/config/app_config.dart';
import 'package:garipath/config/config_resolver.dart';
import 'package:garipath/config/dev_config.dart';
import 'package:garipath/config/prod_config.dart';

void main() {
  group('resolveConfig', () {
    test('returns the dev config for "dev"', () {
      expect(resolveConfig('dev'), same(devConfig));
    });

    test('returns the prod config for "prod"', () {
      expect(resolveConfig('prod'), same(prodConfig));
    });

    test('throws a clear error when no flavor is set', () {
      expect(() => resolveConfig(null), throwsStateError);
    });

    test('throws for an unknown flavor', () {
      expect(() => resolveConfig('staging'), throwsStateError);
    });
  });

  group('flavor configs', () {
    test('only dev shows the DEV banner', () {
      expect(devConfig.showDevBanner, isTrue);
      expect(prodConfig.showDevBanner, isFalse);
    });

    test('flavors have their own application ids', () {
      expect(devConfig.applicationId, 'com.mosharof.garipath.dev');
      expect(prodConfig.applicationId, 'com.mosharof.garipath');
      expect(devConfig.flavor, AppFlavor.dev);
      expect(prodConfig.flavor, AppFlavor.prod);
    });

    test('routing base URLs are valid https URLs without a trailing slash', () {
      for (final config in [devConfig, prodConfig]) {
        final uri = Uri.parse(config.osrmBaseUrl);
        expect(uri.scheme, 'https');
        expect(uri.host, isNotEmpty);
        expect(config.osrmBaseUrl.endsWith('/'), isFalse);
      }
    });
  });
}
