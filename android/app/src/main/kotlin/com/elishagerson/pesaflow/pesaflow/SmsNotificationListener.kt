package com.elishagerson.pesaflow.pesaflow

import android.app.Notification
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class SmsNotificationListener : NotificationListenerService() {

    companion object {
        private const val TAG = "SmsNotifListener"
        var methodChannel: MethodChannel? = null
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "Notification listener connected successfully")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.w(TAG, "Notification listener disconnected")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        Log.d(TAG, "onNotificationPosted: pkg=${sbn.packageName} key=${sbn.key}")

        if (sbn.isOccluded) {
            Log.d(TAG, "Notification is occluded — skipping")
        }

        val extras = sbn.notification.extras ?: return

        // SMS apps typically put the sender in EXTRA_TITLE and the body in EXTRA_TEXT
        val title = extras.getString(Notification.EXTRA_TITLE, "") ?: ""
        val text = extras.getString(Notification.EXTRA_TEXT, "") ?: ""
        val bigText = extras.getString(Notification.EXTRA_BIG_TEXT, "") ?: ""
        val fullBody = if (bigText.isNotEmpty()) bigText else text

        Log.d(TAG, "Notification: title='$title' body='${fullBody.take(100)}'")

        // Filter: only process SMS-like notifications containing financial keywords
        if (!isLikelyFinancialSms(title, fullBody)) return

        Log.d(TAG, "Matched financial SMS notification")

        val json = JSONObject().apply {
            put("sender", title)
            put("body", fullBody)
            put("package", sbn.packageName)
            put("timestamp", System.currentTimeMillis())
        }

        // If Flutter is alive, forward immediately via MethodChannel on the UI main thread
        val channel = methodChannel
        if (channel != null) {
            Handler(Looper.getMainLooper()).post {
                try {
                    channel.invokeMethod("onSmsNotification", json.toString())
                    Log.d(TAG, "Forwarded SMS notification to Flutter")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to forward SMS notification: ${e.message}")
                }
            }
        } else {
            Log.d(TAG, "MethodChannel null — persisted for later retrieval")
        }

        // Always persist to SharedPreferences for startup recovery
        persistPendingSms(json.toString())
    }

    private fun isLikelyFinancialSms(sender: String, body: String): Boolean {
        val combined = "$sender $body"
        val keywords = listOf(
            "Tsh", "TZS", "sent", "received", "M-PESA", "M-Pesa", "Mixx",
            "Selcom", "NMB", "CRDB", "transaction", "balance",
            // Swahili keywords for backward compatibility
            "umetuma", "umepokea", "malipo", "kwa", "shilingi",
        )
        return keywords.any { combined.contains(it, ignoreCase = true) }
    }

    private fun persistPendingSms(json: String) {
        try {
            val prefs: SharedPreferences = getSharedPreferences("pesaflow_pending_sms", MODE_PRIVATE)
            val existing = prefs.getString("pending_sms_list", "[]") ?: "[]"
            val arr = JSONArray(existing)
            arr.put(JSONObject(json))
            prefs.edit().putString("pending_sms_list", arr.toString()).apply()
        } catch (_: Exception) {
            // Silently ignore persistence failures — non-critical
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // No cleanup needed
    }
}
