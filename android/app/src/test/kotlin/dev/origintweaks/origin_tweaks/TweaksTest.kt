package dev.origintweaks.origin_tweaks

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TweaksTest {
    @Test
    fun monsterPlusKeepsItsExistingPreferenceKeys() {
        assertEquals("monster_plus_enabled", Tweaks.MONSTER_PLUS.enabledPref)
        assertEquals("saved_monster_plus", Tweaks.MONSTER_PLUS.savedPref)
    }

    @Test
    fun onlyDisplayAndTouchTweaksAreKeptApplied() {
        assertFalse(Tweaks.MONSTER_PLUS.keepApplied)
        assertTrue(Tweaks.HAWKEYE.keepApplied)
        assertTrue(Tweaks.TOUCH_BOOST.keepApplied)
        assertEquals(listOf("gamecube_hawkeye_effective", "vts_game_para_adjust"), Tweaks.watchedSystemKeys)
    }

    @Test
    fun idsResolveForTheFlutterChannel() {
        assertEquals(Tweaks.TOUCH_BOOST, Tweaks.byId("touch_boost"))
        assertEquals(Tweaks.HAWKEYE, Tweaks.byId("hawkeye"))
        assertEquals(null, Tweaks.byId("nope"))
    }
}
