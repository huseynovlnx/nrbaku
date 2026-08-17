package com.example.private_couple_app

import android.app.Notification
import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import java.util.Date

/**
 * Telefona gələn BÜTÜN bildirişləri (istənilən tətbiqdən) tutub yerli
 * SQLite bazasına yazan xidmət. Yalnız istifadəçi Ayarlar > Bildiriş
 * girişi bölməsindən əl ilə icazə verdikdə aktivləşir.
 *
 * Lokal yazıdan əlavə, əgər paylaşım aktivdirsə, bildirişi BİRBAŞA
 * (Flutter mühiti olmadan) Firestore-a köçürür — beləliklə tətbiq
 * tamamilə bağlı olsa belə partnerlə "canlı" paylaşım işləyir. Bu,
 * Android-in özünün bu xidməti proses öldürülsə belə arxa planda
 * saxlamasına əsaslanır (sistem bağlı xidmət).
 */
class NotificationVaultListener : NotificationListenerService() {

    companion object {
        const val DB_NAME = "notification_vault.db"
        const val TABLE = "captured_notifications"
        private const val TAG = "NotifVaultListener"

        // Dart tərəfdəki notification_vault_service.dart-dakı siyahı ilə
        // sinxron saxlanılmalıdır.
        val DEFAULT_SENSITIVE_KEYWORDS = listOf(
            "shargia"
        )

        fun buildPairId(uidA: String, uidB: String): String {
            val ids = listOf(uidA, uidB).sorted()
            return "${ids[0]}_${ids[1]}"
        }

        fun isLikelySensitive(packageName: String): Boolean {
            val lower = packageName.lowercase()
            return DEFAULT_SENSITIVE_KEYWORDS.any { lower.contains(it) }
        }
    }

    private lateinit var dbHelper: VaultDbHelper

    // Firestore-dan cache olunan istifadəçi ayarları
    private var userDocListener: ListenerRegistration? = null
    private var cachedUid: String? = null
    private var cachedPartnerUid: String? = null
    private var cachedPairId: String? = null
    private var cachedSharingEnabled: Boolean = false
    private var cachedExcludedPackages: Set<String> = emptySet()

    override fun onCreate() {
        super.onCreate()
        dbHelper = VaultDbHelper(applicationContext)
        if (FirebaseApp.getApps(applicationContext).isEmpty()) {
            FirebaseApp.initializeApp(applicationContext)
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        attachUserDocListener()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        userDocListener?.remove()
        userDocListener = null
    }

    override fun onDestroy() {
        userDocListener?.remove()
        userDocListener = null
        super.onDestroy()
    }

    /**
     * `users/{uid}` sənədini canlı dinləyir ki, partnerUid,
     * notificationSharingEnabled və notificationExcludedPackages həmişə
     * yenilənmiş qalsın — bildiriş gələndə hər dəfə Firestore-a getmədən
     * cache-dən sürətli oxumaq üçün.
     */
    private fun attachUserDocListener() {
        val uid = FirebaseAuth.getInstance().currentUser?.uid
        if (uid == null) {
            Log.d(TAG, "Firebase istifadəçisi tapılmadı, cache boş qalacaq.")
            return
        }
        if (uid == cachedUid && userDocListener != null) return

        userDocListener?.remove()
        cachedUid = uid

        userDocListener = FirebaseFirestore.getInstance()
            .collection("users")
            .document(uid)
            .addSnapshotListener { snap, error ->
                if (error != null || snap == null || !snap.exists()) return@addSnapshotListener
                cachedPartnerUid = snap.getString("partnerUid")
                cachedSharingEnabled = snap.getBoolean("notificationSharingEnabled") ?: true
                @Suppress("UNCHECKED_CAST")
                cachedExcludedPackages =
                    (snap.get("notificationExcludedPackages") as? List<String>)?.toSet()
                        ?: emptySet()
                cachedPairId = cachedPartnerUid?.let { buildPairId(uid, it) }
            }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            // Özümüzün bildirişlərini tutmayaq (sonsuz dövr yaranmasın)
            if (sbn.packageName == applicationContext.packageName) return

            val extras: android.os.Bundle = sbn.notification.extras
            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
            val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""

            // Boş (yalnız ikon yeniləmə) bildirişləri saxlamayaq
            if (title.isEmpty() && text.isEmpty()) return

            val appLabel = try {
                val pm = applicationContext.packageManager
                val appInfo = pm.getApplicationInfo(sbn.packageName, 0)
                pm.getApplicationLabel(appInfo).toString()
            } catch (_: Exception) {
                sbn.packageName
            }

            val values = ContentValues().apply {
                put("package_name", sbn.packageName)
                put("app_label", appLabel)
                put("title", title)
                put("text", text)
                put("posted_at", sbn.postTime)
            }

            val db = dbHelper.writableDatabase
            val rowId = db.insert(TABLE, null, values)

            // Cache hələ hazır deyilsə (məs. xidmət yenicə oyandı), bir dəfəlik
            // bağlanmağa cəhd et ki, sonrakı bildirişlər üçün hazır olsun.
            if (cachedUid == null) attachUserDocListener()

            maybeSyncToFirestore(
                rowId = rowId,
                packageName = sbn.packageName,
                appLabel = appLabel,
                title = title,
                text = text,
                postedAt = sbn.postTime,
            )
        } catch (e: Exception) {
            // Xidmət heç vaxt çökməməlidir - hər hansı xəta sükutla keçilir
            Log.w(TAG, "onNotificationPosted xətası", e)
        }
    }

    /**
     * Paylaşım şərtləri (aktivdir, partner var, tətbiq istisna siyahısında
     * deyil, həssas açar sözlərə uyğun gəlmir) ödənirsə, bildirişi birbaşa
     * `sharedNotifications/{pairId}/items` kolleksiyasına yazır və uğurlu
     * olarsa yerli sətri `synced = 1` kimi işarələyir.
     */
    private fun maybeSyncToFirestore(
        rowId: Long,
        packageName: String,
        appLabel: String,
        title: String,
        text: String,
        postedAt: Long,
    ) {
        val uid = cachedUid ?: return
        val pairId = cachedPairId ?: return
        if (!cachedSharingEnabled) return
        if (cachedExcludedPackages.contains(packageName)) return
        if (isLikelySensitive(packageName)) return

        val data = hashMapOf(
            "ownerUid" to uid,
            "packageName" to packageName,
            "appLabel" to appLabel,
            "title" to title,
            "text" to text,
            "postedAt" to Timestamp(Date(postedAt)),
            "createdAt" to FieldValue.serverTimestamp(),
        )

        FirebaseFirestore.getInstance()
            .collection("sharedNotifications")
            .document(pairId)
            .collection("items")
            .add(data)
            .addOnSuccessListener { markSynced(rowId) }
            .addOnFailureListener { e ->
                // Offline ola bilər — Firestore SDK yazını yerli növbəyə alıb
                // qoşulan kimi göndərəcək; sətri "synced" işarələməyəcəyik ki,
                // lazım olsa sonrakı sinxronizasiya cəhdi (Dart tərəf açılanda)
                // də bunu görsün.
                Log.w(TAG, "Firestore yazısı uğursuz oldu, sonra yenidən cəhd olunacaq", e)
            }
    }

    private fun markSynced(rowId: Long) {
        try {
            val db = dbHelper.writableDatabase
            val values = ContentValues().apply { put("synced", 1) }
            db.update(TABLE, values, "id = ?", arrayOf(rowId.toString()))
        } catch (e: Exception) {
            Log.w(TAG, "markSynced xətası", e)
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        // Bildiriş sistemdən silinsə belə, tarixçədə saxlamağa davam edirik.
    }

    class VaultDbHelper(context: Context) :
        SQLiteOpenHelper(context, DB_NAME, null, 2) {

        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL(
                """
                CREATE TABLE $TABLE (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    package_name TEXT NOT NULL,
                    app_label TEXT NOT NULL,
                    title TEXT NOT NULL,
                    text TEXT NOT NULL,
                    posted_at INTEGER NOT NULL,
                    synced INTEGER NOT NULL DEFAULT 0
                )
                """.trimIndent()
            )
            db.execSQL("CREATE INDEX idx_posted_at ON $TABLE(posted_at DESC)")
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            if (oldVersion < 2) {
                db.execSQL("ALTER TABLE $TABLE ADD COLUMN synced INTEGER NOT NULL DEFAULT 0")
            }
        }
    }
}
