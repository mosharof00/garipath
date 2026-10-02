package com.mosharof.garipath.location

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel

/**
 * Our own location plugin, living inside the app module.
 *
 * Being a FlutterPlugin + ActivityAware gives us clear lifecycle hooks: when the
 * engine or the Activity goes away we know exactly where to clean up.
 */
class GariPathLocationPlugin : FlutterPlugin, ActivityAware {

    private var methodChannel: MethodChannel? = null
    private var methodHandler: LocationMethodHandler? = null
    private var permissionManager: PermissionManager? = null
    private var activityBinding: ActivityPluginBinding? = null

    // Engine lifecycle

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext
        val permissions = PermissionManager(context)
        val handler = LocationMethodHandler(context, permissions)

        methodChannel = MethodChannel(binding.binaryMessenger, LocationChannels.METHOD)
        methodChannel?.setMethodCallHandler(handler)
        methodHandler = handler
        permissionManager = permissions
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        methodHandler = null
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
        detachFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        // A new Activity instance: the listener must be registered again.
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
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
