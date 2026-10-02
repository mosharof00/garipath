package com.mosharof.garipath.location

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * Reads and requests the location permission.
 *
 * Android has no "permanently denied" API. We work it out like this:
 * - never asked before                      -> notDetermined
 * - asked, and Android would show a reason  -> denied (we can ask again)
 * - asked, and Android would NOT show one   -> deniedForever (only Settings helps)
 *
 * "Asked before" is saved in SharedPreferences, because before the very first
 * request Android also says "no reason needed", which looks like deniedForever.
 */
class PermissionManager(private val context: Context) :
    PluginRegistry.RequestPermissionsResultListener {

    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /** The Flutter call waiting for the user to answer the system dialog. */
    private var pendingResult: MethodChannel.Result? = null

    /** The visible Activity. Needed to show the dialog and read the rationale. */
    var activity: Activity? = null

    /** Current permission as the map Dart expects: status + isPrecise. */
    fun currentPermission(): Map<String, Any> =
        permissionMap(currentStatus(), isPrecise = hasPreciseLocationPermission())

    /** One of [PermissionStatusValues]. */
    fun currentStatus(): String = when {
        hasAnyLocationPermission() -> PermissionStatusValues.GRANTED
        !hasRequestedBefore() -> PermissionStatusValues.NOT_DETERMINED
        shouldShowRationale() -> PermissionStatusValues.DENIED
        else -> PermissionStatusValues.DENIED_FOREVER
    }

    /**
     * Shows the system dialog. The answer arrives later in
     * [onRequestPermissionsResult], so we keep [result] until then.
     */
    fun requestPermission(result: MethodChannel.Result) {
        // Already precise: nothing to ask. Approximate-only still asks, so the
        // user gets a chance to upgrade to precise.
        if (hasPreciseLocationPermission()) {
            result.success(currentPermission())
            return
        }

        val currentActivity = activity
        if (currentActivity == null) {
            result.error(
                LocationErrorCodes.ACTIVITY_UNAVAILABLE,
                "No visible screen to show the permission dialog.",
                null,
            )
            return
        }

        if (pendingResult != null) {
            result.error(
                LocationErrorCodes.REQUEST_IN_PROGRESS,
                "A permission request is already showing.",
                null,
            )
            return
        }

        pendingResult = OnceResult(result)
        // Save the flag before asking, so a crash mid-dialog can't lose it.
        prefs.edit().putBoolean(KEY_HAS_REQUESTED_BEFORE, true).apply()

        ActivityCompat.requestPermissions(
            currentActivity,
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ),
            REQUEST_CODE,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_CODE) return false

        val result = pendingResult ?: return true
        pendingResult = null

        if (grantResults.isEmpty()) {
            // The dialog was interrupted (no answer). Not a permanent "no".
            result.success(permissionMap(PermissionStatusValues.DENIED, isPrecise = false))
        } else {
            result.success(currentPermission())
        }
        return true
    }

    /** The error code to send when location is needed but not granted. */
    fun permissionErrorCode(): String =
        if (currentStatus() == PermissionStatusValues.DENIED_FOREVER) {
            LocationErrorCodes.PERMISSION_DENIED_FOREVER
        } else {
            LocationErrorCodes.PERMISSION_DENIED
        }

    /** The screen is gone, so the dialog answer will never come. Free the waiting call. */
    fun cancelPendingRequest() {
        val result = pendingResult ?: return
        pendingResult = null
        result.error(
            LocationErrorCodes.ACTIVITY_UNAVAILABLE,
            "The screen closed before the permission dialog was answered.",
            null,
        )
    }

    fun hasAnyLocationPermission(): Boolean =
        hasPreciseLocationPermission() ||
            isGranted(Manifest.permission.ACCESS_COARSE_LOCATION)

    fun hasPreciseLocationPermission(): Boolean =
        isGranted(Manifest.permission.ACCESS_FINE_LOCATION)

    private fun hasRequestedBefore(): Boolean =
        prefs.getBoolean(KEY_HAS_REQUESTED_BEFORE, false)

    /** Without a screen we can't read the rationale, so assume we may ask again. */
    private fun shouldShowRationale(): Boolean {
        val currentActivity = activity ?: return true
        return ActivityCompat.shouldShowRequestPermissionRationale(
            currentActivity,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) || ActivityCompat.shouldShowRequestPermissionRationale(
            currentActivity,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        )
    }

    private fun isGranted(permission: String): Boolean =
        ContextCompat.checkSelfPermission(context, permission) ==
            PackageManager.PERMISSION_GRANTED

    private fun permissionMap(status: String, isPrecise: Boolean): Map<String, Any> =
        mapOf(
            LocationKeys.STATUS to status,
            LocationKeys.IS_PRECISE to isPrecise,
        )

    private companion object {
        const val PREFS_NAME = "garipath_location"
        const val KEY_HAS_REQUESTED_BEFORE = "hasRequestedBefore"

        // Any app-unique number. Lets us ignore results meant for other code.
        const val REQUEST_CODE = 0x6A71
    }
}
