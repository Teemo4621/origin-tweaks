package dev.origintweaks.origin_tweaks

enum class Preset(val id: String, val sourceFps: Int, val targetFps: Int, val label: String) {
    OFF("off", 0, 0, "Off"),
    FPS90("fps90", 45, 90, "90 FPS"),
    FPS120("fps120", 60, 120, "120 FPS"),
    FPS144("fps144", 48, 144, "144 FPS");

    val enabled: Boolean get() = this != OFF

    val interpolationValue: String
        get() = if (enabled) "1:$GAME_INDEX::$sourceFps:$targetFps" else OFF_VALUE

    fun next(): Preset = entries[(ordinal + 1) % entries.size]

    companion object {
        const val GAME_INDEX = 106
        const val OFF_VALUE = "0:-1:0:0:0"

        fun fromId(id: String?): Preset? = entries.firstOrNull { it.id == id }

        fun fromValue(value: String?): Preset? {
            val fields = value?.trim()?.split(':') ?: return null
            if (fields.size < 5) return null
            if (fields[0] == "0") return OFF
            if (fields[0] != "1") return null
            return entries.firstOrNull {
                it.enabled && fields[3] == it.sourceFps.toString() && fields[4] == it.targetFps.toString()
            }
        }
    }
}
