#!/usr/bin/env bash
#
# Fails if a forbidden package appears in pubspec.lock (directly or as a
# transitive dependency). The assessment requires our own native location and
# permission code, and only free, keyless map/routing services.
#
# Usage: bash tool/check_forbidden_deps.sh [path/to/pubspec.lock]

LOCK_FILE="${1:-pubspec.lock}"

FORBIDDEN='geolocator[a-z_]*|location|location_platform_interface|permission_handler[a-z_]*|app_settings|flutter_map_location_marker|background_location|flutter_background_geolocation|google_maps_flutter[a-z_]*|mapbox[a-z_]*'

# Package names in pubspec.lock are indented by exactly two spaces.
MATCHES=$(grep -E "^  (${FORBIDDEN}):" "$LOCK_FILE")

if [ -n "$MATCHES" ]; then
  echo "Forbidden packages found in $LOCK_FILE:"
  echo "$MATCHES"
  exit 1
fi
