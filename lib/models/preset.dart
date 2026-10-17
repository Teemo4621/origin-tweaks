import '../l10n/gen/app_localizations.dart';

enum Preset {
  off('off'),
  fps90('fps90'),
  fps120('fps120'),
  fps144('fps144');

  const Preset(this.id);

  final String id;

  String label(AppLocalizations l10n) => switch (fps) {
        final fps? => l10n.presetFps(fps),
        null => l10n.presetOff,
      };

  bool get enabled => this != off;

  bool get tested => this == fps144;

  int? get fps => switch (this) {
        off => null,
        fps90 => 90,
        fps120 => 120,
        fps144 => 144,
      };

  static Preset? fromId(String? id) {
    for (final preset in values) {
      if (preset.id == id) return preset;
    }
    return null;
  }
}

enum ApplyResult {
  ok,
  failed,
  blocked,
  noPermission,
  noHelper;

  static ApplyResult fromCode(int? code) =>
      code != null && code >= 0 && code < values.length ? values[code] : failed;

  String message(AppLocalizations l10n, Preset preset) => switch (this) {
        ok => preset.enabled ? l10n.applyEnabled(preset.label(l10n)) : l10n.applyDisabled,
        blocked => l10n.applyBlocked,
        noPermission || noHelper => l10n.applyNotSetUp,
        failed => l10n.applyFailed,
      };
}

class CurrentSetting {
  const CurrentSetting({this.value, this.preset});

  final String? value;

  final Preset? preset;

  Preset? get effective => preset ?? (value == null ? Preset.off : null);

  bool get isCustom => effective == null;
}
