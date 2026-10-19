package dev.origintweaks.origin_tweaks

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import android.util.Log
import org.json.JSONArray
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

object Updater {
    const val RELEASES_URL = "https://api.github.com/repos/Teemo4621/origin-tweaks/releases?per_page=15"

    const val INSTALL_STARTED = 0
    const val INSTALL_DOWNLOAD_FAILED = 1
    const val INSTALL_CHECKSUM_FAILED = 2
    const val INSTALL_FAILED = 3
    const val INSTALL_NEEDS_PERMISSION = 4

    private const val TAG = "OriginTweaks"
    private const val APK_SUFFIX = "-arm64.apk"
    private const val TIMEOUT_MS = 15_000

    data class Release(
        val version: String,
        val notes: String,
        val pageUrl: String,
        val apkUrl: String,
        val apkSize: Long,
        val checksumUrl: String?,
    )

    fun currentVersion(context: Context): String =
        context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: "0.0.0"

    @Volatile var latest: Release? = null
        private set

    fun findUpdate(context: Context): Release? {
        val releases = parseReleases(JSONArray(httpGet(RELEASES_URL)))
        return pickUpdate(currentVersion(context), releases).also { latest = it }
    }

    fun pickUpdate(current: String, releases: List<Release>): Release? {
        val currentVersion = Version.parse(current) ?: return null
        return releases
            .mapNotNull { release -> Version.parse(release.version)?.let { it to release } }
            .filter { (version, _) -> currentVersion.isPrerelease || !version.isPrerelease }
            .filter { (version, _) -> version > currentVersion }
            .maxByOrNull { (version, _) -> version }
            ?.second
    }

    fun parseReleases(json: JSONArray): List<Release> = (0 until json.length()).mapNotNull { index ->
        val release = json.getJSONObject(index)
        if (release.optBoolean("draft")) return@mapNotNull null
        val assets = release.optJSONArray("assets") ?: JSONArray()
        val assetList = (0 until assets.length()).map { assets.getJSONObject(it) }
        val apk = assetList.firstOrNull { it.optString("name").endsWith(APK_SUFFIX) } ?: return@mapNotNull null
        val checksum = assetList.firstOrNull { it.optString("name") == apk.optString("name") + ".sha256" }
        Release(
            version = release.optString("tag_name").removePrefix("v"),
            notes = release.optString("body"),
            pageUrl = release.optString("html_url"),
            apkUrl = apk.optString("browser_download_url"),
            apkSize = apk.optLong("size"),
            checksumUrl = checksum?.optString("browser_download_url"),
        )
    }

    fun install(context: Context, release: Release): Int {
        val dir = File(context.cacheDir, "updates").apply { deleteRecursively(); mkdirs() }
        val apk = File(dir, "update.apk")
        try {
            download(release.apkUrl, apk)
        } catch (e: IOException) {
            Log.w(TAG, "update download failed", e)
            return INSTALL_DOWNLOAD_FAILED
        }
        val checksumUrl = release.checksumUrl
        if (checksumUrl != null) {
            val expected = runCatching { httpGet(checksumUrl).trim().split(Regex("\\s+")).first().lowercase() }
                .getOrNull()
            if (expected == null || expected != sha256(apk)) {
                Log.w(TAG, "update checksum mismatch: expected $expected")
                apk.delete()
                return INSTALL_CHECKSUM_FAILED
            }
        }
        return try {
            commitSession(context, apk)
            INSTALL_STARTED
        } catch (e: Exception) {
            Log.w(TAG, "update install failed", e)
            INSTALL_FAILED
        }
    }

    private fun commitSession(context: Context, apk: File) {
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply {
            setAppPackageName(context.packageName)
            setSize(apk.length())
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_REQUIRED)
            }
        }
        val sessionId = installer.createSession(params)
        installer.openSession(sessionId).use { session ->
            apk.inputStream().use { input ->
                session.openWrite("base.apk", 0, apk.length()).use { output ->
                    input.copyTo(output)
                    session.fsync(output)
                }
            }
            val intent = Intent(context, UpdateInstallReceiver::class.java)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
            val pending = PendingIntent.getBroadcast(context, sessionId, intent, flags)
            session.commit(pending.intentSender)
        }
        apk.delete()
    }

    private fun httpGet(url: String): String {
        val connection = open(url)
        try {
            if (connection.responseCode !in 200..299) throw IOException("HTTP ${connection.responseCode} for $url")
            return connection.inputStream.bufferedReader().use { it.readText() }
        } finally {
            connection.disconnect()
        }
    }

    private fun download(url: String, target: File) {
        val connection = open(url)
        try {
            if (connection.responseCode !in 200..299) throw IOException("HTTP ${connection.responseCode} for $url")
            connection.inputStream.use { input -> target.outputStream().use { input.copyTo(it) } }
        } finally {
            connection.disconnect()
        }
    }

    private fun open(url: String): HttpURLConnection =
        (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = TIMEOUT_MS
            readTimeout = TIMEOUT_MS
            instanceFollowRedirects = true
            setRequestProperty("Accept", "application/vnd.github+json")
            setRequestProperty("User-Agent", "OriginTweaks-Updater")
        }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    fun Release.toMap(): Map<String, Any?> = mapOf(
        "version" to version,
        "notes" to notes,
        "pageUrl" to pageUrl,
        "size" to apkSize,
    )
}

class Version private constructor(private val core: List<Int>, private val prerelease: List<String>) : Comparable<Version> {
    val isPrerelease: Boolean get() = prerelease.isNotEmpty()

    override fun compareTo(other: Version): Int {
        for (i in 0 until maxOf(core.size, other.core.size)) {
            val diff = core.getOrElse(i) { 0 }.compareTo(other.core.getOrElse(i) { 0 })
            if (diff != 0) return diff
        }
        if (prerelease.isEmpty() || other.prerelease.isEmpty()) {
            return other.prerelease.size.coerceAtMost(1) - prerelease.size.coerceAtMost(1)
        }
        for (i in 0 until minOf(prerelease.size, other.prerelease.size)) {
            val a = prerelease[i]
            val b = other.prerelease[i]
            val aNum = a.toIntOrNull()
            val bNum = b.toIntOrNull()
            val diff = when {
                aNum != null && bNum != null -> aNum.compareTo(bNum)
                aNum != null -> -1
                bNum != null -> 1
                else -> a.compareTo(b)
            }
            if (diff != 0) return diff
        }
        return prerelease.size.compareTo(other.prerelease.size)
    }

    companion object {
        fun parse(raw: String): Version? {
            val text = raw.trim().removePrefix("v").substringBefore('+')
            val coreText = text.substringBefore('-')
            val core = coreText.split('.').map { it.toIntOrNull() ?: return null }
            if (core.isEmpty()) return null
            val prerelease = if ('-' in text) text.substringAfter('-').split('.').filter { it.isNotEmpty() } else emptyList()
            return Version(core, prerelease)
        }
    }
}
