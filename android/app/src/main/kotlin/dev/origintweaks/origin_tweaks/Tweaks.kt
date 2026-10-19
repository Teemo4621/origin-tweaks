package dev.origintweaks.origin_tweaks

import android.content.Context
import android.util.Log
import dev.origintweaks.origin_tweaks.FrameGen.Namespace

object Tweaks {
    private const val TAG = "OriginTweaks"

    internal class Entry(val namespace: Namespace, val key: String, val on: String, val off: String) {
        val id: String get() = "${namespace.name.lowercase()}/$key"
    }

    class Tweak internal constructor(
        val id: String,
        internal val entries: List<Entry>,
        val keepApplied: Boolean = false,
    ) {
        val enabledPref: String get() = "${id}_enabled"
        val savedPref: String get() = "saved_$id"
    }

    val MONSTER_PLUS = Tweak(
        id = "monster_plus",
        entries = listOf(
            Entry(Namespace.SECURE, "system_property_power_mode_type", "5", "1"),
            Entry(Namespace.SYSTEM, "game_plus_mode_key", "1", "0"),
            Entry(Namespace.SYSTEM, "power_save_type", "8", "1"),
            Entry(Namespace.SECURE, "power_save_type", "8", "1"),
        ),
    )

    val HAWKEYE = Tweak(
        id = "hawkeye",
        entries = listOf(Entry(Namespace.SYSTEM, "gamecube_hawkeye_effective", "1", "0")),
        keepApplied = true,
    )

    val TOUCH_BOOST = Tweak(
        id = "touch_boost",
        entries = listOf(Entry(Namespace.SYSTEM, "vts_game_para_adjust", "0,5,5,5", "0,3,3,3")),
        keepApplied = true,
    )

    val ALL = listOf(MONSTER_PLUS, HAWKEYE, TOUCH_BOOST)

    val watchedSystemKeys: List<String>
        get() = ALL.filter { it.keepApplied }.flatMap { tweak ->
            tweak.entries.filter { it.namespace == Namespace.SYSTEM }.map { it.key }
        }

    fun byId(id: String?): Tweak? = ALL.firstOrNull { it.id == id }

    fun apply(context: Context, tweak: Tweak, enabled: Boolean): Int {
        if (!HelperClient.isReady(context)) return FrameGen.RESULT_NO_HELPER
        if (!FrameGen.hasSecurePermission(context)) return FrameGen.RESULT_NO_PERMISSION
        val store = ProfileStore(context)
        return try {
            if (enabled) {
                if (store.savedTweak(tweak) == null) {
                    store.setSavedTweak(tweak, tweak.entries.mapNotNull { entry ->
                        FrameGen.read(context, entry.namespace, entry.key)?.let { entry.id to it }
                    }.toMap())
                }
                tweak.entries.forEach { FrameGen.write(context, it.namespace, it.key, it.on) }
                store.setTweakEnabled(tweak, true)
                val mismatched = drifted(context, tweak)
                if (mismatched.isEmpty()) {
                    FrameGen.RESULT_OK
                } else {
                    Log.w(TAG, "${tweak.id} not kept: ${mismatched.joinToString { it.id }}")
                    FrameGen.RESULT_BLOCKED
                }
            } else {
                val saved = store.savedTweak(tweak).orEmpty()
                tweak.entries.forEach { FrameGen.write(context, it.namespace, it.key, saved[it.id] ?: it.off) }
                store.setSavedTweak(tweak, null)
                store.setTweakEnabled(tweak, false)
                FrameGen.RESULT_OK
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "${tweak.id} write denied", e)
            FrameGen.RESULT_NO_PERMISSION
        } catch (e: Exception) {
            Log.w(TAG, "${tweak.id} write failed", e)
            FrameGen.RESULT_FAILED
        }
    }

    fun reapplyDrifted(context: Context) {
        val store = ProfileStore(context)
        ALL.filter { it.keepApplied && store.isTweakEnabled(it) }.forEach { tweak ->
            val mismatched = drifted(context, tweak)
            if (mismatched.isEmpty()) return@forEach
            Log.i(TAG, "re-applying ${tweak.id}: ${mismatched.joinToString { it.id }}")
            runCatching { mismatched.forEach { FrameGen.write(context, it.namespace, it.key, it.on) } }
                .onFailure { Log.w(TAG, "${tweak.id} re-apply failed", it) }
        }
    }

    fun status(context: Context, tweak: Tweak): Map<String, Any?> = mapOf(
        "enabled" to ProfileStore(context).isTweakEnabled(tweak),
        "values" to tweak.entries.map { entry ->
            mapOf(
                "key" to entry.id,
                "value" to FrameGen.read(context, entry.namespace, entry.key),
                "expected" to entry.on,
            )
        },
    )

    private fun drifted(context: Context, tweak: Tweak): List<Entry> =
        tweak.entries.filter { FrameGen.read(context, it.namespace, it.key) != it.on }
}
