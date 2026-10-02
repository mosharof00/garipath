package com.mosharof.garipath.location

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.location.LocationManager
import android.net.Uri
import android.provider.Settings
import androidx.core.location.LocationManagerCompat
import com.google.android.gms.location.LocationServices
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

    private val currentLocationFetcher = CurrentLocationFetcher(
        fusedClient = LocationServices.getFusedLocationProviderClient(context),
        permissionManager = permissionManager,
        isLocationServiceEnabled = ::isLocationServiceEnabled,
    )

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            LocationMethods.CHECK_PERMISSION ->
                result.success(permissionManager.currentPermission())

            LocationMethods.REQUEST_PERMISSION ->
                permissionManager.requestPermission(result)

            LocationMethods.IS_LOCATION_SERVICE_ENABLED ->
                result.success(isLocationServiceEnabled())

            LocationMethods.GET_CURRENT_LOCATION -> getCurrentLocation(call, result)

            LocationMethods.OPEN_APP_SETTINGS -> openSettings(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.fromParts("package", context.packageName, null),
                ),
                result,
            )

            LocationMethods.OPEN_LOCATION_SETTINGS ->
                openSettings(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS), result)

            else -> result.notImplemented()
        }
    }

    fun isLocationServiceEnabled(): Boolean {
        val locationManager = context.getSystemService(LocationManager::class.java)
            ?: return false
        return LocationManagerCompat.isLocationEnabled(locationManager)
    }

    private fun getCurrentLocation(call: MethodCall, result: MethodChannel.Result) {
        // Dart ints arrive as Int or Long depending on size, so read as Number.
        val timeoutMs = call.argument<Number>(LocationArgs.TIMEOUT_MS)?.toLong()
        if (timeoutMs == null || timeoutMs <= 0) {
            result.error(
                LocationErrorCodes.INVALID_ARGUMENT,
                "timeoutMs must be a positive number.",
                null,
            )
            return
        }
        currentLocationFetcher.fetch(timeoutMs, result)
    }

    /** Replies true if the screen opened, false if the device has no such screen. */
    private fun openSettings(intent: Intent, result: MethodChannel.Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error(
                LocationErrorCodes.ACTIVITY_UNAVAILABLE,
                "No visible screen to open Settings from.",
                null,
            )
            return
        }
        try {
            currentActivity.startActivity(intent)
            result.success(true)
        } catch (error: ActivityNotFoundException) {
            result.success(false)
        }
    }
}
