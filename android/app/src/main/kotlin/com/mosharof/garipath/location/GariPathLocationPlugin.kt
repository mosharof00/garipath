package com.mosharof.garipath.location

import com.google.android.gms.location.LocationServices
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Our own location plugin, living inside the app module.
 *
 * Being a FlutterPlugin + ActivityAware gives us clear lifecycle hooks: when the
 * engine or the Activity goes away we know exactly where to clean up.
 */
class GariPathLocationPlugin : FlutterPlugin, ActivityAware {

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var methodHandler: LocationMethodHandler? = null
    private var streamHandler: LocationStreamHandler? = null
    private var permissionManager: PermissionManager? = null
    private var activityBinding: ActivityPluginBinding? = null

    // Engine lifecycle

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext
        val fusedClient = LocationServices.getFusedLocationProviderClient(context)
        val permissions = PermissionManager(context)
        val methods = LocationMethodHandler(context, fusedClient, permissions)
        val stream = LocationStreamHandler(context, fusedClient, permissions)

        methodChannel = MethodChannel(binding.binaryMessenger, LocationChannels.METHOD)
        methodChannel?.setMethodCallHandler(methods)
        eventChannel = EventChannel(binding.binaryMessenger, LocationChannels.EVENTS)
        eventChannel?.setStreamHandler(stream)

        permissionManager = permissions
        methodHandler = methods
        streamHandler = stream
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        streamHandler?.stopUpdates()
        permissionManager?.cancelPendingRequest()

        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
        methodHandler = null
        streamHandler = null
        permissionManager = null
    }

    // Activity lifecycle

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        methodHandler?.activity = binding.activity
        permissionManager?.let { manager ->
            manager.activity = binding.activity
            // The permission dialog answer is delivered to the Activity;
            // this forwards it to our PermissionManager.
            binding.addRequestPermissionsResultListener(manager)
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        // The Activity is only being recreated (e.g. dark mode switch). Dart is
        // still listening and a showing dialog will answer the new Activity,
        // so the stream and the pending request stay alive.
        detachFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        // A new Activity instance: the listener must be registered again.
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        // The screen is really gone: release everything tied to it.
        streamHandler?.stopUpdates()
        permissionManager?.cancelPendingRequest()
        detachFromActivity()
    }

    private fun detachFromActivity() {
        permissionManager?.let { manager ->
            activityBinding?.removeRequestPermissionsResultListener(manager)
            manager.activity = null
        }
        methodHandler?.activity = null
        activityBinding = null
    }
}
