import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../native/native_bridge.dart';
import '../theme.dart';
import 'panel.dart';

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
    final l10n = AppLocalizations.of(context);

    final items = [
      _Item(done: status.helper, required: true, label: l10n.setupHelper, detail: l10n.setupHelperDetail),
      _Item(done: status.secureSettings, required: true, label: l10n.setupSecure, detail: l10n.setupSecureDetail),
      _Item(
        done: status.usageAccess,
        label: l10n.setupUsage,
        detail: status.ready && !status.usageAccess ? l10n.setupUsageManual : l10n.usageAccessPurpose,
        action: status.usageAccess
            ? null
            : TextButton(onPressed: NativeBridge.openUsageAccessSettings, child: Text(l10n.open)),
      ),
      _Item(done: status.battery, label: l10n.setupBattery, detail: l10n.setupBatteryDetail),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (index, item) in items.indexed) ...[
                if (index > 0) const InsetDivider(indent: 48),
                item,
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (status.complete)
          _RerunButton(status: status, onChanged: onChanged)
        else ...[
          AutoSetupButton(status: status, onChanged: onChanged),
          if (!status.shizukuUsable)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
              child: Text(l10n.setupStartShizukuFirst, style: const TextStyle(fontSize: 13, color: Palette.muted)),
            ),
        ],
      ],
    );
  }
}

class _RerunButton extends StatefulWidget {
  const _RerunButton({required this.status, required this.onChanged});

  final SetupStatus status;
  final ValueChanged<SetupStatus> onChanged;

  @override
  State<_RerunButton> createState() => _RerunButtonState();
}

class _RerunButtonState extends State<_RerunButton> {
  bool _running = false;

  Future<void> _run() async {
    setState(() => _running = true);
    if (widget.status.shizuku == ShizukuState.noPermission) await NativeBridge.requestShizuku();
    final status = await NativeBridge.autoSetup();
    if (!mounted) return;
    setState(() => _running = false);
    widget.onChanged(status);
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(status.ready ? l10n.autoSetupDone : l10n.autoSetupFailed(describeSetupError(l10n, status.error))),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OutlinedButton.icon(
      icon: _running
          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.refresh, size: 18),
      label: Text(_running ? l10n.autoSetupRunning : l10n.autoSetupAgain),
      onPressed: widget.status.shizukuUsable && !_running ? _run : null,
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
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      checked: done,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 20,
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
                    Text(label, style: const TextStyle(fontSize: 15)),
                    Text(detail, style: const TextStyle(fontSize: 12, height: 1.45, color: Palette.muted)),
                  ],
                ),
              ),
              if (required && !done)
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8),
                  child: Tag(label: l10n.requiredBadge, heat: true),
                ),
              ?action,
            ],
          ),
        ),
      ),
    );
  }
}
