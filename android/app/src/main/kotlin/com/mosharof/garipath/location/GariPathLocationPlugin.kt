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

    // Engine lifecycle

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext
        val handler = LocationMethodHandler(context, PermissionManager(context))

        methodChannel = MethodChannel(binding.binaryMessenger, LocationChannels.METHOD)
        methodChannel?.setMethodCallHandler(handler)
        methodHandler = handler
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        methodHandler = null
    }

    // Activity lifecycle

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        methodHandler?.activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        methodHandler?.activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        methodHandler?.activity = null
    }
}
