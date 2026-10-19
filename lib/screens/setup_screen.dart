import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../native/native_bridge.dart';
import '../native/update_controller.dart';
import '../widgets/info_card.dart';
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
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SectionLabel(l10n.setupSectionStatus),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            alignment: Alignment.topCenter,
            child: _status.complete
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ShizukuCard(state: _status.shizuku, onChanged: _load),
                  ),
          ),
          SetupCard(status: _status, onChanged: (status) => setState(() => _status = status)),
          const SizedBox(height: 24),
          _SectionLabel(l10n.setupSectionTips),
          InfoCard(
            icon: Icons.info_outline,
            iconBackground: scheme.surfaceContainerHighest,
            iconForeground: scheme.onSurfaceVariant,
            title: l10n.setupLimitsTitle,
            body: l10n.setupLimitsBody,
          ),
          const SizedBox(height: 24),
          _SectionLabel(l10n.setupSectionAbout),
          ListenableBuilder(
            listenable: UpdateController.instance,
            builder: (context, _) => AboutCard(controller: UpdateController.instance),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              l10n.setupPullToRefresh,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
