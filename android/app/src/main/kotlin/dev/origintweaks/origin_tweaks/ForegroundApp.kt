package dev.origintweaks.origin_tweaks

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Process

object ForegroundApp {
    private const val LOOKBACK_MS = 10 * 60_000L

    fun hasUsageAccess(context: Context): Boolean {
        val appOps = context.getSystemService(AppOpsManager::class.java)
        val mode = appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        return mode == AppOpsManager.MODE_ALLOWED
    }

    fun current(context: Context): String? {
        if (!hasUsageAccess(context)) return null
        val usageStats = context.getSystemService(UsageStatsManager::class.java)
        val now = System.currentTimeMillis()
        val events = usageStats.queryEvents(now - LOOKBACK_MS, now)
        var latest: String? = null
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED && event.packageName != context.packageName) {
                latest = event.packageName
            }
        }
        return latest
    }

    fun targetPreset(store: ProfileStore, packageName: String?): Preset {
        if (packageName != null && store.profileServiceEnabled) store.profiles()[packageName]?.let { return it }
        return store.manualPreset
    }
}
