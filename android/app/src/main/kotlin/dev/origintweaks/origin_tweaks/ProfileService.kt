package dev.origintweaks.origin_tweaks

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.database.ContentObserver
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.util.Log

class ProfileService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var store: ProfileStore
    private lateinit var usageStats: UsageStatsManager

    private var lastQueryTime = 0L
    private var foregroundPackage: String? = null
    private var target: Preset = Preset.OFF
    private var lastReapply = 0L
    private var lastTweakReapply = 0L

    private val poll = object : Runnable {
        override fun run() {
            checkForeground()
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    private val applyTarget = Runnable { apply() }

    private val verifyTarget = Runnable { verify("foreground") }
    private val verifyTargetLate = Runnable { verify("foreground-late") }
    private val lateTweakCheck = Runnable { scheduleTweakCheck() }

    private val settingObserver = object : ContentObserver(handler) {
        override fun onChange(selfChange: Boolean) {
            Log.i(TAG, "interpolation setting changed")
            verify("observer")
        }
    }

    private val reapplyTweaks = Runnable {
        lastTweakReapply = SystemClock.elapsedRealtime()
        ShizukuBridge.reapplyTweaks()
    }

    private val tweakObserver = object : ContentObserver(handler) {
        override fun onChange(selfChange: Boolean) = scheduleTweakCheck()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ShizukuBridge.init(applicationContext)
        store = ProfileStore(this)
        usageStats = getSystemService(UsageStatsManager::class.java)
        createChannel()
        startInForeground(getString(R.string.profile_waiting))
        contentResolver.registerContentObserver(
            Settings.System.getUriFor(FrameGen.INTERPOLATION_KEY), false, settingObserver,
        )
        Tweaks.watchedSystemKeys.forEach { key ->
            contentResolver.registerContentObserver(Settings.System.getUriFor(key), false, tweakObserver)
        }
        lastQueryTime = System.currentTimeMillis() - INITIAL_LOOKBACK_MS
        foregroundPackage = ForegroundApp.current(this)
        handler.post(poll)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!store.needsService) {
            stopSelf()
            return START_NOT_STICKY
        }

        reevaluate(delayMs = 0)
        scheduleTweakCheck()
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        contentResolver.unregisterContentObserver(settingObserver)
        contentResolver.unregisterContentObserver(tweakObserver)

        val manual = store.manualPreset
        if (target != manual) ShizukuBridge.applyPreset(manual) {}
        super.onDestroy()
    }

    private fun checkForeground() {
        if (!ForegroundApp.hasUsageAccess(this)) return
        val now = System.currentTimeMillis()
        val events = usageStats.queryEvents(lastQueryTime, now)
        lastQueryTime = now
        var latest: String? = null
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED && event.packageName != packageName) {
                latest = event.packageName
            }
        }
        if (latest != null && latest != foregroundPackage) {
            foregroundPackage = latest
            reevaluate(delayMs = APPLY_DELAY_MS)
            handler.removeCallbacks(verifyTarget)
            handler.removeCallbacks(verifyTargetLate)
            handler.postDelayed(verifyTarget, APPLY_DELAY_MS + VERIFY_DELAY_MS)
            handler.postDelayed(verifyTargetLate, LATE_VERIFY_DELAY_MS)
            handler.removeCallbacks(lateTweakCheck)
            handler.postDelayed(lateTweakCheck, LATE_VERIFY_DELAY_MS)
            scheduleTweakCheck(minDelayMs = APPLY_DELAY_MS + VERIFY_DELAY_MS)
        }
    }

    private fun scheduleTweakCheck(minDelayMs: Long = 0) {
        handler.removeCallbacks(reapplyTweaks)
        val wait = lastTweakReapply + TWEAK_REAPPLY_MIN_INTERVAL_MS - SystemClock.elapsedRealtime()
        handler.postDelayed(reapplyTweaks, maxOf(wait, minDelayMs, 0))
    }

    private fun reevaluate(delayMs: Long) {
        val previous = target
        target = ForegroundApp.targetPreset(store, foregroundPackage)
        if (target != previous) {
            handler.removeCallbacks(applyTarget)
            handler.postDelayed(applyTarget, delayMs)
        }
        updateNotification()
    }

    private fun apply() {
        ShizukuBridge.applyPreset(target) { result -> updateNotification(result) }
    }

    private fun verify(reason: String) {
        if (!target.enabled) return
        ShizukuBridge.readCurrent { value ->
            if (!target.enabled || Preset.fromValue(value) == target) return@readCurrent
            Log.i(TAG, "re-applying $target ($reason): found $value")
            val now = SystemClock.elapsedRealtime()
            handler.removeCallbacks(applyTarget)
            if (now - lastReapply < REAPPLY_MIN_INTERVAL_MS) {
                handler.postDelayed(applyTarget, REAPPLY_MIN_INTERVAL_MS)
            } else {
                lastReapply = now
                handler.post(applyTarget)
            }
        }
    }

    private fun appLabel(packageName: String): String = try {
        packageManager.getApplicationLabel(packageManager.getApplicationInfo(packageName, 0)).toString()
    } catch (_: Exception) {
        packageName
    }

    private fun createChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID, getString(R.string.profile_channel), NotificationManager.IMPORTANCE_LOW,
        )
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(text: String): Notification {
        val openApp = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE,
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(if (target.enabled) R.drawable.ic_tile_on else R.drawable.ic_tile_off)
            .setColor(getColor(R.color.brand))
            .setContentTitle(getString(R.string.profile_title))
            .setContentText(text)
            .setContentIntent(openApp)
            .setOngoing(true)
            .build()
    }

    private fun startInForeground(text: String) {
        val notification = buildNotification(text)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification(result: Int = FrameGen.RESULT_OK) {
        val packageName = foregroundPackage
        val text = when {
            result == FrameGen.RESULT_BLOCKED -> getString(R.string.error_blocked)
            result == FrameGen.RESULT_NO_PERMISSION || result == FrameGen.RESULT_NO_HELPER ->
                getString(R.string.tile_setup_needed)
            !target.enabled || packageName == null -> getString(R.string.profile_waiting)
            else -> getString(R.string.profile_active, appLabel(packageName), target.label)
        }
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, buildNotification(text))
    }

    companion object {
        private const val TAG = "OriginTweaks"
        private const val CHANNEL_ID = "profiles"
        private const val NOTIFICATION_ID = 1
        private const val POLL_INTERVAL_MS = 1000L
        private const val INITIAL_LOOKBACK_MS = 60_000L
        private const val APPLY_DELAY_MS = 1500L
        private const val VERIFY_DELAY_MS = 500L
        private const val LATE_VERIFY_DELAY_MS = 5000L
        private const val REAPPLY_MIN_INTERVAL_MS = 1000L
        private const val TWEAK_REAPPLY_MIN_INTERVAL_MS = 3000L

        fun sync(context: Context) {
            val intent = Intent(context, ProfileService::class.java)
            if (ProfileStore(context).needsService) {
                try {
                    context.startForegroundService(intent)
                } catch (e: Exception) {
                    Log.w(TAG, "cannot start ProfileService", e)
                }
            } else {
                context.stopService(intent)
            }
        }
    }
}
