enum Preset {
  off('off', 'ปิด'),
  fps90('fps90', '90 FPS'),
  fps120('fps120', '120 FPS'),
  fps144('fps144', '144 FPS');

  const Preset(this.id, this.label);

  final String id;
  final String label;

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

  String messageFor(Preset preset) => switch (this) {
        ok => preset.enabled ? 'เปิด ${preset.label} แล้ว' : 'ปิดแทรกเฟรมแล้ว',
        blocked => 'ระบบไม่ยอมรับค่าที่เขียน (ค่าถูกรีเซ็ตทันที)',
        noPermission || noHelper => 'ยังตั้งค่าครั้งแรกไม่เสร็จ',
        failed => 'ตั้งค่าไม่สำเร็จ',
      };
}

class CurrentSetting {
  const CurrentSetting({this.value, this.preset});

  final String? value;

  final Preset? preset;

  Preset? get effective => preset ?? (value == null ? Preset.off : null);

  bool get isCustom => effective == null;
}
