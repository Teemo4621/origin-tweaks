import 'package:flutter/material.dart';

import '../models/preset.dart';

class PresetGrid extends StatelessWidget {
  const PresetGrid({
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
    Widget tile(Preset preset) => Expanded(
          child: _PresetTile(
            preset: preset,
            selected: selected == preset,
            pending: pending == preset,
            onTap: enabled && pending == null ? () => onSelected(preset) : null,
          ),
        );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.5,
      child: Column(
        children: [
          Row(children: [tile(Preset.off), const SizedBox(width: 12), tile(Preset.fps90)]),
          const SizedBox(height: 12),
          Row(children: [tile(Preset.fps120), const SizedBox(width: 12), tile(Preset.fps144)]),
        ],
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({required this.preset, required this.selected, required this.pending, required this.onTap});

  final Preset preset;
  final bool selected;
  final bool pending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    final radius = BorderRadius.circular(20);

    final Widget? badge = switch (preset) {
      Preset.off => null,
      _ when preset.tested => _Badge(
          label: 'ทดสอบแล้ว',
          icon: Icons.verified,
          background: scheme.primary,
          foreground: scheme.onPrimary,
        ),
      _ => _Badge(
          label: 'ยังไม่ทดสอบ',
          icon: Icons.science_outlined,
          background: scheme.surfaceContainerHighest,
          foreground: scheme.onSurfaceVariant,
        ),
    };

    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: selected ? scheme.primaryContainer : scheme.surfaceContainer,
          border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 112),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          preset.enabled ? Icons.speed : Icons.power_settings_new,
                          size: 22,
                          color: selected ? scheme.primary : scheme.onSurfaceVariant,
                        ),
                        const Spacer(),
                        SizedBox.square(
                          dimension: 22,
                          child: pending
                              ? const Padding(
                                  padding: EdgeInsets.all(2),
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                )
                              : AnimatedScale(
                                  scale: selected ? 1 : 0,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutBack,
                                  child: Icon(Icons.check_circle, size: 22, color: scheme.primary),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      preset.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleLarge?.copyWith(color: fg, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    badge ??
                        Text(
                          'คืนค่าเดิมทั้งหมด',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
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

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon, required this.background, required this.foreground});

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
