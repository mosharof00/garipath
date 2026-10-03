/// Turns raw numbers into short text for the screen.
///
/// Anything that isn't a valid amount (NaN, infinity, negative) shows as
/// "--" instead of crashing or printing "NaN km".
abstract final class Formatters {
  static const invalid = '--';

  /// "850 m", "1.0 km", "12.4 km", "153 km".
  static String distance(double meters) {
    if (!meters.isFinite || meters < 0) return invalid;

    final roundedMeters = meters.round();
    if (roundedMeters < 1000) return '$roundedMeters m';

    final km = meters / 1000;
    if (km < 100) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  /// "45 s", "1 min", "59 min", "1 h", "2 h 5 min".
  static String duration(double seconds) {
    if (!seconds.isFinite || seconds < 0) return invalid;

    final roundedSeconds = seconds.round();
    if (roundedSeconds < 60) return '$roundedSeconds s';

    // Round to whole minutes first, so 3599 s becomes "1 h", not "60 min".
    final totalMinutes = (seconds / 60).round();
    if (totalMinutes < 60) return '$totalMinutes min';

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return minutes == 0 ? '$hours h' : '$hours h $minutes min';
  }
}
