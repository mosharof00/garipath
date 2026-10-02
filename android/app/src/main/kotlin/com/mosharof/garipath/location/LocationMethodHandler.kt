package com.mosharof.garipath.location

import android.app.Activity
import android.content.Context
import android.location.LocationManager
import androidx.core.location.LocationManagerCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Handles the request/response calls of the location MethodChannel.
 */
class LocationMethodHandler(
    private val context: Context,
    private val permissionManager: PermissionManager,
) : MethodChannel.MethodCallHandler {

    /** The visible Activity, needed for dialogs and Settings. Null in background. */
    var activity: Activity? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            LocationMethods.CHECK_PERMISSION ->
                result.success(permissionManager.currentPermission())

            LocationMethods.REQUEST_PERMISSION ->
                permissionManager.requestPermission(result)

            LocationMethods.IS_LOCATION_SERVICE_ENABLED ->
                result.success(isLocationServiceEnabled())

            else -> result.notImplemented()
        }
    }

    fun isLocationServiceEnabled(): Boolean {
        val locationManager = context.getSystemService(LocationManager::class.java)
            ?: return false
        return LocationManagerCompat.isLocationEnabled(locationManager)
    }
}
