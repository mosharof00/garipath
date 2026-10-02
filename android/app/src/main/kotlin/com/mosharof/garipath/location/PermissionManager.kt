package com.mosharof.garipath.location

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat

/**
 * Reads and requests the location permission.
 */
class PermissionManager(private val context: Context) {

    /** Current permission as the map Dart expects: status + isPrecise. */
    fun currentPermission(): Map<String, Any> {
        val fine = isGranted(Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse = isGranted(Manifest.permission.ACCESS_COARSE_LOCATION)

        val status = if (fine || coarse) {
            PermissionStatusValues.GRANTED
        } else {
            PermissionStatusValues.NOT_DETERMINED
        }

        return mapOf(
            LocationKeys.STATUS to status,
            LocationKeys.IS_PRECISE to fine,
        )
    }

    fun hasAnyLocationPermission(): Boolean =
        isGranted(Manifest.permission.ACCESS_FINE_LOCATION) ||
            isGranted(Manifest.permission.ACCESS_COARSE_LOCATION)

    private fun isGranted(permission: String): Boolean =
        ContextCompat.checkSelfPermission(context, permission) ==
            PackageManager.PERMISSION_GRANTED
}
