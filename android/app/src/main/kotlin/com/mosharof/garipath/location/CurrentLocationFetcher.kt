package com.mosharof.garipath.location

import android.annotation.SuppressLint
import android.content.Context
import android.location.Location
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import com.google.android.gms.location.CurrentLocationRequest
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import io.flutter.plugin.common.MethodChannel

/**
 * Gets a single fresh location with a hard timeout.
 *
 * It never shows the permission dialog: Dart asks first, then calls this.
 */
class CurrentLocationFetcher(
    private val context: Context,
    private val fusedClient: FusedLocationProviderClient,
    private val permissionManager: PermissionManager,
) {
    private val mainHandler = Handler(Looper.getMainLooper())

    // Permission is checked at the top of fetch(); lint can't see that.
    @SuppressLint("MissingPermission")
    fun fetch(timeoutMs: Long, flutterResult: MethodChannel.Result) {
        val result = OnceResult(flutterResult)

        if (!permissionManager.hasAnyLocationPermission()) {
            replyPermissionError(result)
            return
        }
        if (!context.isLocationServiceEnabled()) {
            result.error(
                LocationErrorCodes.SERVICES_DISABLED,
                "Device location is turned off.",
                null,
            )
            return
        }

        val isPrecise = permissionManager.hasPreciseLocationPermission()
        val request = CurrentLocationRequest.Builder()
            .setPriority(
                if (isPrecise) Priority.PRIORITY_HIGH_ACCURACY
                else Priority.PRIORITY_BALANCED_POWER_ACCURACY,
            )
            .setDurationMillis(timeoutMs)
            .setMaxUpdateAgeMillis(MAX_CACHED_AGE_MS)
            .build()
        val cancellation = CancellationTokenSource()

        // Safety net in case Play Services never calls back.
        val watchdog = Runnable {
            cancellation.cancel()
            result.error(LocationErrorCodes.TIMEOUT, "No location within ${timeoutMs}ms.", null)
        }
        mainHandler.postDelayed(watchdog, timeoutMs + WATCHDOG_EXTRA_MS)

        try {
            fusedClient.getCurrentLocation(request, cancellation.token)
                .addOnSuccessListener { location ->
                    mainHandler.removeCallbacks(watchdog)
                    if (location != null) {
                        result.success(location.toChannelMap(isPrecise))
                    } else {
                        replyWithRecentLastLocation(result, isPrecise)
                    }
                }
                .addOnFailureListener { error ->
                    mainHandler.removeCallbacks(watchdog)
                    if (error is SecurityException) {
                        replyPermissionError(result)
                    } else {
                        result.error(LocationErrorCodes.UNKNOWN, error.message, null)
                    }
                }
        } catch (error: SecurityException) {
            // Permission was revoked between our check and the call.
            mainHandler.removeCallbacks(watchdog)
            replyPermissionError(result)
        }
    }

    /** Fallback when no fresh fix arrived: accept the last known one if it's recent. */
    @SuppressLint("MissingPermission")
    private fun replyWithRecentLastLocation(result: MethodChannel.Result, isPrecise: Boolean) {
        try {
            fusedClient.lastLocation
                .addOnSuccessListener { last ->
                    if (last != null && ageMillis(last) <= MAX_FALLBACK_AGE_MS) {
                        result.success(last.toChannelMap(isPrecise))
                    } else {
                        result.error(LocationErrorCodes.TIMEOUT, "No location fix available.", null)
                    }
                }
                .addOnFailureListener {
                    result.error(LocationErrorCodes.TIMEOUT, "No location fix available.", null)
                }
        } catch (error: SecurityException) {
            replyPermissionError(result)
        }
    }

    private fun replyPermissionError(result: MethodChannel.Result) {
        result.error(
            permissionManager.permissionErrorCode(),
            "Location permission is not granted.",
            null,
        )
    }

    /** Uses the boot clock, so changing the phone's time doesn't break it. */
    private fun ageMillis(location: Location): Long =
        (SystemClock.elapsedRealtimeNanos() - location.elapsedRealtimeNanos) / 1_000_000

    private companion object {
        const val MAX_CACHED_AGE_MS = 30_000L
        const val MAX_FALLBACK_AGE_MS = 60_000L
        const val WATCHDOG_EXTRA_MS = 1_000L
    }
}
