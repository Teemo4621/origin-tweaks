package dev.origintweaks.origin_tweaks

import android.content.Context

class ProfileStore(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    var manualPreset: Preset
        get() = Preset.fromId(prefs.getString(KEY_MANUAL, null)) ?: Preset.OFF
        set(value) = prefs.edit().putString(KEY_MANUAL, value.id).apply()

    var profileServiceEnabled: Boolean
        get() = prefs.getBoolean(KEY_SERVICE_ENABLED, false)
        set(value) = prefs.edit().putBoolean(KEY_SERVICE_ENABLED, value).apply()

    fun profiles(): Map<String, Preset> = decode(prefs.getString(KEY_PROFILES, "") ?: "")

    fun setProfile(packageName: String, preset: Preset?) {
        val updated = profiles().toMutableMap()
        if (preset == null) updated.remove(packageName) else updated[packageName] = preset
        prefs.edit().putString(KEY_PROFILES, encode(updated)).apply()
    }

    fun rememberChoice(packageName: String?, preset: Preset) {
        if (packageName != null && profileServiceEnabled && packageName in profiles()) {
            setProfile(packageName, preset)
        } else {
            manualPreset = preset
        }
    }

    var savedSettings: Map<String, String>?
        get() = prefs.getString(KEY_SAVED_SETTINGS, null)?.let { decodeValues(it) }
        set(value) = prefs.edit().putString(KEY_SAVED_SETTINGS, value?.let { encodeValues(it) }).apply()

    var superResLevel: Int
        get() = prefs.getInt(KEY_SUPER_RES_LEVEL, 0)
        set(value) = prefs.edit().putInt(KEY_SUPER_RES_LEVEL, value).apply()

    var savedSuperRes: String?
        get() = prefs.getString(KEY_SAVED_SUPER_RES, null)
        set(value) = prefs.edit().putString(KEY_SAVED_SUPER_RES, value).apply()

    fun isTweakEnabled(tweak: Tweaks.Tweak): Boolean = prefs.getBoolean(tweak.enabledPref, false)

    fun setTweakEnabled(tweak: Tweaks.Tweak, enabled: Boolean) =
        prefs.edit().putBoolean(tweak.enabledPref, enabled).apply()

    fun savedTweak(tweak: Tweaks.Tweak): Map<String, String>? =
        prefs.getString(tweak.savedPref, null)?.let { decodeValues(it) }

    fun setSavedTweak(tweak: Tweaks.Tweak, values: Map<String, String>?) =
        prefs.edit().putString(tweak.savedPref, values?.let { encodeValues(it) }).apply()

    val needsService: Boolean
        get() = profileServiceEnabled || manualPreset.enabled ||
            Tweaks.ALL.any { it.keepApplied && isTweakEnabled(it) }

    companion object {
        private const val PREFS = "origin_tweaks"
        private const val KEY_MANUAL = "manual_preset"
        private const val KEY_SERVICE_ENABLED = "profile_service_enabled"
        private const val KEY_PROFILES = "profiles"
        private const val KEY_SAVED_SETTINGS = "saved_settings"
        private const val KEY_SUPER_RES_LEVEL = "super_res_level"
        private const val KEY_SAVED_SUPER_RES = "saved_super_res"

        fun encodeValues(values: Map<String, String>): String =
            values.entries.sortedBy { it.key }.joinToString("\n") { "${it.key}=${it.value}" }

        fun decodeValues(raw: String): Map<String, String> =
            raw.lineSequence().mapNotNull { line ->
                val separator = line.indexOf('=')
                if (separator <= 0) null else line.substring(0, separator) to line.substring(separator + 1)
            }.toMap()

        fun encode(profiles: Map<String, Preset>): String =
            profiles.entries.sortedBy { it.key }.joinToString("\n") { "${it.key}=${it.value.id}" }

        fun decode(raw: String): Map<String, Preset> =
            raw.lineSequence().mapNotNull { line ->
                val separator = line.indexOf('=')
                if (separator <= 0) return@mapNotNull null
                val preset = Preset.fromId(line.substring(separator + 1).trim()) ?: return@mapNotNull null
                line.substring(0, separator).trim() to preset
            }.toMap()
    }
}
