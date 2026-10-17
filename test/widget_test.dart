import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origin_tweaks/l10n/gen/app_localizations.dart';
import 'package:origin_tweaks/main.dart';
import 'package:origin_tweaks/models/preset.dart';
import 'package:origin_tweaks/native/native_bridge.dart';
import 'package:origin_tweaks/screens/home_screen.dart';
import 'package:origin_tweaks/screens/profiles_screen.dart';
import 'package:origin_tweaks/screens/setup_screen.dart';
import 'package:origin_tweaks/widgets/preset_grid.dart';
import 'package:origin_tweaks/widgets/status_hero.dart';

const _th = Locale('th');
const _en = Locale('en');

Widget _localized(Widget home, {Locale locale = _th, Brightness brightness = Brightness.light}) => MaterialApp(
      theme: buildTheme(brightness),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void _mockNative(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('origin_tweaks/native'),
    (call) async => switch (call.method) {
      'getSetupStatus' => <String, Object?>{'shizuku': 'noPermission', 'helper': true},
      'getCurrent' => <String, Object?>{'value': '7'},
      'listApps' => [
          <String, Object?>{'package': 'com.example.verylongpackagename.game', 'label': 'Very Long Game Name Here', 'isGame': true},
          <String, Object?>{'package': 'com.example.app', 'label': 'App', 'isGame': false},
        ],
      'getProfiles' => <String, String>{'com.example.verylongpackagename.game': 'fps144'},
      'isProfileServiceEnabled' => true,
      'hasUsageAccess' => false,
      _ => null,
    },
  );
}

void main() {
  test('fromId resolves known ids only', () {
    expect(Preset.fromId('fps144'), Preset.fps144);
    expect(Preset.fromId('nope'), isNull);
    expect(Preset.fromId(null), isNull);
  });

  test('result codes map to ShellUserService constants', () {
    expect(ApplyResult.fromCode(0), ApplyResult.ok);
    expect(ApplyResult.fromCode(2), ApplyResult.blocked);
    expect(ApplyResult.fromCode(3), ApplyResult.noPermission);
    expect(ApplyResult.fromCode(99), ApplyResult.failed);
    expect(ApplyResult.fromCode(null), ApplyResult.failed);
  });

  test('preset metadata', () {
    expect(Preset.fps144.tested, isTrue);
    expect(Preset.fps90.tested, isFalse);
    expect(Preset.fps120.fps, 120);
    expect(Preset.off.fps, isNull);
  });

  test('apply messages', () {
    final th = lookupAppLocalizations(_th);
    expect(ApplyResult.ok.message(th, Preset.fps144), 'เปิด 144 FPS แล้ว');
    expect(ApplyResult.ok.message(th, Preset.off), 'ปิดแทรกเฟรมแล้ว');
    expect(ApplyResult.noHelper.message(th, Preset.fps90), 'ยังตั้งค่าครั้งแรกไม่เสร็จ');
    expect(ApplyResult.failed.message(th, Preset.fps90), 'ตั้งค่าไม่สำเร็จ');
    final en = lookupAppLocalizations(_en);
    expect(ApplyResult.ok.message(en, Preset.fps144), '144 FPS enabled');
    expect(ApplyResult.ok.message(en, Preset.off), 'Frame generation turned off');
  });

  test('preset labels per locale', () {
    expect(Preset.off.label(lookupAppLocalizations(_th)), 'ปิด');
    expect(Preset.off.label(lookupAppLocalizations(_en)), 'Off');
    expect(Preset.fps120.label(lookupAppLocalizations(_th)), '120 FPS');
    expect(Preset.fps120.label(lookupAppLocalizations(_en)), '120 FPS');
    expect(lookupAppLocalizations(_en).profilesConfiguredCount(1), '1 app configured');
    expect(lookupAppLocalizations(_en).profilesConfiguredCount(3), '3 apps configured');
  });

  test('current setting resolves effective preset', () {
    expect(const CurrentSetting().effective, Preset.off);
    expect(const CurrentSetting(value: '3', preset: Preset.fps144).effective, Preset.fps144);
    expect(const CurrentSetting(value: '7').isCustom, isTrue);
  });

  test('setup status helpers', () {
    const status = SetupStatus(shizuku: ShizukuState.noPermission, helper: true, battery: true);
    expect(status.shizukuUsable, isTrue);
    expect(status.doneCount, 2);
    expect(status.ready, isFalse);
    expect(const SetupStatus().shizukuUsable, isFalse);
  });

  test('apps sort games first and filter by label or package', () {
    const apps = [
      AppEntry(packageName: 'com.b.app', label: 'Beta', isGame: false),
      AppEntry(packageName: 'com.z.game', label: 'Zeta', isGame: true),
      AppEntry(packageName: 'com.a.game', label: 'alpha', isGame: true),
    ];
    final sorted = sortApps(apps);
    expect(sorted.map((a) => a.label), ['alpha', 'Zeta', 'Beta']);
    expect(filterApps(sorted, 'z.GAME').single.label, 'Zeta');
    expect(filterApps(sorted, '  ').length, 3);
  });

  testWidgets('preset grid shows badges and reports taps', (tester) async {
    Preset? tapped;
    await tester.pumpWidget(_localized(
      Scaffold(
        body: PresetGrid(
          selected: Preset.off,
          pending: null,
          enabled: true,
          onSelected: (p) => tapped = p,
        ),
      ),
    ));
    expect(find.text('ทดสอบแล้ว'), findsOneWidget);
    expect(find.text('ยังไม่ทดสอบ'), findsNWidgets(2));
    await tester.tap(find.text('144 FPS'));
    expect(tapped, Preset.fps144);
  });

  testWidgets('home shows onboarding when setup is not ready', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('origin_tweaks/native'),
      (call) async => switch (call.method) {
        'getSetupStatus' => <String, Object?>{'shizuku': 'notRunning'},
        'getCurrent' => <String, Object?>{'value': '1', 'presetId': 'fps144'},
        _ => null,
      },
    );
    await tester.pumpWidget(_localized(
      Scaffold(body: HomeScreen(refresh: ValueNotifier(0))),
      brightness: Brightness.dark,
    ));
    await tester.pumpAndSettle();
    expect(find.text('เริ่มต้นใช้งาน'), findsOneWidget);
    expect(find.text('เปิด Shizuku'), findsOneWidget);
    expect(find.text('144'), findsOneWidget);
  });

  testWidgets('all tabs render on a narrow phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    _mockNative(tester);
    await tester.pumpWidget(const OriginTweaksApp(locale: _th));
    await tester.pumpAndSettle();
    expect(find.text('เริ่มต้นใช้งาน'), findsOneWidget);
    final homeScroll = find.descendant(of: find.byType(HomeScreen), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.byType(StatusHero), 200, scrollable: homeScroll);
    expect(find.text('ค่าจากระบบ'), findsWidgets);
    expect(find.textContaining('gamecube_frame_interpolation'), findsNothing);
    await tester.scrollUntilVisible(find.text('กดค้างเพื่อเปิดแอปนี้'), 200, scrollable: homeScroll);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('ตั้งไว้ 1 แอป'), findsOneWidget);
    final profileScroll = find.descendant(of: find.byType(ProfilesScreen), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('com.example.app'), 200, scrollable: profileScroll);
    expect(find.text('144 FPS'), findsOneWidget);
    await tester.tap(find.text('144 FPS'));
    await tester.pumpAndSettle();
    expect(find.text('120 FPS'), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตั้งค่า'));
    await tester.pumpAndSettle();
    expect(find.text('1/4'), findsOneWidget);
  });

  testWidgets('english locale renders all tabs on a narrow phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    _mockNative(tester);
    await tester.pumpWidget(const OriginTweaksApp(locale: _en));
    await tester.pumpAndSettle();
    expect(find.text('Getting started'), findsOneWidget);
    expect(find.text('Auto setup'), findsOneWidget);
    expect(find.text('Frame gen'), findsOneWidget);
    final homeScroll = find.descendant(of: find.byType(HomeScreen), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Tested'), 200, scrollable: homeScroll);
    expect(find.text('Untested'), findsNWidgets(2));
    expect(find.text('Off'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Long-press to open this app'), 200, scrollable: homeScroll);
    await tester.tap(find.text('Profiles'));
    await tester.pumpAndSettle();
    expect(find.text('Per-game profiles'), findsOneWidget);
    expect(find.text('1 app configured'), findsOneWidget);
    expect(find.text('Usage access required'), findsOneWidget);
    final profileScroll = find.descendant(of: find.byType(ProfilesScreen), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('com.example.app'), 200, scrollable: profileScroll);
    expect(find.text('Not set'), findsOneWidget);
    await tester.tap(find.text('Setup'));
    await tester.pumpAndSettle();
    expect(find.text('Initial setup'), findsOneWidget);
    expect(find.text('First-time setup'), findsOneWidget);
    expect(find.text('Not allowed yet'), findsOneWidget);
    final setupScroll = find.descendant(of: find.byType(SetupScreen), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Limitations'), 200, scrollable: setupScroll);
    expect(tester.takeException(), isNull);
  });
}
