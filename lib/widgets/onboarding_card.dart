import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    final shizukuOn = status.shizukuUsable || status.ready;
    final granted = status.shizuku == ShizukuState.ready || status.ready;
    final (_, shizukuDetail) = shizukuCopy(l10n, status.shizuku);

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
        child: FilledButton.tonalIcon(
          icon: const Icon(Icons.refresh),
          label: Text(l10n.checkAgain),
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
                      Text(l10n.onboardingTitle, style: text.titleLarge),
                      Text(
                        l10n.onboardingSubtitle,
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
              text: l10n.onboardingStep1,
              detail: shizukuDetail,
            ),
            NumberedStep(
              number: 2,
              done: granted,
              text: l10n.onboardingStep2,
              detail: l10n.onboardingStep2Detail,
            ),
            NumberedStep(
              number: 3,
              done: status.ready,
              text: l10n.onboardingStep3,
              detail: l10n.onboardingStep3Detail,
            ),
            if (status.error != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.onboardingLastError(describeSetupError(l10n, status.error)),
                style: text.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
            const SizedBox(height: 16),
            primary,
            if (onOpenSetup != null)
              Center(
                child: TextButton(
                  onPressed: onOpenSetup,
                  child: Text(l10n.onboardingSetupDetails),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
