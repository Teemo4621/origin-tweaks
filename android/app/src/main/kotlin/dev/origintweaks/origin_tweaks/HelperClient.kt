package dev.origintweaks.origin_tweaks

import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.util.Log
import java.io.File

object HelperClient {
    const val PACKAGE = "dev.origintweaks.origin_tweaks.helper"

    const val BUNDLED_VERSION = 2L

    private const val TAG = "OriginTweaks"
    private const val ASSET = "helper.apk"
    private val URI: Uri = Uri.parse("content://$PACKAGE.settings")

    fun installedVersion(context: Context): Long? = try {
        context.packageManager.getPackageInfo(PACKAGE, 0).longVersionCode
    } catch (_: PackageManager.NameNotFoundException) {
        null
    }

    fun isReady(context: Context): Boolean = (installedVersion(context) ?: 0L) >= BUNDLED_VERSION

    fun extractApk(context: Context): File {
        val file = File(context.cacheDir, ASSET)
        context.assets.open(ASSET).use { input -> file.outputStream().use { input.copyTo(it) } }
        return file
    }

    fun get(context: Context, key: String): String? = try {
        context.contentResolver.call(URI, "get", key, null)?.getString("value")
    } catch (e: Exception) {
        Log.w(TAG, "helper get $key failed", e)
        null
    }

    fun put(context: Context, key: String, value: String): Boolean = try {
        val extras = Bundle().apply { putString("value", value) }
        context.contentResolver.call(URI, "put", key, extras)?.getBoolean("ok") == true
    } catch (e: Exception) {
        Log.w(TAG, "helper put $key failed", e)
        false
    }
}
