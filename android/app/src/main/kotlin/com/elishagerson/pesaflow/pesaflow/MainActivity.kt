package com.elishagerson.pesaflow.pesaflow

import android.Manifest
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
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
                "isNotificationListenerEnabled" -> {
                    result.success(isNotificationListenerEnabled())
                }
                "openNotificationListenerSettings" -> {
                    openNotificationListenerSettings()
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

    private fun isNotificationListenerEnabled(): Boolean {
        // Settings.Secure is the most reliable check across all Android versions.
        // NotificationManagerCompat.getEnabledListenerPackages() has known
        // inconsistencies on newer Android/beta releases.
        val flat = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        )
        return flat != null && flat.contains(packageName)
    }

    private fun openNotificationListenerSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        if (intent.resolveActivity(packageManager) != null) {
            startActivity(intent)
        }
    }

    private fun getPendingSms(): List<String> {
        return try {
            val prefs: SharedPreferences = getSharedPreferences("pesaflow_pending_sms", MODE_PRIVATE)
            val raw = prefs.getString("pending_sms_list", "[]") ?: "[]"
            val arr = JSONArray(raw)
            val list = mutableListOf<String>()
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i)
                if (obj != null) list.add(obj.toString())
            }
            list
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun clearPendingSms() {
        val prefs: SharedPreferences = getSharedPreferences("pesaflow_pending_sms", MODE_PRIVATE)
        prefs.edit().putString("pending_sms_list", "[]").apply()
    }

    override fun onDestroy() {
        SmsNotificationListener.methodChannel = null
        super.onDestroy()
    }
}
