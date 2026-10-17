import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/preset.dart';
import '../native/native_bridge.dart';
import '../widgets/info_card.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final visible = filterApps(_apps, _query);
    final games = visible.where((a) => a.isGame).toList();
    final others = visible.where((a) => !a.isGame).toList();
    final configured = _profiles.length;

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverList.list(
            children: [
              Card(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const IconBadge(icon: Icons.sports_esports_outlined),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ตั้ง FPS แยกแต่ละเกม', style: text.titleMedium),
                                const SizedBox(height: 4),
                                Text(
                                  'เปิดเกมที่ตั้งไว้ → ใช้ FPS ของเกมนั้น · ออกจากเกม → คืนค่าเดิม',
                                  style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, indent: 16, endIndent: 16, color: scheme.outlineVariant),
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      title: const Text('เปิดใช้ Profile รายเกม'),
                      subtitle: Text(_serviceEnabled
                          ? (configured == 0 ? 'ยังไม่ได้ตั้งแอปไหน เลือก FPS ด้านล่าง' : 'ตั้งไว้ $configured แอป')
                          : 'ปิดอยู่ ใช้ค่าจากปุ่มลัดกับทุกเกม'),
                      value: _serviceEnabled,
                      onChanged: _setService,
                    ),
                  ],
                ),
              ),
              if (!_usageAccess) ...[
                const SizedBox(height: 16),
                InfoCard(
                  icon: Icons.lock_outline,
                  color: scheme.tertiaryContainer,
                  iconBackground: scheme.tertiary,
                  iconForeground: scheme.onTertiary,
                  title: 'ต้องให้สิทธิ์ Usage access',
                  body: 'ใช้ตรวจว่าตอนนี้เปิดเกมอะไรอยู่',
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(onPressed: _grantUsageAccess, child: const Text('ให้สิทธิ์')),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _SearchHeader(
            background: scheme.surface,
            child: SearchBar(
              controller: _search,
              hintText: 'ค้นหาแอป/เกม',
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
              padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
              leading: Icon(Icons.search, color: scheme.onSurfaceVariant),
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    tooltip: 'ล้าง',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
              ],
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
        ),
        if (_loading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _Placeholder(icon: null, text: 'กำลังโหลดรายการแอป…'),
          )
        else if (visible.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _Placeholder(
              icon: Icons.search_off,
              text: _query.isEmpty ? 'ไม่พบแอปในเครื่อง' : 'ไม่พบแอปที่ตรงกับ "$_query"',
            ),
          )
        else ...[
          if (games.isNotEmpty) ...[
            _SectionHeader(label: 'เกม', count: games.length),
            _AppList(apps: games, profiles: _profiles, onChanged: _setProfile),
          ],
          if (others.isNotEmpty) ...[
            _SectionHeader(label: 'แอปอื่น', count: others.length),
            _AppList(apps: others, profiles: _profiles, onChanged: _setProfile),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ],
    );
  }
}

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
  _SearchHeader({required this.child, required this.background});

  final Widget child;
  final Color background;

  static const _height = 72.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(_SearchHeader oldDelegate) => true;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          children: [
            Text(label, style: text.titleSmall?.copyWith(color: scheme.primary)),
            const SizedBox(width: 8),
            Text('$count', style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: apps.length,
        itemBuilder: (context, index) {
          final app = apps[index];
          final first = index == 0;
          final last = index == apps.length - 1;
          final radius = BorderRadius.vertical(
            top: Radius.circular(first ? 20 : 4),
            bottom: Radius.circular(last ? 20 : 4),
          );
          return Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 2),
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.only(left: 16, right: 8),
                leading: _AppIcon(packageName: app.packageName),
                title: Text(app.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(app.packageName, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: _PresetMenu(
                  value: profiles[app.packageName],
                  onSelected: (preset) => onChanged(app, preset),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PresetMenu extends StatelessWidget {
  const _PresetMenu({required this.value, required this.onSelected});

  final Preset? value;
  final ValueChanged<Preset?> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final set = value != null;

    Widget item(Preset? preset) => MenuItemButton(
          leadingIcon: Icon(value == preset ? Icons.check : null, size: 18),
          onPressed: () => onSelected(preset),
          child: Text(preset?.label ?? 'ไม่ตั้ง'),
        );

    return MenuAnchor(
      alignmentOffset: const Offset(-24, 0),
      menuChildren: [item(null), for (final preset in Preset.values) item(preset)],
      builder: (context, controller, _) => Material(
        color: set ? scheme.primaryContainer : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: set ? BorderSide.none : BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => controller.isOpen ? controller.close() : controller.open(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value?.label ?? 'ไม่ตั้ง',
                  style: text.labelLarge?.copyWith(
                    color: set ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                  ),
                ),
                Icon(Icons.arrow_drop_down, size: 20, color: set ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
              ],
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
      dimension: 40,
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
