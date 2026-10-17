package dev.origintweaks.origin_tweaks

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.provider.Settings
import android.util.Log

object FrameGen {
    const val RESULT_OK = 0
    const val RESULT_FAILED = 1

    const val RESULT_BLOCKED = 2

    const val RESULT_NO_PERMISSION = 3

    const val RESULT_NO_HELPER = 4

    const val INTERPOLATION_KEY = "gamecube_frame_interpolation"

    private const val TAG = "OriginTweaks"

    private enum class Namespace { SYSTEM, SECURE, GLOBAL }

    private class Entry(val namespace: Namespace, val key: String, val on: (Preset) -> String, val off: String?)

    private val ENTRIES = listOf(
        Entry(Namespace.SYSTEM, INTERPOLATION_KEY, { it.interpolationValue }, Preset.OFF_VALUE),
        Entry(Namespace.SECURE, "gamecube_super_resolution", { "2:" }, "0:"),
        Entry(Namespace.SYSTEM, "vivo_sr_status", { "2" }, "0"),
        Entry(Namespace.GLOBAL, "xpq_value_from_gamecube", { "1" }, "0"),
        Entry(Namespace.GLOBAL, "vsr_value_from_gamecube", { "1" }, "0"),
        Entry(Namespace.SYSTEM, "nova_memc_status", { "1" }, "0"),
        Entry(Namespace.SYSTEM, "vivo_fullscreen_flag", { "1" }, "0"),
        Entry(Namespace.SYSTEM, "memc_main_switch_setting", { "1" }, null),
        Entry(Namespace.SYSTEM, "gamewatch_game_target_fps", { it.targetFps.toString() }, "-1"),
        Entry(Namespace.SECURE, "gamecube_force_bypass_mode", { "0" }, null),
    )

    fun hasSecurePermission(context: Context): Boolean =
        context.checkSelfPermission(Manifest.permission.WRITE_SECURE_SETTINGS) == PackageManager.PERMISSION_GRANTED

    fun isReady(context: Context): Boolean = HelperClient.isReady(context) && hasSecurePermission(context)

    fun readInterpolation(context: Context): String? =
        read(context, Namespace.SYSTEM, INTERPOLATION_KEY)

    fun apply(context: Context, preset: Preset): Int {
        if (!HelperClient.isReady(context)) return RESULT_NO_HELPER
        if (!hasSecurePermission(context)) return RESULT_NO_PERMISSION
        val store = ProfileStore(context)
        return try {
            if (preset.enabled) {
                if (store.savedSettings == null) store.savedSettings = snapshot(context)
                ENTRIES.forEach { write(context, it.namespace, it.key, it.on(preset)) }
            } else {
                val saved = store.savedSettings.orEmpty()
                ENTRIES.forEach { entry ->
                    val value = saved[entry.key] ?: entry.off ?: return@forEach
                    write(context, entry.namespace, entry.key, value)
                }
                store.savedSettings = null
            }
            val expected = if (preset.enabled) preset.interpolationValue else null
            if (expected != null && readInterpolation(context) != expected) RESULT_BLOCKED else RESULT_OK
        } catch (e: SecurityException) {
            Log.w(TAG, "write denied", e)
            RESULT_NO_PERMISSION
        } catch (e: Exception) {
            Log.w(TAG, "write failed", e)
            RESULT_FAILED
        }
    }

    private fun snapshot(context: Context): Map<String, String> =
        ENTRIES.mapNotNull { entry -> read(context, entry.namespace, entry.key)?.let { entry.key to it } }.toMap()

    private fun read(context: Context, namespace: Namespace, key: String): String? = try {
        val resolver = context.contentResolver
        when (namespace) {
            Namespace.SYSTEM -> HelperClient.get(context, key)
            Namespace.SECURE -> Settings.Secure.getString(resolver, key)
            Namespace.GLOBAL -> Settings.Global.getString(resolver, key)
        }
    } catch (e: Exception) {
        Log.w(TAG, "read $key failed", e)
        null
    }

    private fun write(context: Context, namespace: Namespace, key: String, value: String) {
        val resolver = context.contentResolver
        when (namespace) {
            Namespace.SYSTEM -> HelperClient.put(context, key, value)
            Namespace.SECURE -> Settings.Secure.putString(resolver, key, value)
            Namespace.GLOBAL -> Settings.Global.putString(resolver, key, value)
        }
    }
}
