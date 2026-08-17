package com.example.private_couple_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Telefon yenidən başladılandan sonra, yalnız istifadəçi əvvəllər yer
 * paylaşımını AKTİV saxlamışdısa, xidməti avtomatik yenidən başladır.
 * (İstifadəçi özü söndürübsə, boot sonrası da söndürülmüş qalır.)
 */
class LocationBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        if (!LocationTrackingService.isEnabled(context)) return

        val serviceIntent = Intent(context, LocationTrackingService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
