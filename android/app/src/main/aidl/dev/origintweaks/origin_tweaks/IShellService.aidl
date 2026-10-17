package dev.origintweaks.origin_tweaks;

interface IShellService {
    void destroy() = 16777114;

    boolean grantSecureSettings(String packageName) = 1;

    String installHelper(in ParcelFileDescriptor apk, long size) = 2;

    boolean grantUsageStats(String packageName) = 3;

    boolean whitelistDoze(String packageName) = 4;
}
