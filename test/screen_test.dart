import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origin_tweaks/main.dart';
import 'package:origin_tweaks/screens/home_screen.dart';
import 'package:origin_tweaks/screens/profiles_screen.dart';
import 'package:origin_tweaks/screens/setup_screen.dart';
import 'package:origin_tweaks/widgets/onboarding_card.dart';
import 'package:origin_tweaks/widgets/tool_list.dart';

import 'support.dart';

const _tall = Size(400, 2400);

final _apps = [
  <String, Object?>{'package': 'com.kurogame.wutheringwaves.global', 'label': 'Wuthering Waves', 'isGame': true},
  <String, Object?>{'package': 'com.tencent.ig', 'label': 'PUBG MOBILE', 'isGame': true},
  <String, Object?>{'package': 'com.android.chrome', 'label': 'Chrome', 'isGame': false},
];

Future<void> _pumpHome(WidgetTester tester, {Locale locale = th}) async {
  await usePhone(tester, size: _tall);
  await tester.pumpWidget(localized(Scaffold(body: HomeScreen(refresh: ValueNotifier(0), onOpenSetup: () {})), locale: locale));
  await tester.pumpAndSettle();
}

Future<void> _pumpProfiles(WidgetTester tester) async {
  await usePhone(tester, size: _tall);
  await tester.pumpWidget(localized(Scaffold(body: ProfilesScreen(refresh: ValueNotifier(0)))));
  await tester.pumpAndSettle();
}

void main() {
  group('Home', () {
    testWidgets('ready: chip, hero, enabled selector, tools and the tile card copy', (tester) async {
      FakeNative(tester);
      await _pumpHome(tester);
      final t = l10nTh();
      expect(find.text('พร้อมใช้งาน'), findsOneWidget);
      expect(find.byType(OnboardingCard), findsNothing);
      expect(find.text('144'), findsWidgets);
      expect(find.text(t.homePresetNote), findsOneWidget);
      expect(find.text(t.toolsTitle), findsOneWidget);
      expect(find.byType(ToolRow), findsNWidgets(3));
      expect(find.text(t.tileCardTitle), findsOneWidget);
      expect(find.text(t.tileStep1), findsOneWidget);
      expect(find.text(t.tileHintLongPress), findsOneWidget);
    });

    testWidgets('not ready: onboarding first, controls disabled, hint replaces the note', (tester) async {
      FakeNative(tester, handlers: {'getSetupStatus': (_) => <String, Object?>{'shizuku': 'notRunning'}});
      await _pumpHome(tester);
      expect(find.text('ยังไม่พร้อม'), findsOneWidget);
      expect(find.byType(OnboardingCard), findsOneWidget);
      expect(find.text(l10nTh().homeFinishSetupFirst), findsOneWidget);
      for (final element in find.byType(Switch).evaluate()) {
        expect((element.widget as Switch).onChanged, isNull);
      }
      final onboardingTop = tester.getTopLeft(find.byType(OnboardingCard)).dy;
      final toolsTop = tester.getTopLeft(find.text(l10nTh().toolsTitle)).dy;
      expect(onboardingTop, lessThan(toolsTop));
    });

    testWidgets('choosing an FPS applies it and confirms', (tester) async {
      final native = FakeNative(tester, handlers: {'applyPreset': (_) => 0});
      await _pumpHome(tester);
      await tester.tap(find.text('120'));
      await tester.pumpAndSettle();
      final call = native.called('applyPreset').single;
      expect(call.arguments, {'id': 'fps120'});
      expect(find.text('เปิด 120 FPS แล้ว'), findsOneWidget);
      expect(native.called('getCurrent').length, greaterThanOrEqualTo(2));
    });

    testWidgets('a setup error offers a shortcut to setup', (tester) async {
      var opened = false;
      FakeNative(tester, handlers: {'applyPreset': (_) => 4});
      await usePhone(tester, size: _tall);
      await tester.pumpWidget(localized(
        Scaffold(body: HomeScreen(refresh: ValueNotifier(0), onOpenSetup: () => opened = true)),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('90'));
      await tester.pumpAndSettle();
      expect(find.text('ยังตั้งค่าครั้งแรกไม่เสร็จ'), findsOneWidget);
      await tester.tap(find.widgetWithText(SnackBarAction, l10nTh().actionSetup));
      expect(opened, isTrue);
    });

    testWidgets('toggling a tool calls setTweak and confirms with its name', (tester) async {
      final native = FakeNative(tester, handlers: {'setTweak': (_) => 0});
      await _pumpHome(tester);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(native.called('setTweak').single.arguments, {'id': 'hawkeye', 'enabled': true});
      expect(find.text('เปิดภาพคมชัด Hawk-eyeแล้ว'), findsOneWidget);
    });

    testWidgets('a blocked tool reports that the system changed it back', (tester) async {
      FakeNative(tester, handlers: {'setTweak': (_) => 2});
      await _pumpHome(tester);
      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();
      expect(find.text(l10nTh().tweakOverwritten), findsOneWidget);
    });

    testWidgets('tapping a tool opens its sheet with live values from the device', (tester) async {
      final native = FakeNative(tester, handlers: {
        'getTweak': (call) => (call.arguments as Map)['id'] == 'monster_plus'
            ? tweakMap(enabled: true, values: [('system/game_plus_mode_key', '1', '1')])
            : tweakMap(),
      });
      await _pumpHome(tester);
      await tester.tap(find.text('Monster+'));
      await tester.pumpAndSettle();
      expect(find.byType(ToolSheet), findsOneWidget);
      expect(find.text('system/game_plus_mode_key'), findsOneWidget);
      expect(native.called('getTweak').where((c) => (c.arguments as Map)['id'] == 'monster_plus').length,
          greaterThanOrEqualTo(2));
    });

    testWidgets('a hot phone shows the thermal warning on home', (tester) async {
      FakeNative(tester, handlers: {'getThermalStatus': (_) => 3});
      await _pumpHome(tester);
      expect(find.text(l10nTh().thermalSevereTitle), findsOneWidget);
    });

    testWidgets('pull to refresh reads the device again', (tester) async {
      final native = FakeNative(tester);
      await _pumpHome(tester);
      final before = native.called('getSetupStatus').length;
      await tester.fling(find.text(l10nTh().appTitle), const Offset(0, 900), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(native.called('getSetupStatus').length, greaterThan(before));
    });

    testWidgets('english copy', (tester) async {
      FakeNative(tester);
      await _pumpHome(tester, locale: en);
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Experimental tools'), findsOneWidget);
      expect(find.text('Tested'), findsOneWidget);
      expect(find.text('Untested'), findsNWidgets(2));
      expect(find.text('Runs hot'), findsOneWidget);
    });
  });

  group('Profiles', () {
    testWidgets('games filter is the default and counts match', (tester) async {
      FakeNative(tester, handlers: {
        'listApps': (_) => _apps,
        'getProfiles': (_) => <String, String>{'com.android.chrome': 'fps90'},
      });
      await _pumpProfiles(tester);
      expect(find.text('Wuthering Waves'), findsOneWidget);
      expect(find.text('PUBG MOBILE'), findsOneWidget);
      expect(find.text('Chrome'), findsNothing);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('switching filters shows configured and all apps', (tester) async {
      FakeNative(tester, handlers: {
        'listApps': (_) => _apps,
        'getProfiles': (_) => <String, String>{'com.android.chrome': 'fps90'},
      });
      await _pumpProfiles(tester);
      await tester.tap(find.text('ตั้งไว้แล้ว'));
      await tester.pumpAndSettle();
      expect(find.text('Chrome'), findsOneWidget);
      expect(find.text('Wuthering Waves'), findsNothing);
      expect(find.text('90 FPS'), findsOneWidget);
      await tester.ensureVisible(find.text('ทุกแอป'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ทุกแอป'));
      await tester.pumpAndSettle();
      expect(find.text('Chrome'), findsOneWidget);
      expect(find.text('Wuthering Waves'), findsOneWidget);
    });

    testWidgets('search narrows the list and clear restores it', (tester) async {
      FakeNative(tester, handlers: {'listApps': (_) => _apps});
      await _pumpProfiles(tester);
      await tester.enterText(find.byType(TextField), 'tencent');
      await tester.pumpAndSettle();
      expect(find.text('PUBG MOBILE'), findsOneWidget);
      expect(find.text('Wuthering Waves'), findsNothing);
      await tester.tap(find.byTooltip(l10nTh().clear));
      await tester.pumpAndSettle();
      expect(find.text('Wuthering Waves'), findsOneWidget);
    });

    testWidgets('no match explains itself', (tester) async {
      FakeNative(tester, handlers: {'listApps': (_) => _apps});
      await _pumpProfiles(tester);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text(l10nTh().noAppsMatch('zzz')), findsOneWidget);
    });

    testWidgets('picking an FPS for a game saves the profile', (tester) async {
      final semantics = tester.ensureSemantics();
      final native = FakeNative(tester, handlers: {'listApps': (_) => _apps});
      await _pumpProfiles(tester);
      await tester.tap(find.bySemanticsLabel('FPS ของ Wuthering Waves: ไม่ตั้ง'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('144 FPS').last);
      await tester.pumpAndSettle();
      expect(native.called('setProfile').single.arguments, {'package': 'com.kurogame.wutheringwaves.global', 'id': 'fps144'});
      semantics.dispose();
    });

    testWidgets('clearing a profile sends a null preset', (tester) async {
      final semantics = tester.ensureSemantics();
      final native = FakeNative(tester, handlers: {
        'listApps': (_) => _apps,
        'getProfiles': (_) => <String, String>{'com.tencent.ig': 'fps120'},
      });
      await _pumpProfiles(tester);
      await tester.tap(find.bySemanticsLabel('FPS ของ PUBG MOBILE: 120 FPS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ไม่ตั้ง').last);
      await tester.pumpAndSettle();
      expect(native.called('setProfile').single.arguments, {'package': 'com.tencent.ig', 'id': null});
      semantics.dispose();
    });

    testWidgets('service switch shows the configured count and saves', (tester) async {
      final native = FakeNative(tester, handlers: {
        'listApps': (_) => _apps,
        'getProfiles': (_) => <String, String>{'com.tencent.ig': 'fps120'},
        'isProfileServiceEnabled': (_) => true,
      });
      await _pumpProfiles(tester);
      expect(find.text('ตั้งไว้ 1 แอป'), findsOneWidget);
      await tester.tap(find.text(l10nTh().profilesEnable));
      await tester.pumpAndSettle();
      expect(native.called('setProfileServiceEnabled').single.arguments, {'enabled': false});
    });

    testWidgets('missing usage access warns and turning the service on asks for it first', (tester) async {
      final native = FakeNative(tester, handlers: {
        'listApps': (_) => _apps,
        'hasUsageAccess': (_) => false,
        'grantUsageAccess': (_) => false,
      });
      await _pumpProfiles(tester);
      expect(find.text(l10nTh().usageAccessRequired), findsOneWidget);
      await tester.tap(find.text(l10nTh().profilesEnable));
      await tester.pumpAndSettle();
      expect(native.called('grantUsageAccess'), hasLength(1));
      expect(native.called('openUsageAccessSettings'), hasLength(1));
      expect(native.called('setProfileServiceEnabled'), isEmpty);
    });

    testWidgets('a failing app list shows the empty state', (tester) async {
      FakeNative(tester, handlers: {'listApps': (_) => throw PlatformException(code: 'x')});
      await _pumpProfiles(tester);
      expect(find.text(l10nTh().noAppsFound), findsOneWidget);
    });
  });

  group('Setup', () {
    Future<FakeNative> pumpSetup(WidgetTester tester, Map<String, Object?> status) async {
      final native = FakeNative(tester, handlers: {'getSetupStatus': (_) => status});
      await usePhone(tester, size: _tall);
      await tester.pumpWidget(localized(Scaffold(body: SetupScreen(refresh: ValueNotifier(0)))));
      await tester.pumpAndSettle();
      return native;
    }

    testWidgets('complete: subtitle, no Shizuku card, re-run and about', (tester) async {
      await pumpSetup(tester, readySetup);
      expect(find.text('ครบ 4 จาก 4 · ไม่ต้องเปิด Shizuku ค้างไว้'), findsOneWidget);
      expect(find.text(l10nTh().shizukuReady), findsNothing);
      expect(find.text('ตั้งค่าอัตโนมัติอีกครั้ง'), findsOneWidget);
      expect(find.text(l10nTh().setupSectionAbout), findsOneWidget);
    });

    testWidgets('incomplete: progress subtitle and the Shizuku card', (tester) async {
      await pumpSetup(tester, const {'shizuku': 'noPermission', 'helper': true});
      expect(find.text('ทำแล้ว 1 จาก 4'), findsOneWidget);
      expect(find.text(l10nTh().shizukuNoPermission), findsOneWidget);
    });

    testWidgets('limitations expand to the existing copy', (tester) async {
      await pumpSetup(tester, readySetup);
      expect(find.text(l10nTh().setupLimitsBody), findsNothing);
      await tester.tap(find.text(l10nTh().setupLimitsTitle));
      await tester.pumpAndSettle();
      expect(find.text(l10nTh().setupLimitsBody), findsOneWidget);
    });
  });

  group('Whole app', () {
    for (final locale in [th, en]) {
      testWidgets('every tab fits a 360 px phone (${locale.languageCode})', (tester) async {
        await usePhone(tester);
        FakeNative(tester, handlers: {
          'getSetupStatus': (_) => const <String, Object?>{'shizuku': 'noPermission', 'helper': true},
          'getCurrent': (_) => const <String, Object?>{'value': '1:105:26574:72:144'},
          'listApps': (_) => [
                <String, Object?>{'package': 'com.example.verylongpackagename.game', 'label': 'Very Long Game Name Here', 'isGame': true},
                ..._apps,
              ],
          'getProfiles': (_) => const <String, String>{'com.example.verylongpackagename.game': 'fps144'},
          'isProfileServiceEnabled': (_) => true,
          'hasUsageAccess': (_) => false,
          'getThermalStatus': (_) => 4,
        });
        await tester.pumpWidget(OriginTweaksApp(locale: locale));
        await tester.pumpAndSettle();
        final l = lookup(locale);

        final homeScroll = find.descendant(of: find.byType(HomeScreen), matching: find.byType(Scrollable)).first;
        await tester.scrollUntilVisible(find.text(l.tileHintLongPress), 300, scrollable: homeScroll);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text(l.navProfiles));
        await tester.pumpAndSettle();
        expect(find.byType(ProfilesScreen), findsOneWidget);
        final profileScroll = find.descendant(of: find.byType(ProfilesScreen), matching: find.byType(Scrollable)).first;
        await tester.scrollUntilVisible(find.text('PUBG MOBILE'), 200, scrollable: profileScroll);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text(l.navSetup));
        await tester.pumpAndSettle();
        final setupScroll = find.descendant(of: find.byType(SetupScreen), matching: find.byType(Scrollable)).first;
        await tester.scrollUntilVisible(find.text(l.setupLimitsTitle), 300, scrollable: setupScroll);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text(l.navFrameGen));
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen).hitTestable(), findsOneWidget);
      });
    }

    testWidgets('resuming the app refreshes the device state', (tester) async {
      final native = FakeNative(tester);
      await usePhone(tester, size: _tall);
      await tester.pumpWidget(const OriginTweaksApp(locale: th));
      await tester.pumpAndSettle();
      final before = native.called('getSetupStatus').length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(native.called('getSetupStatus').length, greaterThan(before));
    });

    testWidgets('checks for updates once on launch', (tester) async {
      final native = FakeNative(tester);
      await usePhone(tester, size: _tall);
      await tester.pumpWidget(const OriginTweaksApp(locale: th));
      await tester.pumpAndSettle();
      expect(native.called('checkUpdate'), hasLength(1));
    });
  });
}
