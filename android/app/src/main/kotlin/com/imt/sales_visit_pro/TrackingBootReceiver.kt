package com.imt.sales_visit_pro

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/// Restarts the Flutter background tracking service after reboot when a session is still open.
class TrackingBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != "android.intent.action.QUICKBOOT_POWERON"
        ) {
            return
        }

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val sessionId = prefs.getString("flutter.tracking_session_id", null)
        if (sessionId.isNullOrBlank()) return

        try {
            val serviceClass = Class.forName(
                "id.flutter.flutter_background_service.BackgroundService"
            )
            val serviceIntent = Intent(context, serviceClass)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.i(TAG, "Restarted tracking service for open session")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restart tracking service", e)
        }
    }

    companion object {
        private const val TAG = "TrackingBootReceiver"
    }
}
