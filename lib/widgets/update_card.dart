import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../native/native_bridge.dart';
import '../native/update_controller.dart';
import 'info_card.dart';

String installMessage(AppLocalizations l10n, InstallResult result) => switch (result) {
      InstallResult.started => l10n.updateStarted,
      InstallResult.needsPermission => l10n.updateNeedsPermission,
      InstallResult.downloadFailed => l10n.updateDownloadFailed,
      InstallResult.checksumFailed => l10n.updateChecksumFailed,
      InstallResult.failed => l10n.updateFailed,
    };

Future<void> installUpdate(BuildContext context, UpdateController controller) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final result = await controller.install();
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(installMessage(l10n, result))));
}

class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key, required this.controller});

  final UpdateController controller;

  static const _maxNoteLines = 4;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final update = controller.update;
    if (update == null) return const SizedBox(width: double.infinity);
    final installing = controller.status == UpdateStatus.installing;
    final notes = update.notes
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .take(_maxNoteLines)
        .join('\n');

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(icon: Icons.system_update_outlined, background: scheme.primary, foreground: scheme.onPrimary),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    l10n.updateAvailableTitle(update.version),
                    style: text.titleMedium?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                ),
              ],
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                notes,
                maxLines: _maxNoteLines,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: scheme.onPrimaryContainer),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton(onPressed: NativeBridge.openReleasePage, child: Text(l10n.updateDetails)),
                FilledButton.icon(
                  onPressed: installing ? null : () => installUpdate(context, controller),
                  icon: installing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download),
                  label: Text(installing ? l10n.updateDownloading : l10n.updateInstall),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AboutCard extends StatelessWidget {
  const AboutCard({super.key, required this.controller});

  final UpdateController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final status = switch (controller.status) {
      UpdateStatus.checking => l10n.updateChecking,
      UpdateStatus.upToDate => l10n.updateUpToDate,
      UpdateStatus.failed => l10n.updateCheckFailed,
      UpdateStatus.available || UpdateStatus.installing => l10n.updateAvailableTitle(controller.update!.version),
      UpdateStatus.idle => null,
    };
    final version = controller.currentVersion;

    return InfoCard(
      icon: Icons.info_outline,
      iconBackground: scheme.surfaceContainerHighest,
      iconForeground: scheme.onSurfaceVariant,
      title: version.isEmpty ? 'Origin Tweaks' : 'Origin Tweaks · ${l10n.aboutVersion(version)}',
      body: status,
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: controller.status == UpdateStatus.available || controller.status == UpdateStatus.installing
              ? FilledButton.icon(
                  onPressed: controller.busy ? null : () => installUpdate(context, controller),
                  icon: const Icon(Icons.download),
                  label: Text(controller.busy ? l10n.updateDownloading : l10n.updateInstall),
                )
              : OutlinedButton.icon(
                  onPressed: controller.busy ? null : controller.check,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.updateCheck),
                ),
        ),
      ],
    );
  }
}
