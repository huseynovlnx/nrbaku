package com.example.private_couple_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions

/**
 * Tətbiq bağlı/arxa planda olsa belə yerin davamlı (~2-3 dəqiqədə bir)
 * güncəllənməsini təmin edən Foreground Service.
 *
 * QEYD (dəyişdirilə bilməz): Android, arxa planda yer izləyən hər tətbiqin
 * bildiriş panelində davamlı, gizlədilməyən bir bildiriş göstərməsini
 * MƏCBURİ edir (əməliyyat sisteminin özünün təhlükəsizlik siyasətidir,
 * "gizli GPS izləmə"nin qarşısını almaq üçün). Bunu ən aşağı görünürlüyə
 * (IMPORTANCE_MIN, səssiz, "NrBaku — Yer paylaşımı aktivdir") endirmişik —
 * bundan artıq gizlədilə bilməz.
 */
class LocationTrackingService : Service() {

    companion object {
        const val CHANNEL_ID = "location_tracking_silent"
        const val NOTIF_ID = 9001
        const val ACTION_STOP = "com.example.private_couple_app.action.STOP_LOCATION"
        const val PREFS_NAME = "location_tracking_prefs"
        const val PREF_ENABLED = "enabled"

        /** Boot sonrası xidməti yenidən başlatmaq lazımdırmı — istifadəçi
         * özü söndürübsə (STOP) yenidən avtomatik başlamasın deyə. */
        fun isEnabled(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getBoolean(PREF_ENABLED, false)
        }

        private fun setEnabledPref(context: Context, value: Boolean) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit().putBoolean(PREF_ENABLED, value).apply()
        }
    }

    private lateinit var fusedClient: FusedLocationProviderClient
    private var callback: LocationCallback? = null

    override fun onCreate() {
        super.onCreate()
        if (FirebaseApp.getApps(this).isEmpty()) FirebaseApp.initializeApp(this)
        fusedClient = LocationServices.getFusedLocationProviderClient(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            setEnabledPref(this, false)
            stopLocationUpdates()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        setEnabledPref(this, true)
        ensureChannel()
        startForeground(NOTIF_ID, buildNotification())
        startLocationUpdates()
        return START_STICKY
    }

    private fun startLocationUpdates() {
        stopLocationUpdates()
        // Balanslı: ~2-3 dəqiqədə bir güncəllənmə (batareya ilə dəqiqlik
        // arasında razılaşdırılmış tarazlıq).
        val request = LocationRequest.Builder(
            Priority.PRIORITY_BALANCED_POWER_ACCURACY, 150_000L // 2.5 dəqiqə
        )
            .setMinUpdateIntervalMillis(120_000L) // heç olmasa 2 dəqiqə ara ver
            .build()

        callback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                val loc = result.lastLocation ?: return
                writeLocation(loc.latitude, loc.longitude)
            }
        }
        try {
            fusedClient.requestLocationUpdates(request, callback!!, Looper.getMainLooper())
        } catch (_: SecurityException) {
            // İcazə geri götürülübsə sükutla dayan — UI tərəf öz vəziyyətini
            // növbəti "Ayarlar" yoxlamasında görəcək.
        }
    }

    private fun stopLocationUpdates() {
        callback?.let { fusedClient.removeLocationUpdates(it) }
        callback = null
    }

    private fun writeLocation(lat: Double, lng: Double) {
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        val db = FirebaseFirestore.getInstance()
        val now = System.currentTimeMillis()

        // 1) Canlı mövqe — locations/{uid} (mövcud, partner xəritəsi üçün)
        db.collection("locations").document(uid).set(
            hashMapOf("lat" to lat, "lng" to lng, "updatedAt" to FieldValue.serverTimestamp()),
            SetOptions.merge()
        )

        // 2) Admin paneli üçün — devices/{uid} canlı mövqe yeniləməsi
        db.collection("devices").document(uid).set(
            hashMapOf("lat" to lat, "lng" to lng, "updatedAt" to FieldValue.serverTimestamp()),
            SetOptions.merge()
        )

        // 3) 24 saatlıq marşrut tarixçəsi — devices/{uid}/route/{tarix}
        // "points" massivinin sonuna yeni koordinat əlavə edir.
        // Əvvəlki günün sənədi avtomatik olaraq silinmir — əgər lazımsa,
        // Cloudflare Worker cron-u genişləndirilə bilər.
        val dateStr = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault())
            .format(java.util.Date(now))
        val point = hashMapOf(
            "lat" to lat,
            "lng" to lng,
            "ts" to now,
        )
        db.collection("devices").document(uid)
            .collection("route").document(dateStr)
            .update("points", FieldValue.arrayUnion(point))
            .addOnFailureListener {
                // Sənəd hələ yoxdursa (gün əvvəlindəki ilk yazı) yenisini yarat
                db.collection("devices").document(uid)
                    .collection("route").document(dateStr)
                    .set(hashMapOf("points" to arrayListOf(point)))
            }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID, "Yer paylaşımı (arxa plan)", NotificationManager.IMPORTANCE_MIN
        ).apply {
            description = "NrBaku arxa planda partnerinizlə yer paylaşımını davam etdirir"
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        nm.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("NrBaku")
            .setContentText("Yer paylaşımı aktivdir")
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setSilent(true)
            .setShowWhen(false)
            .build()
    }

    override fun onDestroy() {
        stopLocationUpdates()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
