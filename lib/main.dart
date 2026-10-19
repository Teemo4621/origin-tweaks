import 'package:flutter/material.dart';

import 'l10n/gen/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/profiles_screen.dart';
import 'screens/setup_screen.dart';
import 'native/update_controller.dart';
import 'theme.dart';

void main() {
  runApp(const OriginTweaksApp());
}

class OriginTweaksApp extends StatelessWidget {
  const OriginTweaksApp({super.key, this.locale});

  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      themeMode: ThemeMode.dark,
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  final _refresh = ValueNotifier<int>(0);
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    UpdateController.instance.check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refresh.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh.value++;
  }

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    _refresh.value++;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: [
            HomeScreen(refresh: _refresh, onOpenSetup: () => _select(2)),
            ProfilesScreen(refresh: _refresh),
            SetupScreen(refresh: _refresh),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Palette.line))),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.layers_outlined),
              selectedIcon: const Icon(Icons.layers),
              label: l10n.navFrameGen,
            ),
            NavigationDestination(
              icon: const Icon(Icons.sports_esports_outlined),
              selectedIcon: const Icon(Icons.sports_esports),
              label: l10n.navProfiles,
            ),
            NavigationDestination(
              icon: const Icon(Icons.tune_outlined),
              selectedIcon: const Icon(Icons.tune),
              label: l10n.navSetup,
            ),
          ],
        ),
      ),
    );
  }
}
