package com.mosharof.garipath.location

// Mirror of lib/features/location/data/location_channel_contract.dart.
// Every name, key and code must match the Dart side exactly.

object LocationChannels {
    const val METHOD = "com.mosharof.garipath/location"
    const val EVENTS = "com.mosharof.garipath/location_updates"
}

object LocationMethods {
    const val CHECK_PERMISSION = "checkPermission"
    const val REQUEST_PERMISSION = "requestPermission"
    const val IS_LOCATION_SERVICE_ENABLED = "isLocationServiceEnabled"
    const val GET_CURRENT_LOCATION = "getCurrentLocation"
    const val OPEN_APP_SETTINGS = "openAppSettings"
    const val OPEN_LOCATION_SETTINGS = "openLocationSettings"
}

object LocationArgs {
    const val TIMEOUT_MS = "timeoutMs"
    const val INTERVAL_MS = "intervalMs"
    const val MIN_DISTANCE_METERS = "minDistanceMeters"
}

object LocationKeys {
    const val LATITUDE = "lat"
    const val LONGITUDE = "lng"
    const val ACCURACY = "accuracy"
    const val BEARING = "bearing"
    const val SPEED = "speed"
    const val TIMESTAMP = "timestamp"
    const val IS_PRECISE = "isPrecise"
    const val STATUS = "status"
}

object PermissionStatusValues {
    const val NOT_DETERMINED = "notDetermined"
    const val DENIED = "denied"
    const val DENIED_FOREVER = "deniedForever"
    const val GRANTED = "granted"
}

object LocationErrorCodes {
    const val PERMISSION_DENIED = "PERMISSION_DENIED"
    const val PERMISSION_DENIED_FOREVER = "PERMISSION_DENIED_FOREVER"
    const val SERVICES_DISABLED = "SERVICES_DISABLED"
    const val TIMEOUT = "TIMEOUT"
    const val UNAVAILABLE = "LOCATION_UNAVAILABLE"
    const val REQUEST_IN_PROGRESS = "REQUEST_IN_PROGRESS"
    const val ACTIVITY_UNAVAILABLE = "ACTIVITY_UNAVAILABLE"
    const val NOT_SUPPORTED = "NOT_SUPPORTED"
    const val INVALID_ARGUMENT = "INVALID_ARGUMENT"
    const val UNKNOWN = "UNKNOWN"
}
