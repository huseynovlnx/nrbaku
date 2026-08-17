package com.example.private_couple_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Telefon yenidən başladılandan sonra bütün saxlanılan xatırladıcı
 * alarmlarını yenidən qurur (Android reboot-da AlarmManager-i təmizləyir). */
class ReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        ReminderScheduler.rescheduleAllFromPrefs(context)
    }
}
