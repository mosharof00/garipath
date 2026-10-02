package com.mosharof.garipath.location

import android.location.Location

/**
 * Converts an Android [Location] into the map Dart expects.
 * Optional values are only sent when Android says they exist.
 */
fun Location.toChannelMap(isPrecise: Boolean): Map<String, Any?> = mapOf(
    LocationKeys.LATITUDE to latitude,
    LocationKeys.LONGITUDE to longitude,
    LocationKeys.ACCURACY to if (hasAccuracy()) accuracy.toDouble() else null,
    LocationKeys.BEARING to if (hasBearing()) bearing.toDouble() else null,
    LocationKeys.SPEED to if (hasSpeed()) speed.toDouble() else null,
    LocationKeys.TIMESTAMP to time,
    LocationKeys.IS_PRECISE to isPrecise,
)
