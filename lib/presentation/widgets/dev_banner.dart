import 'package:flutter/material.dart';

/// Shows a "DEV" ribbon in the corner so the dev build can't be mistaken for prod.
class DevBanner extends StatelessWidget {
  const DevBanner({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return Banner(
      message: 'DEV',
      location: BannerLocation.topEnd,
      color: Colors.deepOrange,
      child: child,
    );
  }
}
