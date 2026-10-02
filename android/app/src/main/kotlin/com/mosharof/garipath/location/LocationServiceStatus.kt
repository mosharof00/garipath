package com.mosharof.garipath.location

import android.content.Context
import android.location.LocationManager
import androidx.core.location.LocationManagerCompat

/** Whether the device Location switch is on. */
fun Context.isLocationServiceEnabled(): Boolean {
    val locationManager = getSystemService(LocationManager::class.java) ?: return false
    return LocationManagerCompat.isLocationEnabled(locationManager)
}
