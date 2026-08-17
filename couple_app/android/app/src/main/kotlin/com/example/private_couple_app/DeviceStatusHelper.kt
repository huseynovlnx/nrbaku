package com.example.private_couple_app

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build

/**
 * Cihaz vəziyyəti məlumatlarını (batareya, WiFi) toplamaq üçün
 * köməkçi. MainActivity-nin method channel handler-indən çağrılır.
 * Heç bir əlavə icazə tələb etmir — bu API-lər ictimai (public)
 * Android API-ləridir.
 */
object DeviceStatusHelper {

    fun getStatus(context: Context): Map<String, Any?> {
        val battery = getBatteryInfo(context)
        val wifi = getWifiInfo(context)
        return mapOf(
            "batteryLevel" to battery.first,
            "isCharging" to battery.second,
            "isWifi" to wifi.first,
            "wifiName" to wifi.second,
        )
    }

    private fun getBatteryInfo(context: Context): Pair<Int, Boolean> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val bm = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            val isCharging = bm.isCharging
            Pair(level, isCharging)
        } else {
            @Suppress("DEPRECATION")
            val intent = context.registerReceiver(
                null,
                IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            )
            val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
            val pct = if (scale > 0) (level * 100 / scale) else -1
            val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                           status == BatteryManager.BATTERY_STATUS_FULL
            Pair(pct, charging)
        }
    }

    private fun getWifiInfo(context: Context): Pair<Boolean, String?> {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = cm.activeNetwork ?: return Pair(false, null)
        val caps = cm.getNetworkCapabilities(network) ?: return Pair(false, null)
        val isWifi = caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
        return Pair(isWifi, null) // WiFi adı READ_PRECISE_PHONE_STATE tələb edir — icazəsiz saxladıq
    }
}
