import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garipath/config/dev_config.dart';
import 'package:garipath/config/prod_config.dart';
import 'package:garipath/presentation/widgets/dev_banner.dart';

void main() {
  Widget buildBanner({required bool enabled}) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DevBanner(enabled: enabled, child: const Text('content')),
    );
  }

  testWidgets('shows the DEV ribbon in the dev flavor', (tester) async {
    await tester.pumpWidget(buildBanner(enabled: devConfig.showDevBanner));

    final banner = tester.widget<Banner>(find.byType(Banner));
    expect(banner.message, 'DEV');
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('shows no ribbon in the prod flavor', (tester) async {
    await tester.pumpWidget(buildBanner(enabled: prodConfig.showDevBanner));

    expect(find.byType(Banner), findsNothing);
    expect(find.text('content'), findsOneWidget);
  });
}
