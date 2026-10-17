import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origin_tweaks/main.dart';
import 'package:origin_tweaks/models/preset.dart';
import 'package:origin_tweaks/native/native_bridge.dart';
import 'package:origin_tweaks/screens/home_screen.dart';
import 'package:origin_tweaks/screens/profiles_screen.dart';
import 'package:origin_tweaks/widgets/preset_grid.dart';
import 'package:origin_tweaks/widgets/status_hero.dart';

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
    expect(ApplyResult.ok.messageFor(Preset.fps144), 'เปิด 144 FPS แล้ว');
    expect(ApplyResult.ok.messageFor(Preset.off), 'ปิดแทรกเฟรมแล้ว');
    expect(ApplyResult.noHelper.messageFor(Preset.fps90), 'ยังตั้งค่าครั้งแรกไม่เสร็จ');
    expect(ApplyResult.failed.messageFor(Preset.fps90), 'ตั้งค่าไม่สำเร็จ');
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
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(
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
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.dark),
      home: Scaffold(body: HomeScreen(refresh: ValueNotifier(0))),
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
    await tester.pumpWidget(const OriginTweaksApp());
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
}
