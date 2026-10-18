import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';

class SuperResCard extends StatelessWidget {
  const SuperResCard({
    super.key,
    required this.level,
    required this.enabled,
    required this.busy,
    required this.onChanged,
  });

  final int level;
  final bool enabled;
  final bool busy;
  final ValueChanged<int> onChanged;

  static String levelLabel(AppLocalizations l10n, int level) => switch (level) {
        1 => l10n.superResHigh,
        2 => l10n.superResExtreme,
        _ => l10n.superResOff,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.hd_outlined, color: scheme.onSecondaryContainer, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.superResTitle, style: text.titleMedium)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.superResExperimental,
                    style: text.labelSmall?.copyWith(color: scheme.onTertiaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.superResBody, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  for (final value in const [0, 1, 2])
                    ButtonSegment(value: value, label: Text(levelLabel(l10n, value))),
                ],
                selected: {level},
                onSelectionChanged: enabled && !busy ? (selection) => onChanged(selection.first) : null,
              ),
            ),
            SizedBox(
              height: 4,
              child: busy
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(minHeight: 2, color: scheme.primary),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
