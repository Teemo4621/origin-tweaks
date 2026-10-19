import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/preset.dart';
import '../native/native_bridge.dart';
import '../native/update_controller.dart';
import '../theme.dart';
import '../widgets/info_card.dart';
import '../widgets/onboarding_card.dart';
import '../widgets/panel.dart';
import '../widgets/preset_selector.dart';
import '../widgets/status_hero.dart';
import '../widgets/tool_list.dart';
import '../widgets/update_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.refresh, this.onOpenSetup});

  final Listenable refresh;
  final VoidCallback? onOpenSetup;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SetupStatus _status = const SetupStatus(helper: true, secureSettings: true);
  CurrentSetting _current = const CurrentSetting();
  bool _loaded = false;
  Preset? _pending;
  Map<Tweak, TweakStatus> _tweaks = const {};
  Tweak? _tweakBusy;
  ThermalLevel _thermal = ThermalLevel.normal;

  @override
  void initState() {
    super.initState();
    widget.refresh.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.refresh.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final status = await NativeBridge.setupStatus();
    final current = await NativeBridge.current();
    final tweaks = {for (final tweak in Tweak.values) tweak: await NativeBridge.tweak(tweak)};
    final thermal = await NativeBridge.thermalStatus();
    if (!mounted) return;
    setState(() {
      _status = status;
      _current = current;
      _tweaks = tweaks;
      _thermal = thermal;
      _loaded = true;
    });
  }

  void _showMessage(String message, {bool offerSetup = false}) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(message),
      action: offerSetup && widget.onOpenSetup != null
          ? SnackBarAction(label: l10n.actionSetup, onPressed: widget.onOpenSetup!)
          : null,
    ));
  }

  Future<void> _apply(Preset preset) async {
    setState(() => _pending = preset);
    final result = await NativeBridge.applyPreset(preset);
    await _load();
    if (!mounted) return;
    setState(() => _pending = null);
    _showMessage(
      result.message(AppLocalizations.of(context), preset),
      offerSetup: result == ApplyResult.noPermission || result == ApplyResult.noHelper,
    );
  }

  Future<void> _setTweak(Tweak tweak, bool enabled) async {
    setState(() => _tweakBusy = tweak);
    final result = await NativeBridge.setTweak(tweak, enabled);
    await _load();
    if (!mounted) return;
    setState(() => _tweakBusy = null);
    final l10n = AppLocalizations.of(context);
    final title = tweak.title(l10n);
    _showMessage(
      switch (result) {
        ApplyResult.ok => enabled ? l10n.tweakEnabled(title) : l10n.tweakDisabled(title),
        ApplyResult.blocked => l10n.tweakOverwritten,
        _ => result.message(l10n, Preset.off),
      },
      offerSetup: result == ApplyResult.noPermission || result == ApplyResult.noHelper,
    );
  }

  void _openTool(Tweak tweak) {
    showToolSheet(
      context,
      tweak: tweak,
      enabled: _status.ready,
      load: () => NativeBridge.tweak(tweak),
      onChanged: (value) => _setTweak(tweak, value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ready = _status.ready;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ScreenHeader(
            title: l10n.appTitle,
            trailing: StatusChip(label: ready ? l10n.statusReady : l10n.statusNotReady, active: ready),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListenableBuilder(
                  listenable: UpdateController.instance,
                  builder: (context, _) => AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    alignment: Alignment.topCenter,
                    child: UpdateController.instance.update == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: UpdateBanner(controller: UpdateController.instance),
                          ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  alignment: Alignment.topCenter,
                  child: ready
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: OnboardingCard(
                            status: _status,
                            onChanged: (_) => _load(),
                            onRefresh: _load,
                            onOpenSetup: widget.onOpenSetup,
                          ),
                        ),
                ),
                if (_thermal != ThermalLevel.normal) ...[
                  ThermalWarning(level: _thermal),
                  const SizedBox(height: 16),
                ],
                StatusHero(current: _current, loaded: _loaded, busy: _pending != null, ready: ready),
                const SizedBox(height: 16),
                PresetSelector(
                  selected: _loaded ? _current.effective : null,
                  pending: _pending,
                  enabled: ready,
                  onSelected: _apply,
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    ready ? l10n.homePresetNote : l10n.homeFinishSetupFirst,
                    style: const TextStyle(fontSize: 12, height: 1.5, color: Palette.muted),
                  ),
                ),
                const SizedBox(height: 28),
                SectionLabel(l10n.toolsTitle, trailing: l10n.toolsHint),
                ToolList(
                  statuses: _tweaks,
                  enabled: ready,
                  busy: _tweakBusy,
                  onChanged: _setTweak,
                  onOpen: _openTool,
                ),
                const SizedBox(height: 28),
                InfoCard(
                  icon: Icons.dashboard_customize_outlined,
                  title: l10n.tileCardTitle,
                  children: [
                    NumberedStep(number: 1, text: l10n.tileStep1),
                    NumberedStep(number: 2, text: l10n.tileStep2),
                    NumberedStep(number: 3, text: l10n.tileStep3),
                    const SizedBox(height: 8),
                    _TileHint(icon: Icons.touch_app_outlined, text: l10n.tileHintTap),
                    _TileHint(icon: Icons.ads_click, text: l10n.tileHintLongPress),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TileHint extends StatelessWidget {
  const _TileHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Palette.accent),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: Palette.muted))),
        ],
      ),
    );
  }
}
