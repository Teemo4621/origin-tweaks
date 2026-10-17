import 'package:flutter/material.dart';

import '../native/native_bridge.dart';
import 'info_card.dart';

(String, String) shizukuCopy(ShizukuState state) => switch (state) {
      ShizukuState.ready => ('Shizuku พร้อมใช้งาน', 'ใช้ให้สิทธิ์ครั้งแรกเท่านั้น หลังจากนั้นปิด Shizuku ได้'),
      ShizukuState.noPermission => ('ยังไม่ได้อนุญาต', 'กดอนุญาตให้แอปใช้ Shizuku'),
      ShizukuState.notRunning => (
          'Shizuku ยังไม่ทำงาน',
          'เปิดแอป Shizuku แล้วกด Start ผ่าน Wireless debugging (ต้องทำใหม่ทุกครั้งที่รีบูต)'
        ),
      ShizukuState.notInstalled => ('ยังไม่ได้ติดตั้ง Shizuku', 'ติดตั้ง Shizuku จาก GitHub หรือ Play Store ก่อน'),
      ShizukuState.unsupported => ('Shizuku เวอร์ชันเก่าเกินไป', 'อัปเดต Shizuku เป็นเวอร์ชัน 11 ขึ้นไป'),
    };

class ShizukuCard extends StatelessWidget {
  const ShizukuCard({super.key, required this.state, required this.onChanged});

  final ShizukuState state;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ready = state == ShizukuState.ready;
    final (title, detail) = shizukuCopy(state);

    final action = switch (state) {
      ShizukuState.noPermission => FilledButton.icon(
          icon: const Icon(Icons.lock_open),
          label: const Text('อนุญาต'),
          onPressed: () async {
            await NativeBridge.requestShizuku();
            onChanged();
          },
        ),
      ShizukuState.notRunning => FilledButton.tonalIcon(
          icon: const Icon(Icons.open_in_new),
          label: const Text('เปิด Shizuku'),
          onPressed: () => NativeBridge.openShizuku(),
        ),
      _ => null,
    };

    return InfoCard(
      icon: ready ? Icons.verified_user_outlined : Icons.adb,
      iconBackground: ready ? scheme.primaryContainer : scheme.tertiaryContainer,
      iconForeground: ready ? scheme.onPrimaryContainer : scheme.onTertiaryContainer,
      title: title,
      body: detail,
      children: [
        if (action != null) Align(alignment: Alignment.centerLeft, child: action),
      ],
    );
  }
}
