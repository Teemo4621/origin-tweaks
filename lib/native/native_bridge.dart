import 'package:flutter/services.dart';

import '../models/preset.dart';

enum ShizukuState {
  notInstalled,
  notRunning,
  unsupported,
  noPermission,
  ready;

  static ShizukuState fromId(String? id) =>
      values.firstWhere((s) => s.name == id, orElse: () => notRunning);
}

class SetupStatus {
  const SetupStatus({
    this.shizuku = ShizukuState.notRunning,
    this.helper = false,
    this.secureSettings = false,
    this.usageAccess = false,
    this.battery = false,
    this.error,
  });

  factory SetupStatus.fromMap(Map<String, Object?> map) => SetupStatus(
        shizuku: ShizukuState.fromId(map['shizuku'] as String?),
        helper: map['helper'] as bool? ?? false,
        secureSettings: map['secureSettings'] as bool? ?? false,
        usageAccess: map['usageAccess'] as bool? ?? false,
        battery: map['battery'] as bool? ?? false,
        error: map['error'] as String?,
      );

  final ShizukuState shizuku;

  final bool helper;
  final bool secureSettings;
  final bool usageAccess;
  final bool battery;

  final String? error;

  bool get ready => helper && secureSettings;

  bool get complete => ready && usageAccess && battery;

  bool get shizukuUsable => shizuku == ShizukuState.ready || shizuku == ShizukuState.noPermission;

  int get doneCount => [helper, secureSettings, usageAccess, battery].where((done) => done).length;

  static const totalSteps = 4;
}

class AppEntry {
  const AppEntry({required this.packageName, required this.label, required this.isGame});

  final String packageName;
  final String label;
  final bool isGame;
}

class UpdateInfo {
  const UpdateInfo({required this.version, this.notes = '', this.pageUrl = '', this.size = 0});

  factory UpdateInfo.fromMap(Map<String, Object?> map) => UpdateInfo(
        version: map['version'] as String? ?? '',
        notes: map['notes'] as String? ?? '',
        pageUrl: map['pageUrl'] as String? ?? '',
        size: (map['size'] as num?)?.toInt() ?? 0,
      );

  final String version;
  final String notes;
  final String pageUrl;
  final int size;
}

enum InstallResult {
  started,
  downloadFailed,
  checksumFailed,
  failed,
  needsPermission;

  static InstallResult fromCode(int? code) => switch (code) {
        0 => started,
        1 => downloadFailed,
        2 => checksumFailed,
        4 => needsPermission,
        _ => failed,
      };
}

class NativeBridge {
  NativeBridge._();

  static const _channel = MethodChannel('origin_tweaks/native');
  static final Map<String, Future<Uint8List?>> _iconCache = {};

  static Future<ShizukuState> shizukuState() async =>
      ShizukuState.fromId(await _channel.invokeMethod<String>('getShizukuState'));

  static Future<bool> requestShizuku() async =>
      await _channel.invokeMethod<bool>('requestShizuku') ?? false;

  static Future<bool> openShizuku() async => await _channel.invokeMethod<bool>('openShizuku') ?? false;

  static Future<CurrentSetting> current() async {
    final map = await _channel.invokeMapMethod<String, Object?>('getCurrent') ?? const {};
    return CurrentSetting(
      value: map['value'] as String?,
      preset: Preset.fromId(map['presetId'] as String?),
    );
  }

  static Future<ApplyResult> applyPreset(Preset preset) async =>
      ApplyResult.fromCode(await _channel.invokeMethod<int>('applyPreset', {'id': preset.id}));

  static Future<int> superResLevel() async {
    final map = await _channel.invokeMapMethod<String, Object?>('getSuperRes') ?? const {};
    return map['level'] as int? ?? 0;
  }

  static Future<ApplyResult> setSuperRes(int level) async =>
      ApplyResult.fromCode(await _channel.invokeMethod<int>('setSuperRes', {'level': level}));

  static Future<SetupStatus> setupStatus() async =>
      SetupStatus.fromMap(await _channel.invokeMapMethod<String, Object?>('getSetupStatus') ?? const {});

  static Future<SetupStatus> autoSetup() async =>
      SetupStatus.fromMap(await _channel.invokeMapMethod<String, Object?>('autoSetup') ?? const {});

  static Future<Preset> manualPreset() async =>
      Preset.fromId(await _channel.invokeMethod<String>('getManualPreset')) ?? Preset.off;

  static Future<List<AppEntry>> listApps() async {
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>('listApps') ?? const [];
    return raw
        .map((m) => AppEntry(
              packageName: m['package'] as String,
              label: m['label'] as String,
              isGame: m['isGame'] as bool? ?? false,
            ))
        .toList();
  }

  static Future<Uint8List?> appIcon(String packageName) => _iconCache.putIfAbsent(
        packageName,
        () => _channel
            .invokeMethod<Uint8List>('getAppIcon', {'package': packageName})
            .catchError((Object _) => null),
      );

  static Future<Map<String, Preset>> profiles() async {
    final raw = await _channel.invokeMapMethod<String, String>('getProfiles') ?? const {};
    return {
      for (final entry in raw.entries) entry.key: ?Preset.fromId(entry.value),
    };
  }

  static Future<void> setProfile(String packageName, Preset? preset) =>
      _channel.invokeMethod('setProfile', {'package': packageName, 'id': preset?.id});

  static Future<bool> isProfileServiceEnabled() async =>
      await _channel.invokeMethod<bool>('isProfileServiceEnabled') ?? false;

  static Future<void> setProfileServiceEnabled(bool enabled) =>
      _channel.invokeMethod('setProfileServiceEnabled', {'enabled': enabled});

  static Future<bool> hasUsageAccess() async => await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;

  static Future<bool> grantUsageAccess() async =>
      await _channel.invokeMethod<bool>('grantUsageAccess') ?? false;

  static Future<void> openUsageAccessSettings() => _channel.invokeMethod('openUsageAccessSettings');

  static Future<String> appVersion() async => await _channel.invokeMethod<String>('getAppVersion') ?? '';

  static Future<UpdateInfo?> checkUpdate() async {
    final map = await _channel.invokeMapMethod<String, Object?>('checkUpdate');
    return map == null ? null : UpdateInfo.fromMap(map);
  }

  static Future<InstallResult> installUpdate() async =>
      InstallResult.fromCode(await _channel.invokeMethod<int>('installUpdate'));

  static Future<void> openReleasePage() => _channel.invokeMethod('openReleasePage');
}
