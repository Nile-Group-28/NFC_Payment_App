package com.example.tappay

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var tapEventSink: EventChannel.EventSink? = null

    private val tapReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == TapPayHceService.ACTION_TAP_COMPLETE) {
                tapEventSink?.success("tap_complete")
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Method channel: Flutter sets/clears the HCE payment token
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HCE_METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                val prefs = getSharedPreferences(TapPayHceService.PREFS_NAME, MODE_PRIVATE)
                when (call.method) {
                    "setToken" -> {
                        val token = call.arguments as? String
                        if (token != null) {
                            prefs.edit().putString(TapPayHceService.TOKEN_KEY, token).apply()
                            result.success(null)
                        } else {
                            result.error("INVALID_ARG", "Token must be a String", null)
                        }
                    }
                    "clearToken" -> {
                        prefs.edit().remove(TapPayHceService.TOKEN_KEY).apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Event channel: notifies Flutter when the HCE tap is complete
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, HCE_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
                    tapEventSink = eventSink
                    registerReceiver(
                        tapReceiver,
                        IntentFilter(TapPayHceService.ACTION_TAP_COMPLETE)
                    )
                }

                override fun onCancel(arguments: Any?) {
                    tapEventSink = null
                    try { unregisterReceiver(tapReceiver) } catch (_: Exception) {}
                }
            })
    }

    companion object {
        const val HCE_METHOD_CHANNEL = "com.example.tappay/hce"
        const val HCE_EVENT_CHANNEL  = "com.example.tappay/hce_events"
    }
}
