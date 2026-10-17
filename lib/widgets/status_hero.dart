import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/preset.dart';

class StatusHero extends StatelessWidget {
  const StatusHero({super.key, required this.current, required this.loaded, required this.busy});

  final CurrentSetting current;
  final bool loaded;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final preset = current.effective;
    final active = preset?.enabled ?? false;
    final custom = current.isCustom;
    final fg = active ? scheme.onPrimary : scheme.onSurface;
    final muted = active ? scheme.onPrimary.withValues(alpha: 0.8) : scheme.onSurfaceVariant;

    final (pill, caption) = !loaded
        ? (l10n.heroLoading, l10n.heroLoadingCaption)
        : active
            ? (l10n.heroActive, l10n.heroActiveCaption)
            : custom
                ? (l10n.heroCustom, l10n.heroCustomCaption)
                : (l10n.heroOff, l10n.heroOffCaption);

    final Widget headline;
    if (!loaded) {
      headline = Text('—', key: const ValueKey('loading'), style: text.displayMedium?.copyWith(color: fg));
    } else if (preset?.fps case final fps?) {
      headline = Row(
        key: ValueKey(preset),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('$fps', style: text.displayLarge?.copyWith(color: fg, fontWeight: FontWeight.w700, height: 1)),
          const SizedBox(width: 8),
          Text('FPS', style: text.headlineSmall?.copyWith(color: muted, fontWeight: FontWeight.w600)),
        ],
      );
    } else if (custom) {
      headline = Text(l10n.heroCustom,
          key: const ValueKey('custom'), style: text.headlineLarge?.copyWith(color: fg, fontWeight: FontWeight.w600));
    } else {
      headline = Text(l10n.presetOff,
          key: const ValueKey('off'), style: text.displayMedium?.copyWith(color: fg, fontWeight: FontWeight.w600));
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: active ? null : scheme.surfaceContainerHigh,
        gradient: active
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, Color.lerp(scheme.primary, scheme.tertiary, 0.6)!],
              )
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_motion, color: fg, size: 22),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.heroTitle, style: text.titleMedium?.copyWith(color: fg))),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: active ? scheme.onPrimary.withValues(alpha: 0.18) : scheme.surfaceContainerHighest,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active ? scheme.onPrimary : scheme.outline,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(pill, style: text.labelMedium?.copyWith(color: fg)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutBack,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(animation), child: child),
              ),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, ?current],
              ),
              child: headline,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Text(caption, style: text.bodyMedium?.copyWith(color: muted)),
          ),
          SizedBox(
            height: 4,
            child: busy
                ? LinearProgressIndicator(
                    minHeight: 4,
                    color: active ? scheme.onPrimary : scheme.primary,
                    backgroundColor: Colors.transparent,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
