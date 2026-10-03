import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Decodes Google's "encoded polyline" format, which OSRM returns with
/// `geometries=polyline`.
///
/// How the format works:
/// - Each point is stored as the difference from the previous point,
///   multiplied by 10^precision (1e5 for OSRM) and rounded to an integer.
/// - Each integer is "zigzag" encoded so negatives become positive
///   (0, -1, 1, -2, … -> 0, 1, 2, 3, …).
/// - That number is split into 5-bit chunks, lowest first. Every chunk except
///   the last has the 0x20 bit set, meaning "more chunks follow".
/// - Each chunk gets 63 added so it becomes a printable character.
abstract final class PolylineCodec {
  /// Returns the points in lat, lng order.
  ///
  /// Throws a [FormatException] if the text is cut off or contains a
  /// character that can't be part of an encoded polyline.
  static List<LatLng> decode(String encoded, {int precision = 5}) {
    final factor = math.pow(10, precision);
    final points = <LatLng>[];
    final reader = _Reader(encoded);

    var latitude = 0;
    var longitude = 0;
    while (reader.hasMore) {
      latitude += reader.readValue();
      if (!reader.hasMore) {
        throw FormatException(
          'Polyline ends after a latitude with no longitude',
          encoded,
          reader.index,
        );
      }
      longitude += reader.readValue();

      final lat = latitude / factor;
      final lng = longitude / factor;
      if (lat.abs() > 90 || lng.abs() > 180) {
        throw FormatException(
          'Polyline point out of range: $lat, $lng',
          encoded,
          reader.index,
        );
      }
      points.add(LatLng(lat, lng));
    }
    return points;
  }
}

/// Reads one encoded number at a time from the text.
class _Reader {
  _Reader(this.text);

  final String text;
  int index = 0;

  // A valid coordinate never needs more than 7 chunks (35 bits).
  static const _maxShift = 35;

  bool get hasMore => index < text.length;

  int readValue() {
    var result = 0;
    var shift = 0;
    int chunk;
    do {
      if (!hasMore) {
        throw FormatException('Polyline is cut off', text, index);
      }
      chunk = text.codeUnitAt(index) - 63;
      if (chunk < 0 || chunk > 63) {
        throw FormatException('Invalid polyline character', text, index);
      }
      if (shift > _maxShift) {
        throw FormatException('Polyline number is too long', text, index);
      }
      index++;
      result |= (chunk & 0x1f) << shift;
      shift += 5;
    } while (chunk >= 0x20);

    // Undo the zigzag: odd numbers were negative.
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }
}
