import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/preset.dart';
import '../theme.dart';

class PresetSelector extends StatelessWidget {
  const PresetSelector({
    super.key,
    required this.selected,
    required this.pending,
    required this.enabled,
    required this.onSelected,
  });

  final Preset? selected;
  final Preset? pending;
  final bool enabled;
  final ValueChanged<Preset> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      label: l10n.homeChooseMode,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Palette.line),
          ),
          child: Row(
            children: [
              for (final preset in Preset.values) ...[
                if (preset != Preset.off) const SizedBox(width: 4),
                Expanded(
                  child: _Segment(
                    preset: preset,
                    selected: selected == preset,
                    pending: pending == preset,
                    onTap: enabled && pending == null ? () => onSelected(preset) : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.preset, required this.selected, required this.pending, required this.onTap});

  final Preset preset;
  final bool selected;
  final bool pending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fps = preset.fps;
    final caption = switch (preset) {
      Preset.off => null,
      _ when preset.tested => l10n.badgeTested,
      _ => l10n.badgeUntested,
    };
    final ink = selected ? Palette.onAccent : Palette.text;
    final captionInk = selected ? Palette.onAccentSoft : Palette.muted;

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      enabled: onTap != null,
      label: [preset.label(l10n), ?caption].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? Palette.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
              height: 56,
              child: Center(
                child: pending
                    ? SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: selected ? Palette.onAccent : Palette.accent,
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            fps == null ? l10n.presetOff : '$fps',
                            maxLines: 1,
                            style: fps == null
                                ? TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: selected ? ink : Palette.textSoft)
                                : AppText.heading.copyWith(
                                    fontSize: 18,
                                    height: 1.2,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                                    color: ink,
                                  ),
                          ),
                          if (caption != null)
                            Text(
                              caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.3,
                                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                                color: captionInk,
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
