package dev.origintweaks.origin_tweaks

import android.os.ParcelFileDescriptor
import android.util.Log
import java.util.concurrent.TimeUnit
import kotlin.system.exitProcess

class ShellUserService : IShellService.Stub() {
    override fun destroy() {
        exitProcess(0)
    }

    override fun grantSecureSettings(packageName: String?): Boolean {
        if (!isValidPackage(packageName)) return false
        return run(PM, "grant", packageName!!, "android.permission.WRITE_SECURE_SETTINGS") != null
    }

    override fun installHelper(apk: ParcelFileDescriptor?, size: Long): String? {
        if (apk == null || size <= 0) return null
        return try {
            val process = ProcessBuilder(
                PM, "install", "-r", "-t", "--bypass-low-target-sdk-block", "-S", size.toString(),
            ).redirectErrorStream(true).start()
            ParcelFileDescriptor.AutoCloseInputStream(apk).use { input ->
                process.outputStream.use { input.copyTo(it) }
            }
            val output = process.inputStream.bufferedReader().use { it.readText() }.trim()
            if (!process.waitFor(60, TimeUnit.SECONDS)) {
                process.destroy()
                return null
            }
            Log.i(TAG, "pm install: $output")
            output
        } catch (e: Exception) {
            Log.w(TAG, "installHelper failed", e)
            null
        }
    }

    override fun grantUsageStats(packageName: String?): Boolean {
        if (!isValidPackage(packageName)) return false
        return run(APPOPS, "set", packageName!!, "GET_USAGE_STATS", "allow") != null
    }

    override fun whitelistDoze(packageName: String?): Boolean {
        if (!isValidPackage(packageName)) return false
        return run(CMD, "deviceidle", "whitelist", "+$packageName") != null
    }

    override fun setFixedPerformance(enabled: Boolean): String? =
        run(CMD, "power", "set-fixed-performance-mode-enabled", enabled.toString())

    private fun run(vararg command: String): String? = try {
        val process = ProcessBuilder(*command).redirectErrorStream(true).start()
        val output = process.inputStream.bufferedReader().use { it.readText() }.trim()
        if (!process.waitFor(10, TimeUnit.SECONDS)) {
            process.destroy()
            Log.w(TAG, "timeout: ${command.joinToString(" ")}")
            null
        } else if (process.exitValue() != 0) {
            Log.w(TAG, "exit ${process.exitValue()}: ${command.joinToString(" ")} -> $output")
            null
        } else {
            output
        }
    } catch (e: Exception) {
        Log.w(TAG, "failed: ${command.joinToString(" ")}", e)
        null
    }

    companion object {
        private const val TAG = "OriginTweaksShell"
        private const val PM = "/system/bin/pm"
        private const val APPOPS = "/system/bin/appops"
        private const val CMD = "/system/bin/cmd"
        private val PACKAGE_PATTERN = Regex("^[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z0-9_]+)+$")

        fun isValidPackage(name: String?): Boolean = name != null && PACKAGE_PATTERN.matches(name)
    }
}
