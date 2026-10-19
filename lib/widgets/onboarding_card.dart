import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../native/native_bridge.dart';
import '../theme.dart';
import 'panel.dart';
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

  static const stepCount = 3;

  static int completedSteps(SetupStatus status) {
    final shizukuOn = status.shizukuUsable || status.ready;
    final granted = status.shizuku == ShizukuState.ready || status.ready;
    return [shizukuOn, granted, status.ready].where((done) => done).length;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shizukuOn = status.shizukuUsable || status.ready;
    final granted = status.shizuku == ShizukuState.ready || status.ready;
    final (_, shizukuDetail) = shizukuCopy(l10n, status.shizuku);
    final done = completedSteps(status);
    final current = (done + 1).clamp(1, stepCount);

    final Widget primary;
    if (status.shizukuUsable) {
      primary = AutoSetupButton(status: status, onChanged: onChanged);
    } else if (status.shizuku == ShizukuState.notRunning) {
      primary = SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: Text(l10n.openShizuku),
          onPressed: () => NativeBridge.openShizuku(),
        ),
      );
    } else {
      primary = SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.refresh),
          label: Text(l10n.checkAgain),
          onPressed: onRefresh,
        ),
      );
    }

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.setupStepOf(current, stepCount), style: AppText.mono.copyWith(fontSize: 12, color: Palette.muted)),
          const SizedBox(height: 6),
          Semantics(
            header: true,
            child: Text(l10n.onboardingTitle, style: AppText.heading.copyWith(fontSize: 22, height: 1.25)),
          ),
          const SizedBox(height: 6),
          Text(l10n.onboardingSubtitle, style: const TextStyle(fontSize: 14, height: 1.55, color: Palette.textSoft)),
          const SizedBox(height: 16),
          SegmentMeter(filled: done, count: stepCount, height: 4),
          const SizedBox(height: 16),
          _Step(done: shizukuOn, text: l10n.onboardingStep1, detail: shizukuDetail),
          _Step(done: granted, text: l10n.onboardingStep2, detail: l10n.onboardingStep2Detail),
          _Step(done: status.ready, text: l10n.onboardingStep3, detail: l10n.onboardingStep3Detail),
          if (status.error != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.onboardingLastError(describeSetupError(l10n, status.error)),
              style: const TextStyle(fontSize: 13, color: Palette.heatText),
            ),
          ],
          const SizedBox(height: 16),
          primary,
          if (onOpenSetup != null)
            Center(
              child: TextButton(onPressed: onOpenSetup, child: Text(l10n.onboardingSetupDetails)),
            ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.done, required this.text, required this.detail});

  final bool done;
  final String text;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(
            dimension: 22,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: done
                  ? const Icon(Icons.check_rounded, key: ValueKey(true), size: 20, color: Palette.accent)
                  : Center(
                      key: const ValueKey(false),
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Palette.muted, width: 1.5),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color: done ? Palette.muted : Palette.text,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: Palette.muted,
                  ),
                ),
                if (!done)
                  Text(detail, style: const TextStyle(fontSize: 12, height: 1.45, color: Palette.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
