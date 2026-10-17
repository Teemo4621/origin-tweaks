package dev.origintweaks.origin_tweaks

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.widget.Toast

class FrameInterpTileService : TileService() {
    private var current: Preset? = null
    private var custom = false

    override fun onTileAdded() {
        ShizukuBridge.init(applicationContext)
        refresh()
    }

    override fun onStartListening() {
        ShizukuBridge.init(applicationContext)
        if (FrameGen.isReady(this)) {
            current?.let { render(it, ready = true, custom = custom) }
        } else {
            render(null, ready = false)
        }
        refresh()
    }

    override fun onClick() {
        if (!FrameGen.isReady(this)) {
            render(null, ready = false)
            openApp()
            return
        }
        val store = ProfileStore(this)
        val foreground = ForegroundApp.current(this)
        val next = (current ?: ForegroundApp.targetPreset(store, foreground)).next()
        current = next
        custom = false
        render(next, ready = true)
        ShizukuBridge.applyPreset(next) { result ->
            when (result) {
                FrameGen.RESULT_OK -> {
                    store.rememberChoice(foreground, next)
                    ProfileService.sync(this)
                    current = next
                    custom = false
                    render(next, ready = true)
                }
                FrameGen.RESULT_BLOCKED -> {
                    toast(R.string.error_blocked)
                    refresh()
                }
                FrameGen.RESULT_NO_PERMISSION, FrameGen.RESULT_NO_HELPER -> {
                    refresh()
                    openApp()
                }
                else -> refresh()
            }
        }
    }

    private fun refresh() {
        if (!FrameGen.isReady(this)) {
            current = null
            custom = false
            render(null, ready = false)
            return
        }
        ShizukuBridge.readCurrent { value ->
            val fromDevice = Preset.fromValue(value)
            current = fromDevice ?: Preset.OFF
            custom = value != null && fromDevice == null
            render(current, ready = true, custom = custom)
        }
    }

    private fun render(preset: Preset?, ready: Boolean, custom: Boolean = false) {
        val tile = qsTile ?: return
        val on = ready && (custom || preset?.enabled == true)
        val label: String
        val subtitle: String
        val stateText: String
        when {
            !ready -> {
                label = getString(R.string.tile_label_setup)
                subtitle = getString(R.string.tile_setup_needed)
                stateText = label
            }
            custom -> {
                label = getString(R.string.tile_label_custom)
                subtitle = getString(R.string.tile_custom)
                stateText = getString(R.string.tile_state_on, subtitle)
            }
            on -> {
                label = preset!!.label
                subtitle = getString(R.string.tile_subtitle_on)
                stateText = getString(R.string.tile_state_on, label)
            }
            else -> {
                label = getString(R.string.tile_label_off)
                subtitle = getString(R.string.tile_subtitle_off)
                stateText = getString(R.string.tile_state_off)
            }
        }
        tile.label = label
        tile.subtitle = subtitle
        tile.icon = Icon.createWithResource(this, if (on) R.drawable.ic_tile_on else R.drawable.ic_tile_off)
        tile.state = if (on) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.contentDescription = getString(R.string.tile_description, stateText)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            tile.stateDescription = stateText
        }
        tile.updateTile()
    }

    private fun toast(message: Int) {
        Toast.makeText(this, message, Toast.LENGTH_LONG).show()
    }

    @SuppressLint("StartActivityAndCollapseDeprecated")
    private fun openApp() {
        val intent = Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(
                PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE),
            )
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
