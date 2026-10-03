import 'package:flutter_test/flutter_test.dart';
import 'package:garipath/features/routing/data/osrm_url_builder.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const dhaka = LatLng(23.8103, 90.4125);
  const chattogram = LatLng(22.3569, 91.7832);
  const base = 'https://router.project-osrm.org';

  test('full URL with longitude first, then latitude', () {
    final url = OsrmUrlBuilder.route(
      baseUrl: base,
      start: dhaka,
      destination: chattogram,
    );

    expect(
      url,
      'https://router.project-osrm.org/route/v1/driving/'
      '90.412500,23.810300;91.783200,22.356900'
      '?overview=full&geometries=polyline&alternatives=false&steps=false',
    );
  });

  test('a trailing slash in the base URL does not create "//"', () {
    final url = OsrmUrlBuilder.route(
      baseUrl: '$base/',
      start: dhaka,
      destination: chattogram,
    );

    expect(url, startsWith('$base/route/v1/'));
    expect(url.substring('https://'.length), isNot(contains('//')));
  });

  test('tiny and negative values never use scientific notation', () {
    final url = OsrmUrlBuilder.route(
      baseUrl: base,
      start: const LatLng(0.0000001, -0.0000001),
      destination: const LatLng(-33.8688, -151.2093),
    );

    expect(url, contains('-0.000000,0.000000;-151.209300,-33.868800'));
    expect(url, isNot(contains('e-')));
  });

  test('the URL parses as a valid https URI', () {
    final uri = Uri.parse(
      OsrmUrlBuilder.route(
        baseUrl: base,
        start: dhaka,
        destination: chattogram,
      ),
    );

    expect(uri.scheme, 'https');
    expect(uri.queryParameters['geometries'], 'polyline');
    expect(uri.queryParameters['overview'], 'full');
  });
}
