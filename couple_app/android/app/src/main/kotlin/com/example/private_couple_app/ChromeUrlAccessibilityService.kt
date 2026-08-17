package com.example.private_couple_app

import android.accessibilityservice.AccessibilityService
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.google.firebase.FirebaseApp
import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import java.util.Date
import java.util.regex.Pattern

/**
 * YALNIZ Chrome-un (`com.android.chrome`) ünvan zolağını oxuyan, məhdud
 * əhatəli Accessibility Service. Bu, birgə qərarla, qohumların şahid
 * olduğu razılıqla, partnerin fırıldaqçılıqdan qorunması məqsədilə
 * qurulub — heç bir başqa tətbiqin ekranını oxumur (`packageNames`
 * konfiqurasiyada Chrome ilə sərt məhdudlaşdırılıb, bax:
 * res/xml/chrome_url_service_config.xml).
 *
 * Yalnız URL tutulur (səhifə başlığı, məzmunu YOX). 2 həftədən köhnə
 * yazılar Cloudflare Worker-in gündəlik cron tapşırığı ilə avtomatik
 * silinir (bax: cloudflare-worker/src/index.js).
 */
class ChromeUrlAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "ChromeUrlService"
        private const val CHROME_PACKAGE = "com.android.chrome"
        private val URL_BAR_IDS = listOf(
            "com.android.chrome:id/url_bar",
            "com.android.chrome:id/location_bar_edit_text"
        )

        // Ehtiyat planı: dəqiq view ID tapılmasa, ekrandakı mətnlər arasında
        // URL-ə bənzəyən naxışı axtarır (tam zəmanət vermir, amma Chrome
        // yenilənib ID dəyişəndə sistemin tamamilə "kor" qalmasının qarşısını alır).
        private val URL_LIKE_PATTERN = Pattern.compile(
            "^(https?://\\S+|(www\\.)?[a-zA-Z0-9-]+\\.[a-z]{2,}(/\\S*)?)$"
        )
    }

    private var cachedUid: String? = null
    private var cachedPairId: String? = null
    private var cachedEnabled: Boolean = false
    private var userDocListener: ListenerRegistration? = null
    private var lastCapturedUrl: String? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        if (FirebaseApp.getApps(applicationContext).isEmpty()) {
            FirebaseApp.initializeApp(applicationContext)
        }
        attachUserDocListener()
    }

    private fun attachUserDocListener() {
        val uid = FirebaseAuth.getInstance().currentUser?.uid
        if (uid == null) {
            Log.d(TAG, "Firebase istifadəçisi tapılmadı.")
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
                val partnerUid = snap.getString("partnerUid")
                cachedEnabled = snap.getBoolean("browsingHistoryEnabled") ?: true
                cachedPairId = partnerUid?.let {
                    val ids = listOf(uid, it).sorted()
                    "${ids[0]}_${ids[1]}"
                }
            }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.packageName?.toString() != CHROME_PACKAGE) return
        if (cachedUid == null) attachUserDocListener()
        if (!cachedEnabled) return
        val pairId = cachedPairId ?: return

        val root = rootInActiveWindow ?: return
        val url = findUrl(root) ?: return
        root.recycle()

        if (url == lastCapturedUrl) return
        lastCapturedUrl = url

        saveUrl(pairId, url)
    }

    /** Əvvəlcə dəqiq view ID-lərlə axtarır, tapılmasa ehtiyat naxış axtarışına keçir. */
    private fun findUrl(root: AccessibilityNodeInfo): String? {
        for (id in URL_BAR_IDS) {
            val nodes = root.findAccessibilityNodeInfosByViewId(id)
            if (nodes.isNotEmpty()) {
                val text = nodes[0].text?.toString()
                if (!text.isNullOrBlank()) return text.trim()
            }
        }
        return findUrlLikeTextRecursive(root, depth = 0)
    }

    // DÜZELTME: Tüm return path'lerde node.recycle() çağrılıyor
    private fun findUrlLikeTextRecursive(
        node: AccessibilityNodeInfo,
        depth: Int
    ): String? {
        if (depth > 12) {
            node.recycle() // DÜZELTME: EKLENDİ
            return null
        }

        val text = node.text?.toString()?.trim()
        if (!text.isNullOrEmpty() && URL_LIKE_PATTERN.matcher(text).matches()) {
            node.recycle() // DÜZELTME: EKLENDİ
            return text
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = findUrlLikeTextRecursive(child, depth + 1)
            if (found != null) {
                node.recycle() // DÜZELTME: EKLENDİ
                return found
            }
        }
        
        node.recycle() // DÜZELTME: EKLENDİ
        return null
    }

    private fun saveUrl(pairId: String, url: String) {
        val uid = cachedUid ?: return
        val data = hashMapOf(
            "ownerUid" to uid,
            "url" to url,
            "capturedAt" to Timestamp(Date()),
            "createdAt" to FieldValue.serverTimestamp(),
        )
        FirebaseFirestore.getInstance()
            .collection("browsingHistory")
            .document(pairId)
            .collection("urls")
            .add(data)
            .addOnFailureListener { e ->
                Log.w(TAG, "URL yazısı uğursuz oldu", e)
            }
    }

    override fun onInterrupt() {}
}