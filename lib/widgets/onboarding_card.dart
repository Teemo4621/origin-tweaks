import 'package:flutter/material.dart';

import '../native/native_bridge.dart';
import 'info_card.dart';
import 'setup_card.dart';
import 'shizuku_card.dart';

class OnboardingCard extends StatelessWidget {
  const OnboardingCard({
    super.key,
    required this.status,
    required this.onChanged,
    required this.onRefresh,
    this.onOpenSetup,
  });

  final SetupStatus status;
  final ValueChanged<SetupStatus> onChanged;
  final VoidCallback onRefresh;
  final VoidCallback? onOpenSetup;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final shizukuOn = status.shizukuUsable || status.ready;
    final granted = status.shizuku == ShizukuState.ready || status.ready;
    final (_, shizukuDetail) = shizukuCopy(status.shizuku);

    final Widget primary;
    if (status.shizukuUsable) {
      primary = AutoSetupButton(status: status, onChanged: onChanged);
    } else if (status.shizuku == ShizukuState.notRunning) {
      primary = SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: const Text('เปิด Shizuku'),
          onPressed: () => NativeBridge.openShizuku(),
        ),
      );
    } else {
      primary = SizedBox(
        width: double.infinity,
        child: FilledButton.tonalIcon(
          icon: const Icon(Icons.refresh),
          label: const Text('ตรวจอีกครั้ง'),
          onPressed: onRefresh,
        ),
      );
    }

    return Card(
      color: scheme.secondaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(
                  icon: Icons.rocket_launch_outlined,
                  background: scheme.primary,
                  foreground: scheme.onPrimary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('เริ่มต้นใช้งาน', style: text.titleLarge),
                      Text(
                        'ตั้งค่าครั้งเดียวผ่าน Shizuku แล้วใช้แทรกเฟรมได้ตลอด',
                        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            NumberedStep(
              number: 1,
              done: shizukuOn,
              text: 'ติดตั้งและเปิด Shizuku',
              detail: shizukuDetail,
            ),
            NumberedStep(
              number: 2,
              done: granted,
              text: 'อนุญาตให้ Origin Tweaks ใช้ Shizuku',
              detail: 'ระบบจะถามเมื่อกดตั้งค่าอัตโนมัติ',
            ),
            NumberedStep(
              number: 3,
              done: status.ready,
              text: 'กด "ตั้งค่าอัตโนมัติ"',
              detail: 'แอปจะติดตั้งตัวช่วยและให้สิทธิ์ที่จำเป็นให้เอง',
            ),
            if (status.error != null) ...[
              const SizedBox(height: 8),
              Text(
                'ครั้งก่อนไม่สำเร็จ: ${describeSetupError(status.error)}',
                style: text.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
            const SizedBox(height: 16),
            primary,
            if (onOpenSetup != null)
              Center(
                child: TextButton(
                  onPressed: onOpenSetup,
                  child: const Text('ดูรายละเอียดการตั้งค่า'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
