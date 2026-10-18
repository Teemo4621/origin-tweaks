package dev.origintweaks.origin_tweaks

import android.Manifest
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val store by lazy { ProfileStore(this) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ShizukuBridge.init(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler(::onMethodCall)
        ProfileService.sync(this)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getShizukuState" -> result.success(ShizukuBridge.state().id)
            "requestShizuku" -> ShizukuBridge.requestPermission { result.success(it) }
            "openShizuku" -> result.success(launch(ShizukuBridge.shizukuLaunchIntent()))
            "getCurrent" -> ShizukuBridge.readCurrent { value ->
                result.success(mapOf("value" to value, "presetId" to Preset.fromValue(value)?.id))
            }
            "applyPreset" -> {
                val preset = Preset.fromId(call.argument<String>("id"))
                if (preset == null) {
                    result.error("bad_preset", "Unknown preset", null)
                } else {
                    ShizukuBridge.applyPreset(preset) { code ->
                        if (code == FrameGen.RESULT_OK) {
                            store.manualPreset = preset
                            ProfileService.sync(this)
                        }
                        result.success(code)
                    }
                }
            }
            "getManualPreset" -> result.success(store.manualPreset.id)
            "getSuperRes" -> ShizukuBridge.readSuperRes { value ->
                result.success(mapOf("level" to store.superResLevel, "value" to value))
            }
            "setSuperRes" -> ShizukuBridge.applySuperRes(call.argument<Int>("level") ?: -1) { result.success(it) }
            "getSetupStatus" -> result.success(ShizukuBridge.setupStatus())
            "autoSetup" -> ShizukuBridge.autoSetup { status ->
                ProfileService.sync(this)
                result.success(status)
            }
            "listApps" -> background(result) { listApps() }
            "getAppIcon" -> background(result) { appIcon(call.argument<String>("package")) }
            "getProfiles" -> result.success(store.profiles().mapValues { it.value.id })
            "setProfile" -> {
                val packageName = call.argument<String>("package")
                if (!ShellUserService.isValidPackage(packageName)) {
                    result.error("bad_package", "Invalid package name", null)
                } else {
                    store.setProfile(packageName!!, Preset.fromId(call.argument<String>("id")))
                    ProfileService.sync(this)
                    result.success(true)
                }
            }
            "isProfileServiceEnabled" -> result.success(store.profileServiceEnabled)
            "setProfileServiceEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") == true
                store.profileServiceEnabled = enabled
                if (enabled) requestNotificationPermission()
                ProfileService.sync(this)
                result.success(true)
            }
            "hasUsageAccess" -> result.success(ForegroundApp.hasUsageAccess(this))
            "grantUsageAccess" -> ShizukuBridge.grantUsageStats { result.success(it) }
            "openUsageAccessSettings" -> result.success(
                launch(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS, Uri.parse("package:$packageName"))) ||
                    launch(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)),
            )
            else -> result.notImplemented()
        }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        ioExecutor.execute {
            val value = runCatching(work)
            mainHandler.post {
                value.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { result.error("native_error", it.message, null) },
                )
            }
        }
    }

    private fun listApps(): List<Map<String, Any>> {
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return packageManager.queryIntentActivities(launcherIntent, 0)
            .map { it.activityInfo.applicationInfo }
            .distinctBy { it.packageName }
            .filter { it.packageName != packageName }
            .map { info ->
                mapOf(
                    "package" to info.packageName,
                    "label" to packageManager.getApplicationLabel(info).toString(),
                    "isGame" to (info.category == ApplicationInfo.CATEGORY_GAME),
                )
            }
    }

    private fun appIcon(packageName: String?): ByteArray? {
        if (packageName == null) return null
        val drawable = packageManager.getApplicationIcon(packageName)
        val bitmap = Bitmap.createBitmap(ICON_SIZE, ICON_SIZE, Bitmap.Config.ARGB_8888)
        drawable.setBounds(0, 0, ICON_SIZE, ICON_SIZE)
        drawable.draw(Canvas(bitmap))
        return ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            out.toByteArray()
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_REQUEST_CODE)
        }
    }

    private fun launch(intent: Intent?): Boolean {
        if (intent == null) return false
        return try {
            startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (_: Exception) {
            false
        }
    }

    companion object {
        private const val CHANNEL = "origin_tweaks/native"
        private const val ICON_SIZE = 96
        private const val NOTIFICATION_REQUEST_CODE = 1001
    }
}
