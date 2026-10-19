package dev.origintweaks.origin_tweaks

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class UpdaterTest {
    private fun version(raw: String) = Version.parse(raw)!!

    private fun release(version: String) = Updater.Release(version, "", "", "https://example.invalid/$version.apk", 0, null)

    @Test
    fun ordersVersionsLikeSemver() {
        assertTrue(version("0.1.0-alpha.10") > version("0.1.0-alpha.9"))
        assertTrue(version("0.1.0-beta.1") > version("0.1.0-alpha.9"))
        assertTrue(version("0.1.0") > version("0.1.0-alpha.9"))
        assertTrue(version("0.2.0-alpha.1") > version("0.1.0"))
        assertEquals(0, version("v0.1.0-alpha.4+4").compareTo(version("0.1.0-alpha.4")))
        assertNull(Version.parse("latest"))
    }

    @Test
    fun picksTheNewestNewerRelease() {
        val releases = listOf(release("0.1.0-alpha.3"), release("0.1.0-alpha.5"), release("0.1.0-alpha.4"))
        assertEquals("0.1.0-alpha.5", Updater.pickUpdate("0.1.0-alpha.4", releases)?.version)
        assertNull(Updater.pickUpdate("0.1.0-alpha.5", releases))
    }

    @Test
    fun stableBuildsIgnorePrereleases() {
        val releases = listOf(release("0.2.0-alpha.1"), release("0.1.1"))
        assertEquals("0.1.1", Updater.pickUpdate("0.1.0", releases)?.version)
        assertEquals("0.2.0-alpha.1", Updater.pickUpdate("0.1.0-alpha.9", releases)?.version)
    }
}
