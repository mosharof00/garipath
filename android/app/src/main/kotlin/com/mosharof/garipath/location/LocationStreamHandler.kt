package com.mosharof.garipath.location

import android.annotation.SuppressLint
import android.content.Context
import android.os.Looper
import android.util.Log
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationAvailability
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.Priority
import io.flutter.plugin.common.EventChannel

/**
 * Streams location updates to Dart while Dart is listening.
 *
 * Dart listen -> [onListen] starts updates. Dart cancel -> [onCancel] stops them.
 * Problems are sent with `events.error(...)`, never thrown: Flutter swallows
 * exceptions thrown from here, so Dart would never see them.
 */
class LocationStreamHandler(
    private val context: Context,
    private val fusedClient: FusedLocationProviderClient,
    private val permissionManager: PermissionManager,
) : EventChannel.StreamHandler {

    private var events: EventChannel.EventSink? = null
    private var callback: LocationCallback? = null

    // Permission is checked at the top of onListen(); lint can't see that.
    @SuppressLint("MissingPermission")
    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        // Never keep two registrations alive.
        stopUpdates()

        if (!permissionManager.hasAnyLocationPermission()) {
            events.error(
                permissionManager.permissionErrorCode(),
                "Location permission is not granted.",
                null,
            )
            return
        }
        if (!context.isLocationServiceEnabled()) {
            events.error(LocationErrorCodes.SERVICES_DISABLED, "Device location is turned off.", null)
            return
        }

        val args = arguments as? Map<*, *>
        val intervalMs = (args?.get(LocationArgs.INTERVAL_MS) as? Number)?.toLong()
            ?: DEFAULT_INTERVAL_MS
        val minDistanceMeters = (args?.get(LocationArgs.MIN_DISTANCE_METERS) as? Number)?.toFloat()
            ?: DEFAULT_MIN_DISTANCE_METERS

        val isPrecise = permissionManager.hasPreciseLocationPermission()
        val request = LocationRequest.Builder(
            if (isPrecise) Priority.PRIORITY_HIGH_ACCURACY
            else Priority.PRIORITY_BALANCED_POWER_ACCURACY,
            intervalMs,
        )
            .setMinUpdateIntervalMillis(intervalMs / 2)
            .setMinUpdateDistanceMeters(minDistanceMeters)
            .build()

        val newCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                val location = result.lastLocation ?: return
                this@LocationStreamHandler.events?.success(location.toChannelMap(isPrecise))
            }

            override fun onLocationAvailability(availability: LocationAvailability) {
                // "Unavailable" also happens indoors; only report it when the
                // Location switch is really off. Updates resume when it's back on.
                if (!availability.isLocationAvailable && !context.isLocationServiceEnabled()) {
                    this@LocationStreamHandler.events?.error(
                        LocationErrorCodes.SERVICES_DISABLED,
                        "Device location is turned off.",
                        null,
                    )
                }
            }
        }

        this.events = events
        callback = newCallback
        try {
            fusedClient.requestLocationUpdates(request, newCallback, Looper.getMainLooper())
            Log.i(TAG, "updates STARTED (every ${intervalMs}ms, min ${minDistanceMeters}m)")
        } catch (error: SecurityException) {
            stopUpdates()
            events.error(permissionManager.permissionErrorCode(), error.message, null)
        }
    }

    override fun onCancel(arguments: Any?) {
        stopUpdates()
    }

    /** Safe to call any number of times, from any lifecycle hook. */
    fun stopUpdates() {
        val currentCallback = callback ?: return
        fusedClient.removeLocationUpdates(currentCallback)
        callback = null
        events = null
        Log.i(TAG, "updates STOPPED")
    }

    private companion object {
        const val TAG = "GariPathLocation"
        const val DEFAULT_INTERVAL_MS = 2_000L
        const val DEFAULT_MIN_DISTANCE_METERS = 5f
    }
}
