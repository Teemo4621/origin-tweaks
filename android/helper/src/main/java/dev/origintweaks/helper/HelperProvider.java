package dev.origintweaks.helper;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.Context;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.provider.Settings;

import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;

public final class HelperProvider extends ContentProvider {
    private static final Set<String> ALLOWED_KEYS = new HashSet<>(Arrays.asList(
            "gamecube_frame_interpolation",
            "vivo_sr_status",
            "nova_memc_status",
            "vivo_fullscreen_flag",
            "memc_main_switch_setting",
            "gamewatch_game_target_fps"));

    @Override
    public boolean onCreate() {
        return true;
    }

    @Override
    public Bundle call(String method, String key, Bundle extras) {
        enforceSameSignature();
        if (key == null || !ALLOWED_KEYS.contains(key)) {
            throw new IllegalArgumentException("Key not allowed: " + key);
        }
        Context context = getContext();
        Bundle result = new Bundle();
        switch (method) {
            case "get":
                result.putString("value", Settings.System.getString(context.getContentResolver(), key));
                return result;
            case "put":
                String value = extras == null ? null : extras.getString("value");
                if (value == null) throw new IllegalArgumentException("Missing value");
                boolean ok = Settings.System.putString(context.getContentResolver(), key, value)
                        && value.equals(Settings.System.getString(context.getContentResolver(), key));
                result.putBoolean("ok", ok);
                return result;
            default:
                throw new IllegalArgumentException("Unknown method: " + method);
        }
    }

    private void enforceSameSignature() {
        Context context = getContext();
        String caller = getCallingPackage();
        if (caller == null || context.getPackageManager().checkSignatures(context.getPackageName(), caller)
                != PackageManager.SIGNATURE_MATCH) {
            throw new SecurityException("Caller not allowed: " + caller);
        }
    }

    @Override
    public Cursor query(Uri uri, String[] projection, String selection, String[] selectionArgs, String sortOrder) {
        return null;
    }

    @Override
    public String getType(Uri uri) {
        return null;
    }

    @Override
    public Uri insert(Uri uri, ContentValues values) {
        return null;
    }

    @Override
    public int delete(Uri uri, String selection, String[] selectionArgs) {
        return 0;
    }

    @Override
    public int update(Uri uri, ContentValues values, String selection, String[] selectionArgs) {
        return 0;
    }
}
