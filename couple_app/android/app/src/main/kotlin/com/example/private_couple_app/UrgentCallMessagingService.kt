package com.example.private_couple_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * "Təcili Çağırış" (type=urgent_call) data-only FCM mesajlarını NATIVE
 * tərəfdə tutub, birbaşa tam ekran bildirişi göstərir.
 */
class UrgentCallMessagingService : FirebaseMessagingService() {

    companion object {
        const val CHANNEL_ID = "urgent_call_native"
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        val data = remoteMessage.data
        if (data["type"] == "urgent_call") {
            showFullScreenCall(data)
        }
    }

    private fun showFullScreenCall(data: Map<String, String>) {
        val callId = data["callId"] ?: return
        val pairId = data["pairId"] ?: return
        val fromName = data["fromName"] ?: "Partner"
        val message = data["message"] ?: ""
        val notifId = callId.hashCode()

        ensureChannel()

        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
            putExtra("urgent_call_id", callId)
            putExtra("urgent_call_pairId", pairId)
            putExtra("urgent_call_fromName", fromName)
            putExtra("urgent_call_message", message)
        }
        
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this, notifId, fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val respondIntent = Intent(this, UrgentCallResponseReceiver::class.java).apply {
            action = UrgentCallResponseReceiver.ACTION_RESPOND
            putExtra("callId", callId)
            putExtra("pairId", pairId)
            putExtra("notificationId", notifId)
            putExtra("fromUid", data["fromUid"])
        }
        val respondPendingIntent = PendingIntent.getBroadcast(
            this, notifId + 1, respondIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val soundUri = urgentAlarmUri()

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("🚨 $fromName")
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(fullScreenPendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setLights(0xFFB3261E.toInt(), 500, 500)
            .addAction(0, "✓ Cavab verdim", respondPendingIntent)

        if (soundUri != null && Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            builder.setSound(soundUri)
        }

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(notifId, builder.build())
    }

    private fun urgentAlarmUri(): Uri? {
        return try {
            Uri.parse("android.resource://$packageName/raw/urgent_alarm")
        } catch (_: Exception) {
            null
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            CHANNEL_ID, "Təcili Çağırış", NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Partnerdən təcili diqqət tələb edən çağırışlar"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 800, 400, 800, 400, 800, 400, 800)
            lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            // Yalnız icazə (ACCESS_NOTIFICATION_POLICY) kifayət deyil —
            // hər kanal özü açıq şəkildə DND-ni keçməyi bildirməlidir.
            setBypassDnd(true)

            val soundUri = urgentAlarmUri()
            if (soundUri != null) {
                val audioAttrs = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                setSound(soundUri, audioAttrs)
            }
        }
        nm.createNotificationChannel(channel)
    }
}