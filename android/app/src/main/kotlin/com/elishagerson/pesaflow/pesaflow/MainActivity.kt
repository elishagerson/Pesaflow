package com.elishagerson.pesaflow.pesaflow

import android.Manifest
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "pesaflow/notification_listener"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        // Expose the channel so SmsNotificationListener can use it
        SmsNotificationListener.methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPostNotifications" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                            1001
                        )
                    }
                    result.success(true)
                }
                "getPendingSms" -> {
                    val pending = getPendingSms()
                    result.success(pending)
                }
                "clearPendingSms" -> {
                    clearPendingSms()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getPendingSms(): List<String> {
        val prefs: SharedPreferences = getSharedPreferences("pesaflow_pending_sms", MODE_PRIVATE)
        val raw = prefs.getString("pending_sms_list", "[]") ?: "[]"
        val arr = JSONArray(raw)
        val list = mutableListOf<String>()
        for (i in 0 until arr.length()) {
            list.add(arr.getJSONObject(i).toString())
        }
        return list
    }

    private fun clearPendingSms() {
        val prefs: SharedPreferences = getSharedPreferences("pesaflow_pending_sms", MODE_PRIVATE)
        prefs.edit().putString("pending_sms_list", "[]").apply()
    }
}
