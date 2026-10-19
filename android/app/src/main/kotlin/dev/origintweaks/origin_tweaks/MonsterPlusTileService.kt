package dev.origintweaks.origin_tweaks

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.widget.Toast

class MonsterPlusTileService : TileService() {
    override fun onTileAdded() {
        ShizukuBridge.init(applicationContext)
        render()
    }

    override fun onStartListening() {
        ShizukuBridge.init(applicationContext)
        render()
    }

    override fun onClick() {
        if (!FrameGen.isReady(this)) {
            render()
            openApp()
            return
        }
        val enable = !ProfileStore(this).isTweakEnabled(Tweaks.MONSTER_PLUS)
        render(pending = enable)
        ShizukuBridge.applyTweak(Tweaks.MONSTER_PLUS, enable) { result ->
            when (result) {
                FrameGen.RESULT_OK -> Unit
                FrameGen.RESULT_BLOCKED -> toast(R.string.error_blocked)
                FrameGen.RESULT_NO_PERMISSION, FrameGen.RESULT_NO_HELPER -> openApp()
                else -> toast(R.string.monster_tile_failed)
            }
            ProfileService.sync(this)
            render()
        }
    }

    private fun render(pending: Boolean? = null) {
        val tile = qsTile ?: return
        val ready = FrameGen.isReady(this)
        val on = ready && (pending ?: ProfileStore(this).isTweakEnabled(Tweaks.MONSTER_PLUS))
        val subtitle = when {
            !ready -> getString(R.string.tile_setup_needed)
            on -> getString(R.string.monster_tile_on)
            else -> getString(R.string.monster_tile_off)
        }
        tile.label = getString(R.string.monster_tile_label)
        tile.subtitle = subtitle
        tile.icon = Icon.createWithResource(this, R.drawable.ic_tile_monster)
        tile.state = when {
            !ready -> Tile.STATE_INACTIVE
            on -> Tile.STATE_ACTIVE
            else -> Tile.STATE_INACTIVE
        }
        tile.contentDescription = getString(R.string.monster_tile_description, subtitle)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            tile.stateDescription = subtitle
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
