package dev.origintweaks.origin_tweaks

import android.content.ComponentName
import android.content.Context
import android.content.ServiceConnection
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.os.PowerManager
import android.util.Log
import rikka.shizuku.Shizuku
import java.util.concurrent.Executors

object ShizukuBridge {
    enum class State(val id: String) {
        NOT_INSTALLED("notInstalled"),
        NOT_RUNNING("notRunning"),
        UNSUPPORTED("unsupported"),
        NO_PERMISSION("noPermission"),
        READY("ready"),
    }

    private const val TAG = "OriginTweaks"
    private const val SHIZUKU_PACKAGE = "moe.shizuku.privileged.api"
    private const val PERMISSION_REQUEST_CODE = 4210
    private const val BIND_TIMEOUT_MS = 5000L

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val pending = ArrayList<(IShellService?) -> Unit>()
    private val permissionCallbacks = ArrayList<(Boolean) -> Unit>()

    private lateinit var appContext: Context
    @Volatile private var service: IShellService? = null
    private var binding = false

    private val bindTimeout = Runnable {
        Log.w(TAG, "Shizuku user service bind timed out")
        flush(null)
    }

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            mainHandler.removeCallbacks(bindTimeout)
            service = if (binder != null && binder.pingBinder()) IShellService.Stub.asInterface(binder) else null
            flush(service)
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            service = null
        }
    }

    private val permissionListener = Shizuku.OnRequestPermissionResultListener { requestCode, grantResult ->
        if (requestCode != PERMISSION_REQUEST_CODE) return@OnRequestPermissionResultListener
        val granted = grantResult == PackageManager.PERMISSION_GRANTED
        val callbacks = synchronized(permissionCallbacks) {
            permissionCallbacks.toList().also { permissionCallbacks.clear() }
        }
        callbacks.forEach { it(granted) }
    }

    @Synchronized
    fun init(context: Context) {
        if (::appContext.isInitialized) return
        appContext = context.applicationContext
        Shizuku.addBinderDeadListener { service = null }
        Shizuku.addRequestPermissionResultListener(permissionListener)
    }

    fun state(): State {
        if (!Shizuku.pingBinder()) {
            return if (isShizukuInstalled()) State.NOT_RUNNING else State.NOT_INSTALLED
        }
        if (Shizuku.isPreV11()) return State.UNSUPPORTED
        return if (Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) State.READY else State.NO_PERMISSION
    }

    fun requestPermission(onResult: (Boolean) -> Unit) {
        when (state()) {
            State.READY -> onResult(true)
            State.NO_PERMISSION -> {
                synchronized(permissionCallbacks) { permissionCallbacks.add(onResult) }
                Shizuku.requestPermission(PERMISSION_REQUEST_CODE)
            }
            else -> onResult(false)
        }
    }

    fun applyPreset(preset: Preset, onDone: (Int) -> Unit) {
        executor.execute {
            val result = FrameGen.apply(appContext, preset)
            if (result != FrameGen.RESULT_OK) Log.w(TAG, "apply $preset failed: $result")
            mainHandler.post { onDone(result) }
        }
    }

    fun applySuperRes(level: Int, onDone: (Int) -> Unit) {
        executor.execute {
            val result = FrameGen.applySuperRes(appContext, level)
            if (result != FrameGen.RESULT_OK) Log.w(TAG, "super resolution $level failed: $result")
            mainHandler.post { onDone(result) }
        }
    }

    fun readSuperRes(onDone: (String?) -> Unit) {
        executor.execute {
            val value = FrameGen.readSuperRes(appContext)
            mainHandler.post { onDone(value) }
        }
    }

    fun readCurrent(onDone: (String?) -> Unit) {
        executor.execute {
            val value = FrameGen.readInterpolation(appContext)
            mainHandler.post { onDone(value) }
        }
    }

    fun autoSetup(onDone: (Map<String, Any?>) -> Unit) {
        use { shell ->
            var error: String? = null
            if (shell == null) {
                error = "shizuku"
            } else {
                val packageName = appContext.packageName
                if (!HelperClient.isReady(appContext)) {
                    val output = runCatching {
                        val apk = HelperClient.extractApk(appContext)
                        ParcelFileDescriptor.open(apk, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
                            shell.installHelper(fd, apk.length())
                        }
                    }.onFailure { Log.w(TAG, "helper install failed", it) }.getOrNull()
                    if (!HelperClient.isReady(appContext)) error = "helper: ${output ?: "no output"}"
                }
                if (!FrameGen.hasSecurePermission(appContext)) {
                    runCatching { shell.grantSecureSettings(packageName) }
                    if (!FrameGen.hasSecurePermission(appContext) && error == null) error = "secure"
                }
                runCatching { shell.grantUsageStats(packageName) }
                runCatching { shell.whitelistDoze(packageName) }
            }
            val status = setupStatus() + ("error" to error)
            mainHandler.post { onDone(status) }
        }
    }

    fun setupStatus(): Map<String, Any?> = mapOf(
        "shizuku" to state().id,
        "helper" to HelperClient.isReady(appContext),
        "secureSettings" to FrameGen.hasSecurePermission(appContext),
        "usageAccess" to ForegroundApp.hasUsageAccess(appContext),
        "battery" to appContext.getSystemService(PowerManager::class.java)
            .isIgnoringBatteryOptimizations(appContext.packageName),
    )

    fun grantUsageStats(onDone: (Boolean) -> Unit) = callBoolean(onDone) {
        it.grantUsageStats(appContext.packageName)
        ForegroundApp.hasUsageAccess(appContext)
    }

    private fun callBoolean(onDone: (Boolean) -> Unit, call: (IShellService) -> Boolean) {
        use { shell ->
            val ok = shell != null && runCatching { call(shell) }.getOrDefault(false)
            mainHandler.post { onDone(ok) }
        }
    }

    private fun use(block: (IShellService?) -> Unit) {
        val current = service
        if (current != null && current.asBinder().pingBinder()) {
            executor.execute { block(current) }
            return
        }
        if (state() != State.READY) {
            executor.execute { block(null) }
            return
        }
        synchronized(pending) {
            pending.add(block)
            if (binding) return
            binding = true
        }
        mainHandler.post {
            try {
                Shizuku.bindUserService(userServiceArgs(), connection)
                mainHandler.postDelayed(bindTimeout, BIND_TIMEOUT_MS)
            } catch (e: Throwable) {
                Log.w(TAG, "bindUserService failed", e)
                flush(null)
            }
        }
    }

    private fun flush(shell: IShellService?) {
        val blocks = synchronized(pending) {
            binding = false
            pending.toList().also { pending.clear() }
        }
        blocks.forEach { block -> executor.execute { block(shell) } }
    }

    private fun userServiceArgs(): Shizuku.UserServiceArgs {
        val debuggable = (appContext.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        return Shizuku.UserServiceArgs(ComponentName(appContext.packageName, ShellUserService::class.java.name))
            .daemon(false)
            .processNameSuffix("shell")
            .debuggable(debuggable)
            .version(6)
    }

    private fun isShizukuInstalled(): Boolean = try {
        appContext.packageManager.getPackageInfo(SHIZUKU_PACKAGE, 0)
        true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }

    fun shizukuLaunchIntent() = appContext.packageManager.getLaunchIntentForPackage(SHIZUKU_PACKAGE)
}
