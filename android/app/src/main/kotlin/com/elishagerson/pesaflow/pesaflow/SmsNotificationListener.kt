package com.elishagerson.pesaflow.pesaflow

import android.app.Notification
import android.content.SharedPreferences
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class SmsNotificationListener : NotificationListenerService() {

    companion object {
        var methodChannel: MethodChannel? = null
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val extras = sbn.notification.extras

        // SMS apps typically put the sender in EXTRA_TITLE and the body in EXTRA_TEXT
        val title = extras.getString(Notification.EXTRA_TITLE, "") ?: ""
        val text = extras.getString(Notification.EXTRA_TEXT, "") ?: ""
        val bigText = extras.getString(Notification.EXTRA_BIG_TEXT, "") ?: ""
        val fullBody = if (bigText.isNotEmpty()) bigText else text

        // Filter: only process SMS-like notifications containing financial keywords
        if (!isLikelyFinancialSms(title, fullBody)) return

        val json = JSONObject().apply {
            put("sender", title)
            put("body", fullBody)
            put("package", sbn.packageName)
            put("timestamp", System.currentTimeMillis())
        }

        // If Flutter is alive, forward immediately via MethodChannel
        methodChannel?.invokeMethod("onSmsNotification", json.toString())

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
