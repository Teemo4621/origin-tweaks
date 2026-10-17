import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../native/native_bridge.dart';

class AutoSetupButton extends StatefulWidget {
  const AutoSetupButton({super.key, required this.status, required this.onChanged});

  final SetupStatus status;
  final ValueChanged<SetupStatus> onChanged;

  @override
  State<AutoSetupButton> createState() => _AutoSetupButtonState();
}

class _AutoSetupButtonState extends State<AutoSetupButton> {
  bool _running = false;

  Future<void> _run() async {
    setState(() => _running = true);
    if (widget.status.shizuku == ShizukuState.noPermission) await NativeBridge.requestShizuku();
    final status = await NativeBridge.autoSetup();
    if (!mounted) return;
    setState(() => _running = false);
    widget.onChanged(status);
    final l10n = AppLocalizations.of(context);
    final String message;
    if (!status.ready) {
      message = l10n.autoSetupFailed(describeSetupError(l10n, status.error));
    } else if (!status.usageAccess) {
      message = l10n.autoSetupUsageLeft;
      await NativeBridge.openUsageAccessSettings();
    } else {
      message = l10n.autoSetupDone;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        icon: _running
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : const Icon(Icons.auto_fix_high),
        label: Text(_running ? l10n.autoSetupRunning : l10n.autoSetup),
        onPressed: widget.status.shizukuUsable && !_running ? _run : null,
      ),
    );
  }
}

String describeSetupError(AppLocalizations l10n, String? error) {
  if (error == null) return l10n.setupErrorUnknown;
  if (error == 'shizuku') return l10n.setupErrorShizuku;
  if (error == 'secure') return l10n.setupErrorSecure;
  if (error.startsWith('helper')) return l10n.setupErrorHelper(error);
  return error;
}

class SetupCard extends StatelessWidget {
  const SetupCard({super.key, required this.status, required this.onChanged});

  final SetupStatus status;
  final ValueChanged<SetupStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final done = status.doneCount;
    const total = SetupStatus.totalSteps;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(status.complete ? l10n.setupComplete : l10n.setupFirstTime, style: text.titleMedium),
                ),
                Text('$done/$total', style: text.labelLarge?.copyWith(color: scheme.primary)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: done / total),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _Item(
              done: status.helper,
              required: true,
              label: l10n.setupHelper,
              detail: l10n.setupHelperDetail,
            ),
            _Item(
              done: status.secureSettings,
              required: true,
              label: l10n.setupSecure,
              detail: l10n.setupSecureDetail,
            ),
            _Item(
              done: status.usageAccess,
              label: l10n.setupUsage,
              detail: status.ready && !status.usageAccess
                  ? l10n.setupUsageManual
                  : l10n.usageAccessPurpose,
              action: status.usageAccess
                  ? null
                  : TextButton(onPressed: NativeBridge.openUsageAccessSettings, child: Text(l10n.open)),
            ),
            _Item(
              done: status.battery,
              label: l10n.setupBattery,
              detail: l10n.setupBatteryDetail,
            ),
            if (!status.complete) ...[
              const SizedBox(height: 16),
              AutoSetupButton(status: status, onChanged: onChanged),
              if (!status.shizukuUsable)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.setupStartShizukuFirst,
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.done,
    required this.label,
    required this.detail,
    this.required = false,
    this.action,
  });

  final bool done;
  final bool required;
  final String label;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              key: ValueKey(done),
              size: 24,
              color: done ? scheme.primary : scheme.outline,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodyLarge),
                Text(detail, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (required && !done)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(AppLocalizations.of(context).requiredBadge, style: text.labelSmall?.copyWith(color: scheme.onTertiaryContainer)),
            ),
          ?action,
        ],
      ),
    );
  }
}
