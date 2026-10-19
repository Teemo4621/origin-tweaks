import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../native/native_bridge.dart';
import '../theme.dart';
import 'panel.dart';

extension TweakCopy on Tweak {
  IconData get icon => switch (this) {
        Tweak.hawkeye => Icons.visibility_outlined,
        Tweak.touchBoost => Icons.touch_app_outlined,
        Tweak.monsterPlus => Icons.local_fire_department_outlined,
      };

  bool get runsHot => this == Tweak.monsterPlus;

  String title(AppLocalizations l10n) => switch (this) {
        Tweak.hawkeye => l10n.hawkeyeTitle,
        Tweak.touchBoost => l10n.touchBoostTitle,
        Tweak.monsterPlus => l10n.monsterPlusTitle,
      };

  String short(AppLocalizations l10n) => switch (this) {
        Tweak.hawkeye => l10n.hawkeyeShort,
        Tweak.touchBoost => l10n.touchBoostShort,
        Tweak.monsterPlus => l10n.monsterPlusShort,
      };

  String body(AppLocalizations l10n) => switch (this) {
        Tweak.hawkeye => l10n.hawkeyeBody,
        Tweak.touchBoost => l10n.touchBoostBody,
        Tweak.monsterPlus => l10n.monsterPlusBody,
      };
}

const toolOrder = [Tweak.hawkeye, Tweak.touchBoost, Tweak.monsterPlus];

class ToolList extends StatelessWidget {
  const ToolList({
    super.key,
    required this.statuses,
    required this.enabled,
    required this.busy,
    required this.onChanged,
    required this.onOpen,
  });

  final Map<Tweak, TweakStatus> statuses;
  final bool enabled;
  final Tweak? busy;
  final void Function(Tweak tweak, bool value) onChanged;
  final ValueChanged<Tweak> onOpen;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final tweak in toolOrder) ...[
            if (tweak != toolOrder.first) const InsetDivider(indent: 70),
            ToolRow(
              tweak: tweak,
              status: statuses[tweak] ?? const TweakStatus(),
              enabled: enabled,
              busy: busy == tweak,
              onChanged: (value) => onChanged(tweak, value),
              onOpen: () => onOpen(tweak),
            ),
          ],
        ],
      ),
    );
  }
}

class ToolRow extends StatelessWidget {
  const ToolRow({
    super.key,
    required this.tweak,
    required this.status,
    required this.enabled,
    required this.busy,
    required this.onChanged,
    required this.onOpen,
  });

  final Tweak tweak;
  final TweakStatus status;
  final bool enabled;
  final bool busy;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Row(
                  children: [
                    IconTile(icon: tweak.icon, heat: tweak.runsHot),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(tweak.title(l10n), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                              if (tweak.runsHot) Tag(label: l10n.heatTag, heat: true),
                              if (status.overwritten)
                                const Icon(Icons.warning_amber_rounded, size: 16, color: Palette.heat),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(tweak.short(l10n), style: const TextStyle(fontSize: 13, color: Palette.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: busy
                ? const SizedBox(
                    width: 52,
                    height: 44,
                    child: Center(
                      child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.2)),
                    ),
                  )
                : Switch(
                    value: status.enabled,
                    onChanged: enabled ? onChanged : null,
                    activeTrackColor: tweak.runsHot ? Palette.heat : null,
                  ),
          ),
        ],
      ),
    );
  }
}

Future<void> showToolSheet(
  BuildContext context, {
  required Tweak tweak,
  required bool enabled,
  required Future<TweakStatus> Function() load,
  required Future<void> Function(bool value) onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => ToolSheet(tweak: tweak, enabled: enabled, load: load, onChanged: onChanged),
  );
}

class ToolSheet extends StatefulWidget {
  const ToolSheet({super.key, required this.tweak, required this.enabled, required this.load, required this.onChanged});

  final Tweak tweak;
  final bool enabled;
  final Future<TweakStatus> Function() load;
  final Future<void> Function(bool value) onChanged;

  @override
  State<ToolSheet> createState() => _ToolSheetState();
}

class _ToolSheetState extends State<ToolSheet> {
  TweakStatus _status = const TweakStatus();
  ThermalLevel _thermal = ThermalLevel.normal;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await widget.load();
    final thermal = await NativeBridge.thermalStatus();
    if (!mounted) return;
    setState(() {
      _status = status;
      _thermal = thermal;
    });
  }

  Future<void> _set(bool value) async {
    setState(() => _busy = true);
    await widget.onChanged(value);
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tweak = widget.tweak;
    final hot = tweak.runsHot;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(icon: tweak.icon, heat: hot, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(tweak.title(l10n), style: AppText.heading.copyWith(fontSize: 22)),
                    ),
                    Text(
                      '${l10n.superResExperimental} · ${_status.enabled ? l10n.tweakStateOn : l10n.tweakStateOff}',
                      style: const TextStyle(fontSize: 13, color: Palette.muted),
                    ),
                  ],
                ),
              ),
              _busy
                  ? const SizedBox(
                      width: 52,
                      height: 44,
                      child: Center(
                        child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.2)),
                      ),
                    )
                  : Switch(
                      value: _status.enabled,
                      onChanged: widget.enabled ? _set : null,
                      activeTrackColor: hot ? Palette.heat : null,
                    ),
            ],
          ),
          const SizedBox(height: 18),
          Text(tweak.body(l10n), style: const TextStyle(fontSize: 14, height: 1.6, color: Palette.textSoft)),
          if (_thermal != ThermalLevel.normal) ...[
            const SizedBox(height: 18),
            ThermalWarning(level: _thermal),
          ],
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(l10n.liveValuesTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ),
              Text(l10n.liveValuesHint, style: const TextStyle(fontSize: 12, color: Palette.muted)),
            ],
          ),
          const SizedBox(height: 10),
          if (_status.values.isEmpty)
            Text(l10n.liveValuesEmpty, style: const TextStyle(fontSize: 13, color: Palette.muted))
          else
            LiveValues(status: _status),
          const SizedBox(height: 8),
          Text(l10n.liveValuesLegend, style: const TextStyle(fontSize: 12, height: 1.5, color: Palette.muted)),
          const SizedBox(height: 20),
          Row(
            children: [
              if (_status.enabled) ...[
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      foregroundColor: hot ? Palette.heatText : Palette.text,
                      side: BorderSide(color: hot ? Palette.heatLine : Palette.line),
                    ),
                    onPressed: widget.enabled && !_busy ? () => _set(false) : null,
                    child: Text(l10n.turnOffRestore),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Palette.text, foregroundColor: Palette.ground),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.done),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LiveValues extends StatelessWidget {
  const LiveValues({super.key, required this.status});

  final TweakStatus status;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      radius: 14,
      color: Palette.nav,
      child: Column(
        children: [
          for (final (index, value) in status.values.indexed) ...[
            if (index > 0) const InsetDivider(),
            _ValueRow(value: value, active: status.enabled),
          ],
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.value, required this.active});

  final TweakValue value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final drifted = active && !value.matches;
    final icon = !active
        ? const Icon(Icons.circle_outlined, size: 14, color: Palette.muted)
        : value.matches
            ? const Icon(Icons.check_rounded, size: 16, color: Palette.accent)
            : const Icon(Icons.warning_amber_rounded, size: 16, color: Palette.heat);
    return Container(
      color: drifted ? const Color(0xFF1C1411) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value.key,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.mono.copyWith(fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value.value ?? '–',
            style: AppText.mono.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: drifted ? Palette.heatText : Palette.text,
            ),
          ),
          if (drifted)
            Text(' ≠ ${value.expected}', style: AppText.mono.copyWith(fontSize: 13, color: Palette.muted)),
        ],
      ),
    );
  }
}

class ThermalWarning extends StatelessWidget {
  const ThermalWarning({super.key, required this.level});

  final ThermalLevel level;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      child: Panel(
        padding: const EdgeInsets.all(14),
        radius: 14,
        color: Palette.heatSoft,
        borderColor: Palette.heatLine,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.warning_amber_rounded, size: 20, color: Palette.heat),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level == ThermalLevel.critical ? l10n.thermalCriticalTitle : l10n.thermalSevereTitle,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Palette.heatText),
                  ),
                  const SizedBox(height: 4),
                  Text(l10n.thermalBody, style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFFE6C2B6))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
