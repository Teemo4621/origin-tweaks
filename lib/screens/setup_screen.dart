import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../native/native_bridge.dart';
import '../native/update_controller.dart';
import '../theme.dart';
import '../widgets/panel.dart';
import '../widgets/setup_card.dart';
import '../widgets/shizuku_card.dart';
import '../widgets/update_card.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.refresh});

  final Listenable refresh;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  SetupStatus _status = const SetupStatus();

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
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final done = _status.doneCount;
    const total = SetupStatus.totalSteps;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ScreenHeader(
            title: l10n.titleSetup,
            subtitle: _status.complete
                ? l10n.setupCompleteSubtitle(done, total)
                : l10n.setupIncompleteSubtitle(done, total),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionLabel(l10n.setupSectionStatus),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  alignment: Alignment.topCenter,
                  child: _status.complete
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ShizukuCard(state: _status.shizuku, onChanged: _load),
                        ),
                ),
                SetupCard(status: _status, onChanged: (status) => setState(() => _status = status)),
                const SizedBox(height: 28),
                SectionLabel(l10n.setupSectionAbout),
                ListenableBuilder(
                  listenable: UpdateController.instance,
                  builder: (context, _) => AboutCard(controller: UpdateController.instance),
                ),
                const SizedBox(height: 28),
                SectionLabel(l10n.setupSectionTips),
                Panel(
                  padding: EdgeInsets.zero,
                  radius: 18,
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    title: Text(l10n.setupLimitsTitle, style: const TextStyle(fontSize: 15)),
                    children: [
                      Text(l10n.setupLimitsBody, style: const TextStyle(fontSize: 13, height: 1.6, color: Palette.textSoft)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(l10n.setupPullToRefresh, style: const TextStyle(fontSize: 12, color: Palette.muted)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
