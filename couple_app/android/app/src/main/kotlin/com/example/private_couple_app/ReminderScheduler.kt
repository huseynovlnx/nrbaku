package com.example.private_couple_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import org.json.JSONObject
import java.util.Calendar

/**
 * Xatırladıcıları `AlarmManager.setAlarmClock()` ilə planlaşdıran ortaq
 * köməkçi. Bu API telefonun daxili Saat/Alarm tətbiqinin istifadə etdiyi
 * EYNİ mexanizmdir — heç bir icazə tələb etmir, Doze/App Standby-dan
 * tam müstəsnadır (sistem heç vaxt gecikdirmir və ya ləğv etmir).
 *
 * SharedPreferences-də saxlanılan JSON siyahı reboot sonrası (Android
 * bütün AlarmManager alarmlarını silir) yenidən qurmaq üçündür — bax:
 * [ReminderBootReceiver].
 */
object ReminderScheduler {
    private const val PREFS_NAME = "reminder_alarms"
    private const val KEY_ITEMS = "items" // JSON array string

    fun schedule(
        context: Context,
        id: Int,
        title: String,
        body: String,
        timestampMillis: Long,
        recurringYearly: Boolean,
    ) {
        saveToPrefs(context, id, title, body, timestampMillis, recurringYearly)
        armAlarm(context, id, title, body, timestampMillis)
    }

    fun cancel(context: Context, id: Int) {
        removeFromPrefs(context, id)
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val operationIntent = Intent(context, ReminderAlarmReceiver::class.java)
        val pi = PendingIntent.getBroadcast(
            context, id, operationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        am.cancel(pi)
        pi.cancel()
    }

    /**
     * Dart-dan gələn CARI (hazırkı) xatırladıcı siyahısı ilə bu cihazda
     * ARTIQ qurulmuş alarmları müqayisə edir:
     * - Siyahıda olan hər şeyi planlaşdırır/yeniləyir
     * - Siyahıda OLMAYAN (yəni silinmiş və ya partnerin başqa cihazda
     *   sildiyi) hər hansı qurulu alarmı LƏĞV edir.
     * Bu, "partnerin telefonunda silinmiş xatırladıcı hələ də qurulu qalır"
     * problemini həll edir — çünki hər cihaz alarmı özü, lokal qurur, silmə
     * əməliyyatı da hər cihaza öz-özünə "çatmalıdır".
     */
    fun syncAll(
        context: Context,
        items: List<Map<String, Any?>>,
    ) {
        val desiredIds = items.mapNotNull { (it["id"] as? Number)?.toInt() }.toSet()
        val currentIds = readPrefs(context).keys().asSequence()
            .mapNotNull { it.toIntOrNull() }
            .toSet()

        // Artıq siyahıda olmayanları ləğv et (silinmiş/başqa cihazda silinmiş)
        for (staleId in currentIds - desiredIds) {
            cancel(context, staleId)
        }

        // Qalanları planlaşdır/yenilə
        for (item in items) {
            val id = (item["id"] as? Number)?.toInt() ?: continue
            val title = item["title"] as? String ?: continue
            val body = item["body"] as? String ?: ""
            val timestamp = (item["timestampMillis"] as? Number)?.toLong() ?: continue
            val recurring = item["recurringYearly"] as? Boolean ?: false
            schedule(context, id, title, body, timestamp, recurring)
        }
    }

    /** Alarm atəşlədikdən sonra çağrılır: təkrarlanandırsa gələn ilə köçürür,
     * deyilsə siyahıdan silir. */
    fun rescheduleIfRecurring(context: Context, id: Int) {
        val items = readPrefs(context)
        val item = items.optJSONObject(id.toString()) ?: return
        val recurring = item.optBoolean("recurring", false)
        if (!recurring) {
            removeFromPrefs(context, id)
            return
        }
        val oldTs = item.optLong("timestamp")
        val cal = Calendar.getInstance().apply {
            timeInMillis = oldTs
            add(Calendar.YEAR, 1)
        }
        val title = item.optString("title")
        val body = item.optString("body")
        schedule(context, id, title, body, cal.timeInMillis, true)
    }

    /** Reboot sonrası bütün saxlanılan xatırladıcıları yenidən silahlandırır. */
    fun rescheduleAllFromPrefs(context: Context) {
        val items = readPrefs(context)
        val now = System.currentTimeMillis()
        val keys = items.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val item = items.optJSONObject(key) ?: continue
            var ts = item.optLong("timestamp")
            val recurring = item.optBoolean("recurring", false)
            val id = key.toIntOrNull() ?: continue

            if (ts < now) {
                if (!recurring) {
                    // Keçmişdə qalıb, təkrarlanmır — təmizlə
                    removeFromPrefs(context, id)
                    continue
                }
                // Təkrarlanandırsa, gələcək ən yaxın tarixə köçür
                val cal = Calendar.getInstance().apply { timeInMillis = ts }
                while (cal.timeInMillis < now) cal.add(Calendar.YEAR, 1)
                ts = cal.timeInMillis
            }
            armAlarm(context, id, item.optString("title"), item.optString("body"), ts)
        }
    }

    private fun armAlarm(
        context: Context,
        id: Int,
        title: String,
        body: String,
        timestampMillis: Long,
    ) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val operationIntent = Intent(context, ReminderAlarmReceiver::class.java).apply {
            putExtra(ReminderAlarmReceiver.EXTRA_ID, id)
            putExtra(ReminderAlarmReceiver.EXTRA_TITLE, title)
            putExtra(ReminderAlarmReceiver.EXTRA_BODY, body)
        }
        val operationPendingIntent = PendingIntent.getBroadcast(
            context, id, operationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val showIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val showPendingIntent = PendingIntent.getActivity(
            context, id, showIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        am.setAlarmClock(
            AlarmManager.AlarmClockInfo(timestampMillis, showPendingIntent),
            operationPendingIntent
        )
    }

    private fun saveToPrefs(
        context: Context,
        id: Int,
        title: String,
        body: String,
        timestampMillis: Long,
        recurring: Boolean,
    ) {
        val items = readPrefs(context)
        val obj = JSONObject().apply {
            put("title", title)
            put("body", body)
            put("timestamp", timestampMillis)
            put("recurring", recurring)
        }
        items.put(id.toString(), obj)
        writePrefs(context, items)
    }

    private fun removeFromPrefs(context: Context, id: Int) {
        val items = readPrefs(context)
        items.remove(id.toString())
        writePrefs(context, items)
    }

    private fun readPrefs(context: Context): JSONObject {
        val raw = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_ITEMS, null) ?: return JSONObject()
        return try {
            JSONObject(raw)
        } catch (_: Exception) {
            JSONObject()
        }
    }

    private fun writePrefs(context: Context, items: JSONObject) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_ITEMS, items.toString())
            .apply()
    }
}

private fun String.toIntOrNull(): Int? = try {
    this.toInt()
} catch (_: NumberFormatException) {
    null
}
