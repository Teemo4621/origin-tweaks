import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/preset.dart';
import '../native/native_bridge.dart';
import '../widgets/info_card.dart';
import '../widgets/onboarding_card.dart';
import '../widgets/preset_grid.dart';
import '../widgets/status_hero.dart';
import '../widgets/super_res_card.dart';

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
  int _superRes = 0;
  bool _superResBusy = false;

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
    final superRes = await NativeBridge.superResLevel();
    if (!mounted) return;
    setState(() {
      _status = status;
      _current = current;
      _superRes = superRes;
      _loaded = true;
    });
  }

  Future<void> _apply(Preset preset) async {
    setState(() => _pending = preset);
    final result = await NativeBridge.applyPreset(preset);
    await _load();
    if (!mounted) return;
    setState(() => _pending = null);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(result.message(l10n, preset)),
      action: result == ApplyResult.noPermission || result == ApplyResult.noHelper
          ? widget.onOpenSetup == null
              ? null
              : SnackBarAction(label: l10n.actionSetup, onPressed: widget.onOpenSetup!)
          : null,
    ));
  }

  Future<void> _applySuperRes(int level) async {
    setState(() => _superResBusy = true);
    final result = await NativeBridge.setSuperRes(level);
    await _load();
    if (!mounted) return;
    setState(() => _superResBusy = false);
    final l10n = AppLocalizations.of(context);
    final message = switch (result) {
      ApplyResult.ok => level > 0
          ? l10n.superResEnabled(SuperResCard.levelLabel(l10n, level))
          : l10n.superResDisabled,
      ApplyResult.blocked => l10n.applyBlocked,
      ApplyResult.noPermission || ApplyResult.noHelper => l10n.applyNotSetUp,
      ApplyResult.failed => l10n.applyFailed,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final ready = _status.ready;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
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
          StatusHero(current: _current, loaded: _loaded, busy: _pending != null),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(child: Text(l10n.homeChooseMode, style: text.titleMedium)),
                if (!ready)
                  Text(l10n.homeFinishSetupFirst, style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PresetGrid(
            selected: _loaded ? _current.effective : null,
            pending: _pending,
            enabled: ready,
            onSelected: _apply,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              l10n.homePresetNote,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 24),
          SuperResCard(
            level: _superRes,
            enabled: _status.secureSettings,
            busy: _superResBusy,
            onChanged: _applySuperRes,
          ),
          const SizedBox(height: 16),
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
    );
  }
}

class _TileHint extends StatelessWidget {
  const _TileHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}
