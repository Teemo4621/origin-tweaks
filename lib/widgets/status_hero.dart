import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/preset.dart';
import '../theme.dart';
import 'panel.dart';

class StatusHero extends StatelessWidget {
  const StatusHero({super.key, required this.current, required this.loaded, required this.busy, this.ready = true});

  final CurrentSetting current;
  final bool loaded;
  final bool busy;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preset = current.effective;
    final active = preset?.enabled ?? false;
    final custom = current.isCustom;

    final caption = !loaded
        ? l10n.heroLoadingCaption
        : active
            ? l10n.heroActiveCaption
            : custom
                ? l10n.heroCustomCaption
                : l10n.heroOffCaption;

    final Widget headline;
    if (!loaded) {
      headline = Text('—', key: const ValueKey('loading'), style: AppText.display.copyWith(fontSize: 64, color: Palette.muted));
    } else if (preset?.fps case final fps?) {
      headline = Row(
        key: ValueKey(preset),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$fps',
            style: AppText.display.copyWith(fontSize: 104, height: 0.95, letterSpacing: -3, color: Palette.accent),
          ),
          const SizedBox(width: 10),
          Text('FPS', style: AppText.heading.copyWith(fontSize: 22)),
        ],
      );
    } else if (custom) {
      headline = Text(
        l10n.heroCustom,
        key: const ValueKey('custom'),
        style: AppText.display.copyWith(fontSize: 44, height: 1.1),
      );
    } else {
      headline = Text(
        l10n.presetOff,
        key: const ValueKey('off'),
        style: AppText.display.copyWith(fontSize: 72, height: 1, color: ready ? Palette.text : Palette.textSoft),
      );
    }

    final range = switch ((preset?.sourceFps, preset?.fps)) {
      (final from?, final to?) => '$from → $to',
      _ => null,
    };

    return Semantics(
      container: true,
      label: '${l10n.heroTitle}: ${preset?.label(l10n) ?? l10n.heroCustom}',
      child: Panel(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(l10n.heroTitle, style: const TextStyle(fontSize: 14, color: Palette.muted)),
                      ),
                      if (range != null) Text(range, style: AppText.mono.copyWith(fontSize: 12, color: Palette.muted)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ExcludeSemantics(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(animation),
                          child: child,
                        ),
                      ),
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.bottomLeft,
                        children: [...previous, ?current],
                      ),
                      child: FittedBox(
                        key: headline.key,
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: headline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SegmentMeter(filled: loaded ? (preset?.meterLevel ?? 0) : 0),
                  const SizedBox(height: 14),
                  Text(caption, style: const TextStyle(fontSize: 14, height: 1.55, color: Palette.textSoft)),
                ],
              ),
            ),
            SizedBox(height: 3, child: busy ? const LinearProgressIndicator(minHeight: 3) : null),
          ],
        ),
      ),
    );
  }
}
