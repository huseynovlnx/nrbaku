package com.example.private_couple_app

import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val VAULT_CHANNEL = "com.example.private_couple_app/notification_vault"
    private val PERMISSION_FLOW_CHANNEL = "com.example.private_couple_app/permission_flow"
    private val URGENT_CALL_CHANNEL = "com.example.private_couple_app/urgent_call_launch"
    private val CHROME_ACCESSIBILITY_CHANNEL = "com.example.private_couple_app/chrome_accessibility"
    private val LOCATION_TRACKING_CHANNEL = "com.example.private_couple_app/location_tracking"
    private val EXACT_ALARM_CHANNEL = "com.example.private_couple_app/exact_alarm"
    private val REMINDER_ALARM_CHANNEL = "com.example.private_couple_app/reminder_alarm"
    private val DEVICE_REPORTER_CHANNEL = "com.example.private_couple_app/device_reporter"

    private var urgentCallChannel: MethodChannel? = null
    private var pendingUrgentCall: Map<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // SOS VƏ YA Xatırladıcı (alarm) ekranı açılıbsa ekranı aç və kilidi
        // keç — super.onCreate()-dən SONRA çağrılır, çünki Window obyekti
        // bəzi OEM (Samsung One UI) qatlarında ondan əvvəl etibarlı şəkildə
        // hazır olmaya bilər.
        if (isWakeScreenIntent(intent)) {
            wakeUpScreen()
            dismissKeyguard()
            keepScreenOn()
        }

        extractUrgentCallExtras(intent)?.let { pendingUrgentCall = it }
    }

    /** SOS çağırışı VƏ YA xatırladıcı alarmı — hər ikisi ekranı oyatmalıdır. */
    private fun isWakeScreenIntent(intent: Intent?): Boolean {
        return intent?.getStringExtra("urgent_call_id") != null ||
            intent?.hasExtra("reminder_alarm_id") == true
    }

    private fun wakeUpScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    private fun dismissKeyguard() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD)
        }
    }

    private fun keepScreenOn() {
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        // SOS VƏ YA Xatırladıcı — tətbiq artıq açıq olanda (cold-start yox,
        // bu metoddan keçəndə) da ekran oyadılmalıdır. Əvvəllər bu yoxlama
        // yalnız SOS-a məxsus idi və digər hallarda ERKƏN return edirdi —
        // xatırladıcı üçün ekran heç vaxt oyanmırdı.
        if (isWakeScreenIntent(intent)) {
            wakeUpScreen()
            dismissKeyguard()
        }

        val data = extractUrgentCallExtras(intent) ?: return

        val ch = urgentCallChannel
        if (ch != null) {
            ch.invokeMethod("onUrgentCallLaunch", data)
        } else {
            pendingUrgentCall = data
        }
    }

    private fun extractUrgentCallExtras(intent: Intent?): Map<String, String>? {
        val callId = intent?.getStringExtra("urgent_call_id") ?: return null
        return mapOf(
            "callId" to callId,
            "pairId" to (intent.getStringExtra("urgent_call_pairId") ?: ""),
            "fromName" to (intent.getStringExtra("urgent_call_fromName") ?: "Partner"),
            "message" to (intent.getStringExtra("urgent_call_message") ?: "")
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VAULT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isNotificationAccessEnabled" -> {
                        result.success(isNotificationAccessEnabled())
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSION_FLOW_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isFullScreenIntentGranted" -> {
                        result.success(isFullScreenIntentGranted())
                    }
                    "openFullScreenIntentSettings" -> {
                        openFullScreenIntentSettings()
                        result.success(null)
                    }
                    "isDndAccessGranted" -> {
                        result.success(isDndAccessGranted())
                    }
                    "openDndAccessSettings" -> {
                        openDndAccessSettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        urgentCallChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, URGENT_CALL_CHANNEL)
        urgentCallChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingUrgentCall" -> {
                    result.success(pendingUrgentCall)
                    pendingUrgentCall = null
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHROME_ACCESSIBILITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAccessibilityEnabled" -> {
                        result.success(isChromeAccessibilityEnabled())
                    }
                    "openAccessibilitySettings" -> {
                        openAccessibilitySettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCATION_TRACKING_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isBackgroundLocationGranted" -> {
                        result.success(isBackgroundLocationGranted())
                    }
                    "openBackgroundLocationSettings" -> {
                        openBackgroundLocationSettings()
                        result.success(null)
                    }
                    "startLocationTracking" -> {
                        startLocationTrackingService()
                        result.success(null)
                    }
                    "stopLocationTracking" -> {
                        stopLocationTrackingService()
                        result.success(null)
                    }
                    "isLocationTrackingActive" -> {
                        result.success(LocationTrackingService.isEnabled(applicationContext))
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EXACT_ALARM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canScheduleExactAlarms" -> {
                        result.success(canScheduleExactAlarms())
                    }
                    "openExactAlarmSettings" -> {
                        openExactAlarmSettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, REMINDER_ALARM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleReminder" -> {
                        val id = call.argument<Int>("id") ?: 0
                        val title = call.argument<String>("title") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        val timestamp = call.argument<Long>("timestampMillis") ?: 0L
                        val recurring = call.argument<Boolean>("recurringYearly") ?: false
                        ReminderScheduler.schedule(
                            applicationContext, id, title, body, timestamp, recurring
                        )
                        result.success(null)
                    }
                    "cancelReminder" -> {
                        val id = call.argument<Int>("id") ?: 0
                        ReminderScheduler.cancel(applicationContext, id)
                        result.success(null)
                    }
                    "syncReminders" -> {
                        @Suppress("UNCHECKED_CAST")
                        val items = call.argument<List<Map<String, Any?>>>("items") ?: emptyList()
                        ReminderScheduler.syncAll(applicationContext, items)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        setupDeviceReporterChannel(flutterEngine)
    }

    private fun canScheduleExactAlarms(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true // 31-dən aşağıda ayrıca icazə yoxdur
        val am = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        return am.canScheduleExactAlarms()
    }

    private fun openExactAlarmSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        try {
            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        } catch (_: Exception) {
        }
    }

    private fun isBackgroundLocationGranted(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return true // 29-dan aşağıda ayrıca icazə yoxdur
        return androidx.core.content.ContextCompat.checkSelfPermission(
            this, android.Manifest.permission.ACCESS_BACKGROUND_LOCATION
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    private fun openBackgroundLocationSettings() {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        } catch (_: Exception) {
        }
    }

    private fun startLocationTrackingService() {
        val intent = Intent(this, LocationTrackingService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopLocationTrackingService() {
        val intent = Intent(this, LocationTrackingService::class.java).apply {
            action = LocationTrackingService.ACTION_STOP
        }
        startService(intent)
    }

    private fun setupDeviceReporterChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_REPORTER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDeviceStatus" -> {
                        result.success(DeviceStatusHelper.getStatus(applicationContext))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isChromeAccessibilityEnabled(): Boolean {
        val enabled = Settings.Secure.getString(
            applicationContext.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabled.contains("${packageName}/${packageName}.ChromeUrlAccessibilityService")
    }

    private fun openAccessibilitySettings() {
        try {
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
        } catch (_: Exception) {}
    }

    private fun isNotificationAccessEnabled(): Boolean {
        val pkgName = applicationContext.packageName
        val enabledListeners = Settings.Secure.getString(
            applicationContext.contentResolver,
            "enabled_notification_listeners"
        ) ?: return false
        return enabledListeners.contains(pkgName)
    }

    private fun isFullScreenIntentGranted(): Boolean {
        if (Build.VERSION.SDK_INT < 34) return true
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        return nm.canUseFullScreenIntent()
    }

    private fun openFullScreenIntentSettings() {
        if (Build.VERSION.SDK_INT < 34) return
        try {
            val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        } catch (_: Exception) {
        }
    }

    private fun isDndAccessGranted(): Boolean {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        return nm.isNotificationPolicyAccessGranted
    }

    private fun openDndAccessSettings() {
        try {
            val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            startActivity(intent)
        } catch (_: Exception) {}
    }
}