package com.example.private_couple_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat

/**
 * `AlarmManager.setAlarmClock()` tetiklənəndə işə düşür. Telefonun daxili
 * Alarm tətbiqi kimi — yüksək prioritetli, səsli, tam-ekrana çıxa bilən
 * bildiriş göstərir.
 */
class ReminderAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val CHANNEL_ID = "reminder_alarm_native"
        const val EXTRA_ID = "reminder_id"
        const val EXTRA_TITLE = "reminder_title"
        const val EXTRA_BODY = "reminder_body"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(EXTRA_ID, 0)
        val title = intent.getStringExtra(EXTRA_TITLE) ?: "Xatırladıcı"
        val body = intent.getStringExtra(EXTRA_BODY) ?: ""

        ensureChannel(context)

        val dismissIntent = Intent(context, ReminderDismissReceiver::class.java).apply {
            putExtra(EXTRA_ID, id)
        }
        val dismissPendingIntent = PendingIntent.getBroadcast(
            context, id, dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            // SOS ilə eyni "ekranı oyat" mexanizmini işə salmaq üçün
            // MainActivity-nin tanıdığı əlavəni göndəririk.
            putExtra("reminder_alarm_id", id)
        }
        val openPendingIntent = PendingIntent.getActivity(
            context, id, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle("⏰ $title")
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setFullScreenIntent(openPendingIntent, true)
            .setContentIntent(openPendingIntent)
            .setAutoCancel(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .addAction(0, "Bağla", dismissPendingIntent)

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            urgentAlarmUri(context)?.let { builder.setSound(it) }
        }

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(id, builder.build())

        // Təkrarlanandırsa gələn ilə köçür, deyilsə siyahıdan sil
        ReminderScheduler.rescheduleIfRecurring(context, id)
    }

    private fun urgentAlarmUri(context: Context): Uri? = try {
        Uri.parse("android.resource://${context.packageName}/raw/urgent_alarm")
    } catch (_: Exception) {
        null
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            CHANNEL_ID, "Xatırladıcı Alarmı", NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Plan/xatırladıcı vaxtı gələndə"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 500, 250, 500)
            lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            // Yalnız icazə (ACCESS_NOTIFICATION_POLICY) kifayət deyil —
            // hər kanal özü açıq şəkildə DND-ni keçməyi bildirməlidir
            // (SOS kanalında da eyni düzəliş edilib).
            setBypassDnd(true)
            urgentAlarmUri(context)?.let { uri ->
                val attrs = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                setSound(uri, attrs)
            }
        }
        nm.createNotificationChannel(channel)
    }
}
