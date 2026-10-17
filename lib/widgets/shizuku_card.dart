import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../native/native_bridge.dart';
import 'info_card.dart';

(String, String) shizukuCopy(AppLocalizations l10n, ShizukuState state) => switch (state) {
      ShizukuState.ready => (l10n.shizukuReady, l10n.shizukuReadyDetail),
      ShizukuState.noPermission => (l10n.shizukuNoPermission, l10n.shizukuNoPermissionDetail),
      ShizukuState.notRunning => (l10n.shizukuNotRunning, l10n.shizukuNotRunningDetail),
      ShizukuState.notInstalled => (l10n.shizukuNotInstalled, l10n.shizukuNotInstalledDetail),
      ShizukuState.unsupported => (l10n.shizukuUnsupported, l10n.shizukuUnsupportedDetail),
    };

class ShizukuCard extends StatelessWidget {
  const ShizukuCard({super.key, required this.state, required this.onChanged});

  final ShizukuState state;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final ready = state == ShizukuState.ready;
    final (title, detail) = shizukuCopy(l10n, state);

    final action = switch (state) {
      ShizukuState.noPermission => FilledButton.icon(
          icon: const Icon(Icons.lock_open),
          label: Text(l10n.allow),
          onPressed: () async {
            await NativeBridge.requestShizuku();
            onChanged();
          },
        ),
      ShizukuState.notRunning => FilledButton.tonalIcon(
          icon: const Icon(Icons.open_in_new),
          label: Text(l10n.openShizuku),
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
