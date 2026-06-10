package com.elishagerson.pesaflow.pesaflow

import android.app.Notification
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
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

        val extras = sbn.notification.extras ?: return
        val sender = extractSender(extras)
        val body = extractBody(extras)

        if (sender == null && body == null) {
            logExtras(extras)
            return
        }

        val fullBody = body ?: ""
        val fullSender = sender ?: ""

        Log.d(TAG, "Notification: sender='$fullSender' body='${fullBody.take(150)}'")

        if (!isLikelyFinancialSms(fullSender, fullBody, sbn.packageName)) return

        Log.d(TAG, "Matched financial SMS notification")

        val json = JSONObject().apply {
            put("sender", fullSender)
            put("body", fullBody)
            put("package", sbn.packageName)
            put("timestamp", System.currentTimeMillis())
        }

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

        persistPendingSms(json.toString())
    }

    private fun extractSender(extras: Bundle): String? {
        // Try conversation title first (Android 11+ messaging style)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val convTitle = extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)?.toString()
            if (!convTitle.isNullOrBlank()) return convTitle.trim()
        }

        // Try Android 14+ conversation title key
        val convTitleLegacy = extras.getCharSequence("android.conversationTitle")?.toString()
        if (!convTitleLegacy.isNullOrBlank()) return convTitleLegacy.trim()

        // Try extra title
        val title = extras.getString(Notification.EXTRA_TITLE)
        if (!title.isNullOrBlank()) return title.trim()

        // Try SUB_TEXT (sometimes carries sender info)
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()
        if (!subText.isNullOrBlank()) return subText.trim()

        return null
    }

    private fun extractBody(extras: Bundle): String? {
        // Try messages list first (Android 7+ messaging style with multiple messages)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
            if (messages != null && messages.isNotEmpty()) {
                val sb = StringBuilder()
                for (msg in messages) {
                    // Each message is a Bundle or CharSequence
                    val text = when (msg) {
                        is Bundle -> msg.getCharSequence("text")?.toString()
                        is CharSequence -> msg.toString()
                        else -> null
                    }
                    if (!text.isNullOrBlank()) {
                        if (sb.isNotEmpty()) sb.append("\n")
                        sb.append(text)
                    }
                }
                if (sb.isNotEmpty()) return sb.toString()
            }
        }

        // Try big text (expanded notification view)
        val bigText = extras.getString(Notification.EXTRA_BIG_TEXT)
        if (!bigText.isNullOrBlank()) return bigText.trim()

        // Try standard text
        val text = extras.getString(Notification.EXTRA_TEXT)
        if (!text.isNullOrBlank()) return text.trim()

        // Try sub text as fallback
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()
        if (!subText.isNullOrBlank()) return subText.trim()

        // Try Android 14+ text key variations
        val title = extras.getString(Notification.EXTRA_TITLE)
        if (!title.isNullOrBlank()) return title.trim()

        return null
    }

    private fun isLikelyFinancialSms(sender: String, body: String, packageName: String): Boolean {
        val combined = "$sender $body"

        // Known financial SMS sender packages
        val knownPackages = listOf(
            "com.android.mms",
            "com.android.messaging",
            "com.google.android.apps.messaging",
            "com.samsung.android.messaging",
        )

        // Also process notifications from financial apps directly
        val financialPackages = listOf(
            "com.mpesa",
            "com.crdb",
            "com.nmb",
            "com.selcom",
            "com.airtel",
            "com.tigo",
        )

        if (financialPackages.any { packageName.contains(it, ignoreCase = true) }) {
            return true
        }

        val keywords = listOf(
            "Tsh", "TZS", "sent", "received", "M-PESA", "M-Pesa", "Mixx",
            "Selcom", "NMB", "CRDB", "transaction", "balance",
            "umetuma", "umepokea", "malipo", "kwa", "shilingi",
            "deposited", "withdrawn", "payment", "transfer",
            "airtime", "utility", "bought", "paid",
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

    private fun logExtras(extras: Bundle) {
        try {
            val keys = extras.keySet()
            val details = keys.joinToString(", ") { key ->
                val value = when (val v = extras.get(key)) {
                    is String -> "\"$v\""
                    is Array<*> -> "[${v.size}]"
                    else -> v?.toString()?.take(80) ?: "null"
                }
                "$key=$value"
            }
            Log.d(TAG, "Extras keys: $details")
        } catch (_: Exception) {}
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // No cleanup needed
    }
}
