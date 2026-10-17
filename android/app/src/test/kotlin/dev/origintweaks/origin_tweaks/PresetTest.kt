package dev.origintweaks.origin_tweaks

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PresetTest {
    @Test
    fun interpolationValuesMatchTheWorkingTaskerValue() {
        assertEquals("1:106::48:144", Preset.FPS144.interpolationValue)
        assertEquals("1:106::60:120", Preset.FPS120.interpolationValue)
        assertEquals("1:106::45:90", Preset.FPS90.interpolationValue)
        assertEquals("0:-1:0:0:0", Preset.OFF.interpolationValue)
    }

    @Test
    fun nextCyclesBackToOff() {
        assertEquals(Preset.FPS90, Preset.OFF.next())
        assertEquals(Preset.OFF, Preset.FPS144.next())
    }

    @Test
    fun fromValueMatchesFpsFieldsOnly() {
        assertEquals(Preset.FPS144, Preset.fromValue("1:106::48:144"))
        assertEquals(Preset.FPS144, Preset.fromValue("1:105:26574:48:144"))
        assertEquals(Preset.OFF, Preset.fromValue("0:-1:26574:0:0"))
        assertNull(Preset.fromValue("1:105:26574:72:144"))
        assertNull(Preset.fromValue("garbage"))
        assertNull(Preset.fromValue(null))
    }

    @Test
    fun profilesRoundTrip() {
        val profiles = mapOf("com.tencent.ig" to Preset.FPS120, "com.miHoYo.GenshinImpact" to Preset.FPS90)
        assertEquals(profiles, ProfileStore.decode(ProfileStore.encode(profiles)))
    }

    @Test
    fun decodeSkipsBrokenLines() {
        assertEquals(
            mapOf("a.b" to Preset.FPS144),
            ProfileStore.decode("a.b=fps144\n=fps90\nc.d=unknown\nnoequals"),
        )
    }

    @Test
    fun savedSettingsRoundTripValuesWithColons() {
        val values = mapOf("gamecube_frame_interpolation" to "0:-1:22765:0:0", "gamecube_super_resolution" to "0:")
        assertEquals(values, ProfileStore.decodeValues(ProfileStore.encodeValues(values)))
    }

    @Test
    fun packageValidationRejectsShellInput() {
        assertTrue(ShellUserService.isValidPackage("dev.origintweaks.origin_tweaks"))
        assertFalse(ShellUserService.isValidPackage("a.b; reboot"))
        assertFalse(ShellUserService.isValidPackage("nodots"))
        assertFalse(ShellUserService.isValidPackage(null))
    }
}
