import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/preset.dart';
import '../native/native_bridge.dart';
import '../theme.dart';
import '../widgets/info_card.dart';
import '../widgets/panel.dart';

class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key, required this.refresh});

  final Listenable refresh;

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  final _search = TextEditingController();
  List<AppEntry> _apps = const [];
  Map<String, Preset> _profiles = const {};
  bool _serviceEnabled = false;
  bool _usageAccess = true;
  bool _loading = true;
  String _query = '';
  AppFilter? _filter;

  @override
  void initState() {
    super.initState();
    widget.refresh.addListener(_loadState);
    _loadApps();
    _loadState();
  }

  @override
  void dispose() {
    widget.refresh.removeListener(_loadState);
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    List<AppEntry> apps;
    try {
      apps = await NativeBridge.listApps();
    } catch (_) {
      apps = const [];
    }
    apps = sortApps(apps);
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _loading = false;
    });
  }

  Future<void> _loadState() async {
    final profiles = await NativeBridge.profiles();
    final enabled = await NativeBridge.isProfileServiceEnabled();
    final usage = await NativeBridge.hasUsageAccess();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _serviceEnabled = enabled;
      _usageAccess = usage;
    });
  }

  Future<void> _grantUsageAccess() async {
    final ok = await NativeBridge.grantUsageAccess();
    if (!ok) await NativeBridge.openUsageAccessSettings();
    await _loadState();
  }

  Future<void> _setService(bool enabled) async {
    if (enabled && !_usageAccess) {
      await _grantUsageAccess();
      if (!_usageAccess) return;
    }
    await NativeBridge.setProfileServiceEnabled(enabled);
    await _loadState();
  }

  Future<void> _setProfile(AppEntry app, Preset? preset) async {
    await NativeBridge.setProfile(app.packageName, preset);
    await _loadState();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final searched = filterApps(_apps, _query);
    final gameCount = searched.where((a) => a.isGame).length;
    final configuredCount = searched.where((a) => _profiles.containsKey(a.packageName)).length;
    final filter = _filter ?? (gameCount > 0 ? AppFilter.games : AppFilter.all);
    final visible = filterByKind(searched, filter, _profiles);
    final configured = _profiles.length;

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: ScreenHeader(title: l10n.titleProfiles, subtitle: l10n.profilesHeaderBody),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          sliver: SliverList.list(
            children: [
              Panel(
                padding: EdgeInsets.zero,
                radius: 18,
                child: MergeSemantics(
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
                    title: Text(l10n.profilesEnable, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      _serviceEnabled
                          ? (configured == 0 ? l10n.profilesNoneConfigured : l10n.profilesConfiguredCount(configured))
                          : l10n.profilesServiceOff,
                      style: const TextStyle(fontSize: 13, color: Palette.muted),
                    ),
                    value: _serviceEnabled,
                    onChanged: _setService,
                  ),
                ),
              ),
              if (!_usageAccess) ...[
                const SizedBox(height: 12),
                InfoCard(
                  icon: Icons.lock_outline,
                  color: Palette.heatSoft,
                  iconBackground: Palette.heatTile,
                  iconForeground: Palette.heat,
                  title: l10n.usageAccessRequired,
                  body: l10n.usageAccessPurpose,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(onPressed: _grantUsageAccess, child: Text(l10n.grant)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _SearchHeader(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 48,
                  child: TextField(
                    controller: _search,
                    onChanged: (value) => setState(() => _query = value),
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: l10n.searchAppsHint,
                      hintStyle: const TextStyle(color: Color(0xFF8C9299)),
                      prefixIcon: const Icon(Icons.search, size: 20, color: Palette.muted),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: l10n.clear,
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            ),
                      filled: true,
                      fillColor: Palette.surface,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Palette.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Palette.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Palette.accent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: l10n.filterGames,
                        count: gameCount,
                        selected: filter == AppFilter.games,
                        onTap: () => setState(() => _filter = AppFilter.games),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: l10n.filterConfigured,
                        count: configuredCount,
                        selected: filter == AppFilter.configured,
                        onTap: () => setState(() => _filter = AppFilter.configured),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: l10n.filterAll,
                        selected: filter == AppFilter.all,
                        onTap: () => setState(() => _filter = AppFilter.all),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_loading)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _Placeholder(icon: null, text: l10n.loadingApps),
          )
        else if (visible.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _Placeholder(
              icon: Icons.search_off,
              text: _query.isEmpty ? l10n.noAppsFound : l10n.noAppsMatch(_query),
            ),
          )
        else ...[
          _AppList(apps: visible, profiles: _profiles, onChanged: _setProfile),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ],
    );
  }
}

enum AppFilter { games, configured, all }

List<AppEntry> filterByKind(List<AppEntry> apps, AppFilter filter, Map<String, Preset> profiles) => switch (filter) {
      AppFilter.games => apps.where((a) => a.isGame).toList(),
      AppFilter.configured => apps.where((a) => profiles.containsKey(a.packageName)).toList(),
      AppFilter.all => apps,
    };

List<AppEntry> sortApps(Iterable<AppEntry> apps) => apps.toList()
  ..sort((a, b) {
    if (a.isGame != b.isGame) return a.isGame ? -1 : 1;
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  });

List<AppEntry> filterApps(List<AppEntry> apps, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return apps;
  return apps.where((a) => a.label.toLowerCase().contains(q) || a.packageName.toLowerCase().contains(q)).toList();
}

class _SearchHeader extends SliverPersistentHeaderDelegate {
  _SearchHeader({required this.child});

  final Widget child;

  static const _height = 112.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: Palette.ground,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(_SearchHeader oldDelegate) => true;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.count});

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? Palette.text : Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: selected ? Palette.text : Palette.line)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? Palette.ground : Palette.textSoft,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '$count',
                      style: AppText.mono.copyWith(fontSize: 13, color: selected ? Palette.ground : Palette.textSoft),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppList extends StatelessWidget {
  const _AppList({required this.apps, required this.profiles, required this.onChanged});

  final List<AppEntry> apps;
  final Map<String, Preset> profiles;
  final Future<void> Function(AppEntry app, Preset? preset) onChanged;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: DecoratedSliver(
        decoration: BoxDecoration(
          color: Palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Palette.line),
        ),
        sliver: SliverList.builder(
          itemCount: apps.length,
          itemBuilder: (context, index) {
            final app = apps[index];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (index > 0) const InsetDivider(indent: 68),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 68),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                    child: Row(
                      children: [
                        _AppIcon(packageName: app.packageName),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                app.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                app.packageName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.mono.copyWith(fontSize: 11, color: Palette.muted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PresetMenu(
                          app: app.label,
                          value: profiles[app.packageName],
                          onSelected: (preset) => onChanged(app, preset),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PresetMenu extends StatelessWidget {
  const _PresetMenu({required this.app, required this.value, required this.onSelected});

  final String app;
  final Preset? value;
  final ValueChanged<Preset?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final set = value != null;
    final label = value?.label(l10n) ?? l10n.profileNotSet;

    Widget item(Preset? preset) => MenuItemButton(
          leadingIcon: Icon(value == preset ? Icons.check : null, size: 18, color: Palette.accent),
          onPressed: () => onSelected(preset),
          child: Text(preset?.label(l10n) ?? l10n.profileNotSet),
        );

    return MenuAnchor(
      alignmentOffset: const Offset(-24, 0),
      menuChildren: [item(null), for (final preset in Preset.values) item(preset)],
      builder: (context, controller, _) => Semantics(
        container: true,
        button: true,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        label: l10n.presetFor(app, label),
        excludeSemantics: true,
        child: Material(
          color: set ? Palette.accentSoft : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: set ? Palette.accentLine : Palette.line),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => controller.isOpen ? controller.close() : controller.open(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40, minWidth: 80),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: AppText.heading.copyWith(
                        fontSize: 14,
                        color: set ? Palette.accent : Palette.textSoft,
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, size: 20, color: set ? Palette.accent : Palette.muted),
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

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.text});

  final IconData? icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon == null)
            const CircularProgressIndicator()
          else
            Icon(icon, size: 48, color: scheme.outline),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.packageName});

  final String packageName;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 42,
      child: FutureBuilder<Uint8List?>(
        future: NativeBridge.appIcon(packageName),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: bytes == null
                ? Icon(Icons.android, key: const ValueKey(false), color: Theme.of(context).colorScheme.outline)
                : Image.memory(bytes, key: const ValueKey(true), gaplessPlayback: true),
          );
        },
      ),
    );
  }
}
