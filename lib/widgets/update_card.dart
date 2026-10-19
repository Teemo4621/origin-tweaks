import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../native/native_bridge.dart';
import '../native/update_controller.dart';
import '../theme.dart';
import 'panel.dart';

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

class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key, required this.controller});

  final UpdateController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final update = controller.update;
    if (update == null) return const SizedBox(width: double.infinity);
    final installing = controller.status == UpdateStatus.installing;

    return Panel(
      padding: EdgeInsets.zero,
      radius: 14,
      child: InkWell(
        onTap: installing ? null : () => installUpdate(context, controller),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                const Icon(Icons.download_rounded, size: 20, color: Palette.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.updateBannerTitle(update.version),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        installing ? l10n.updateDownloading : l10n.updateBannerBody,
                        style: const TextStyle(fontSize: 12, color: Palette.muted),
                      ),
                    ],
                  ),
                ),
                if (installing)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else
                  TextButton(
                    onPressed: () => installUpdate(context, controller),
                    child: Text(l10n.updateInstall),
                  ),
              ],
            ),
          ),
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
    final status = switch (controller.status) {
      UpdateStatus.checking => l10n.updateChecking,
      UpdateStatus.upToDate => l10n.updateUpToDate,
      UpdateStatus.failed => l10n.updateCheckFailed,
      UpdateStatus.available || UpdateStatus.installing => l10n.updateAvailableTitle(controller.update!.version),
      UpdateStatus.idle => null,
    };
    final version = controller.currentVersion;
    final hasUpdate = controller.status == UpdateStatus.available || controller.status == UpdateStatus.installing;

    return Panel(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  version.isEmpty ? 'Origin Tweaks' : l10n.aboutVersion(version),
                  style: AppText.mono.copyWith(fontSize: 15, fontWeight: FontWeight.w500, color: Palette.text),
                ),
                if (status != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    status,
                    style: TextStyle(fontSize: 13, color: hasUpdate ? Palette.accent : Palette.muted),
                  ),
                ],
              ],
            ),
          ),
          if (hasUpdate)
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: controller.busy ? null : () => installUpdate(context, controller),
              child: Text(controller.busy ? l10n.updateDownloading : l10n.updateInstall),
            )
          else
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44), backgroundColor: Palette.raised),
              onPressed: controller.busy ? null : controller.check,
              child: Text(controller.status == UpdateStatus.checking ? l10n.updateChecking : l10n.updateCheck),
            ),
        ],
      ),
    );
  }
}
