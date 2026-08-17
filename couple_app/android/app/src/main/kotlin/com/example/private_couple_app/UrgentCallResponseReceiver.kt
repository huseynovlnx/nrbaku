package com.example.private_couple_app

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * "✓ Cavab verdim" bildiriş düyməsinə toxunulanda işə düşür. Tətbiqi
 * açmadan, birbaşa Firestore-a "responded" statusunu yazır, bildirişi
 * bağlayır, VƏ göndərənə (partnerə) birbaşa push göndərir — bu sonuncu
 * addım vacibdir, çünki göndərənin tətbiqi TAM bağlı olsa belə (nə
 * Firestore live-listener, nə də köhnə Cloud Function işləyə bilməz)
 * onun xəbərdar olmasının yeganə yoludur.
 */
class UrgentCallResponseReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_RESPOND = "com.example.private_couple_app.ACTION_RESPOND_URGENT_CALL"

        // push_relay_service.dart ilə EYNİ dəyərlər — Cloudflare Worker
        // vasitəsilə partnerə birbaşa push göndərmək üçün.
        private const val WORKER_URL = "https://sesi-push-relay.instagramim-az.workers.dev"
        private const val WORKER_AUTH_SECRET = "9fMWX21HIf90VeMkZVedkD1xfHVCfCCbQpu5lcY"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val callId = intent.getStringExtra("callId") ?: return
        val pairId = intent.getStringExtra("pairId") ?: return
        val fromUid = intent.getStringExtra("fromUid")
        val notificationId = intent.getIntExtra("notificationId", callId.hashCode())

        // Bildirişi dərhal bağla ki, istifadəçi ani reaksiya görsün
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(notificationId)

        // goAsync(): bütün asinxron işlər (Firestore yazısı + push
        // göndərmə) bitənə qədər sistemin bu prosesi öldürməsinin
        // qarşısını alır.
        val pendingResult = goAsync()

        try {
            if (FirebaseApp.getApps(context).isEmpty()) {
                FirebaseApp.initializeApp(context)
            }
            FirebaseFirestore.getInstance()
                .collection("urgentCalls")
                .document(pairId)
                .collection("items")
                .document(callId)
                .update(
                    mapOf(
                        "status" to "responded",
                        "respondedAt" to FieldValue.serverTimestamp()
                    )
                )
                .addOnCompleteListener { writeTask ->
                    if (!writeTask.isSuccessful) {
                        Log.w("UrgentCallResponse", "Firestore yazısı uğursuz oldu", writeTask.exception)
                    }
                    // Firestore nəticəsindən asılı olmayaraq (best-effort),
                    // partnerə push göndərməyə çalış.
                    notifySenderThenFinish(fromUid, pendingResult)
                }
        } catch (e: Exception) {
            Log.w("UrgentCallResponse", "Firestore yazısı uğursuz oldu", e)
            notifySenderThenFinish(fromUid, pendingResult)
        }
    }

    private fun notifySenderThenFinish(fromUid: String?, pendingResult: PendingResult) {
        if (fromUid.isNullOrEmpty()) {
            pendingResult.finish()
            return
        }
        FirebaseFirestore.getInstance().collection("users").document(fromUid).get()
            .addOnCompleteListener { tokenTask ->
                val token = tokenTask.result?.getString("fcmToken")
                if (token.isNullOrEmpty()) {
                    pendingResult.finish()
                    return@addOnCompleteListener
                }
                // HttpURLConnection bloklayıcıdır — ayrı thread-də icra et.
                Thread {
                    try {
                        sendResponsePush(token)
                    } catch (e: Exception) {
                        Log.w("UrgentCallResponse", "Push göndərilə bilmədi", e)
                    } finally {
                        pendingResult.finish()
                    }
                }.start()
            }
    }

    private fun sendResponsePush(token: String) {
        val conn = URL(WORKER_URL).openConnection() as HttpURLConnection
        try {
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("Authorization", "Bearer $WORKER_AUTH_SECRET")
            conn.doOutput = true
            conn.connectTimeout = 8000
            conn.readTimeout = 8000

            val json = JSONObject().apply {
                put("token", token)
                put("title", "✓ Cavab verdi")
                put("body", "Partneriniz təcili çağırışınıza cavab verdi")
            }
            conn.outputStream.use { it.write(json.toString().toByteArray(Charsets.UTF_8)) }
            conn.responseCode // sorğunu faktiki göndərmək üçün oxunmalıdır
        } finally {
            conn.disconnect()
        }
    }
}
