import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origin_tweaks/models/preset.dart';
import 'package:origin_tweaks/native/native_bridge.dart';
import 'package:origin_tweaks/native/update_controller.dart';
import 'package:origin_tweaks/widgets/onboarding_card.dart';
import 'package:origin_tweaks/widgets/panel.dart';
import 'package:origin_tweaks/widgets/preset_selector.dart';
import 'package:origin_tweaks/widgets/setup_card.dart';
import 'package:origin_tweaks/widgets/status_hero.dart';
import 'package:origin_tweaks/widgets/super_res_card.dart';
import 'package:origin_tweaks/widgets/tool_list.dart';
import 'package:origin_tweaks/widgets/update_card.dart';

import 'support.dart';

TweakStatus _status({bool enabled = false, List<(String, String?, String)> values = const []}) =>
    TweakStatus.fromMap(tweakMap(enabled: enabled, values: values));

void main() {
  group('StatusHero', () {
    testWidgets('shows the active FPS, its source range and a full meter', (tester) async {
      await tester.pumpWidget(inScaffold(
        const StatusHero(current: CurrentSetting(value: 'x', preset: Preset.fps144), loaded: true, busy: false),
      ));
      expect(find.text('144'), findsOneWidget);
      expect(find.text('FPS'), findsOneWidget);
      expect(find.text('48 → 144'), findsOneWidget);
      expect(find.text(l10nTh().heroActiveCaption), findsOneWidget);
      expect(tester.widget<SegmentMeter>(find.byType(SegmentMeter)).filled, 4);
    });

    testWidgets('off shows the off label, no range and an empty meter', (tester) async {
      await tester.pumpWidget(inScaffold(const StatusHero(current: CurrentSetting(), loaded: true, busy: false)));
      expect(find.text('ปิด'), findsOneWidget);
      expect(find.textContaining('→'), findsNothing);
      expect(tester.widget<SegmentMeter>(find.byType(SegmentMeter)).filled, 0);
      expect(find.text(l10nTh().heroOffCaption), findsOneWidget);
    });

    testWidgets('a value written by GameCube is shown as custom', (tester) async {
      await tester.pumpWidget(inScaffold(
        const StatusHero(current: CurrentSetting(value: '1:105:26574:72:144'), loaded: true, busy: false),
      ));
      expect(find.text(l10nTh().heroCustom), findsOneWidget);
      expect(find.text(l10nTh().heroCustomCaption), findsOneWidget);
    });

    testWidgets('loading shows a dash and busy shows a progress bar', (tester) async {
      await tester.pumpWidget(inScaffold(const StatusHero(current: CurrentSetting(), loaded: false, busy: true)));
      expect(find.text('—'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('announces the current mode to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(inScaffold(
        const StatusHero(current: CurrentSetting(value: 'x', preset: Preset.fps120), loaded: true, busy: false),
      ));
      expect(find.bySemanticsLabel(RegExp('^${RegExp.escape(l10nTh().heroTitle)}: 120 FPS')), findsOneWidget);
      handle.dispose();
    });
  });

  group('PresetSelector', () {
    Widget selector({Preset? selected, Preset? pending, bool enabled = true, ValueChanged<Preset>? onSelected}) =>
        inScaffold(PresetSelector(
          selected: selected,
          pending: pending,
          enabled: enabled,
          onSelected: onSelected ?? (_) {},
        ));

    testWidgets('shows four choices with tested/untested captions', (tester) async {
      await tester.pumpWidget(selector(selected: Preset.fps144));
      for (final label in ['ปิด', '90', '120', '144']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('ทดสอบแล้ว'), findsOneWidget);
      expect(find.text('ยังไม่ทดสอบ'), findsNWidgets(2));
    });

    testWidgets('reports the tapped preset', (tester) async {
      final tapped = <Preset>[];
      await tester.pumpWidget(selector(selected: Preset.off, onSelected: tapped.add));
      await tester.tap(find.text('120'));
      await tester.tap(find.text('ปิด'));
      expect(tapped, [Preset.fps120, Preset.off]);
    });

    testWidgets('ignores taps while disabled or while a change is pending', (tester) async {
      final tapped = <Preset>[];
      await tester.pumpWidget(selector(enabled: false, onSelected: tapped.add));
      await tester.tap(find.text('144'), warnIfMissed: false);
      await tester.pumpWidget(selector(pending: Preset.fps90, onSelected: tapped.add));
      await tester.tap(find.text('144'), warnIfMissed: false);
      expect(tapped, isEmpty);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('90'), findsNothing);
    });

    testWidgets('marks the selected choice for accessibility', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(selector(selected: Preset.fps144));
      expect(
        tester.getSemantics(find.bySemanticsLabel('144 FPS, ทดสอบแล้ว')),
        matchesSemantics(
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          isEnabled: true,
          hasEnabledState: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('90 FPS, ยังไม่ทดสอบ')),
        matchesSemantics(
          isButton: true,
          hasSelectedState: true,
          isEnabled: true,
          hasEnabledState: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('choice buttons are at least 48 px tall', (tester) async {
      await tester.pumpWidget(selector());
      final box = tester.getSize(find.ancestor(of: find.text('90'), matching: find.byType(InkWell)).first);
      expect(box.height, greaterThanOrEqualTo(48));
    });
  });

  group('ToolList', () {
    Widget list({
      Map<Tweak, TweakStatus> statuses = const {},
      bool enabled = true,
      Tweak? busy,
      void Function(Tweak, bool)? onChanged,
      ValueChanged<Tweak>? onOpen,
    }) =>
        inScaffold(ToolList(
          statuses: statuses,
          enabled: enabled,
          busy: busy,
          onChanged: onChanged ?? (_, _) {},
          onOpen: onOpen ?? (_) {},
        ));

    testWidgets('lists every tool in order with its short description', (tester) async {
      await tester.pumpWidget(list());
      final t = l10nTh();
      final titles = [t.hawkeyeTitle, t.touchBoostTitle, t.monsterPlusTitle];
      final ys = [for (final title in titles) tester.getTopLeft(find.text(title)).dy];
      expect(ys, orderedEquals([...ys]..sort()));
      for (final short in [t.hawkeyeShort, t.touchBoostShort, t.monsterPlusShort]) {
        expect(find.text(short), findsOneWidget);
      }
      expect(find.byType(Switch), findsNWidgets(3));
    });

    testWidgets('only Monster+ carries the heat tag', (tester) async {
      await tester.pumpWidget(list());
      expect(find.text('ร้อนง่าย'), findsOneWidget);
      final monsterRow = find.ancestor(of: find.text('Monster+'), matching: find.byType(ToolRow));
      expect(find.descendant(of: monsterRow, matching: find.text('ร้อนง่าย')), findsOneWidget);
    });

    testWidgets('switches report the tweak and the new value', (tester) async {
      final changes = <(Tweak, bool)>[];
      await tester.pumpWidget(list(
        statuses: {Tweak.touchBoost: _status(enabled: true)},
        onChanged: (tweak, value) => changes.add((tweak, value)),
      ));
      await tester.tap(find.byType(Switch).at(0));
      await tester.tap(find.byType(Switch).at(1));
      expect(changes, [(Tweak.hawkeye, true), (Tweak.touchBoost, false)]);
    });

    testWidgets('tapping a row opens its details', (tester) async {
      final opened = <Tweak>[];
      await tester.pumpWidget(list(onOpen: opened.add));
      await tester.tap(find.text(l10nTh().touchBoostShort));
      await tester.tap(find.text('Monster+'));
      expect(opened, [Tweak.touchBoost, Tweak.monsterPlus]);
    });

    testWidgets('disabled switches and a busy row cannot be toggled', (tester) async {
      final changes = <(Tweak, bool)>[];
      await tester.pumpWidget(list(enabled: false, onChanged: (t, v) => changes.add((t, v))));
      for (final element in find.byType(Switch).evaluate()) {
        expect((element.widget as Switch).onChanged, isNull);
      }
      await tester.pumpWidget(list(busy: Tweak.hawkeye, onChanged: (t, v) => changes.add((t, v))));
      expect(find.byType(Switch), findsNWidgets(2));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(changes, isEmpty);
    });

    testWidgets('a drifted tool shows a warning mark', (tester) async {
      await tester.pumpWidget(list(statuses: {
        Tweak.hawkeye: _status(enabled: true, values: [('system/gamecube_hawkeye_effective', '0', '1')]),
        Tweak.touchBoost: _status(enabled: true, values: [('system/vts_game_para_adjust', '0,5,5,5', '0,5,5,5')]),
      }));
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });

  group('ToolSheet', () {
    Future<List<bool>> openSheet(
      WidgetTester tester, {
      required Tweak tweak,
      TweakStatus status = const TweakStatus(),
      int thermal = 0,
      bool enabled = true,
    }) async {
      FakeNative(tester, handlers: {'getThermalStatus': (_) => thermal});
      final changes = <bool>[];
      var current = status;
      await tester.pumpWidget(localized(Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showToolSheet(
              context,
              tweak: tweak,
              enabled: enabled,
              load: () async => current,
              onChanged: (value) async {
                changes.add(value);
                current = TweakStatus(enabled: value, values: current.values);
              },
            ),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return changes;
    }

    testWidgets('shows the card copy, live values and the legend', (tester) async {
      await openSheet(tester, tweak: Tweak.monsterPlus, status: _status(enabled: true, values: [
        ('system/power_save_type', '8', '8'),
        ('secure/power_save_type', '1', '8'),
      ]));
      final t = l10nTh();
      expect(find.text(t.monsterPlusBody), findsOneWidget);
      expect(find.text('system/power_save_type'), findsOneWidget);
      expect(find.text(' ≠ 8'), findsOneWidget);
      expect(find.text(t.liveValuesLegend), findsOneWidget);
      expect(find.text('ทดลอง · เปิดอยู่'), findsOneWidget);
    });

    testWidgets('warns when the phone is critically hot', (tester) async {
      await openSheet(tester, tweak: Tweak.monsterPlus, thermal: 4);
      expect(find.text(l10nTh().thermalCriticalTitle), findsOneWidget);
      expect(find.text(l10nTh().thermalBody), findsOneWidget);
    });

    testWidgets('stays quiet when the phone is cool', (tester) async {
      await openSheet(tester, tweak: Tweak.hawkeye, thermal: 2);
      expect(find.text(l10nTh().thermalCriticalTitle), findsNothing);
      expect(find.text(l10nTh().thermalSevereTitle), findsNothing);
    });

    testWidgets('turn off and restore calls back with false, then hides itself', (tester) async {
      final changes = await openSheet(tester, tweak: Tweak.touchBoost, status: _status(enabled: true));
      await tester.tap(find.text('ปิดและคืนค่า'));
      await tester.pumpAndSettle();
      expect(changes, [false]);
      expect(find.text('ปิดและคืนค่า'), findsNothing);
      expect(find.text('ทดลอง · ปิดอยู่'), findsOneWidget);
    });

    testWidgets('the sheet switch turns a tool on', (tester) async {
      final changes = await openSheet(tester, tweak: Tweak.hawkeye);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(changes, [true]);
    });

    testWidgets('without setup the switch is disabled and values explain why', (tester) async {
      await openSheet(tester, tweak: Tweak.hawkeye, enabled: false);
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
      expect(find.text(l10nTh().liveValuesEmpty), findsOneWidget);
    });

    testWidgets('done closes the sheet', (tester) async {
      await openSheet(tester, tweak: Tweak.hawkeye);
      await tester.tap(find.text('เสร็จ'));
      await tester.pumpAndSettle();
      expect(find.byType(ToolSheet), findsNothing);
    });
  });

  group('ThermalWarning', () {
    testWidgets('titles differ by level', (tester) async {
      await tester.pumpWidget(inScaffold(const ThermalWarning(level: ThermalLevel.severe), locale: en));
      expect(find.text('Phone is very hot'), findsOneWidget);
      await tester.pumpWidget(inScaffold(const ThermalWarning(level: ThermalLevel.critical), locale: en));
      expect(find.text('Phone is critically hot'), findsOneWidget);
    });
  });

  group('OnboardingCard', () {
    Widget card(SetupStatus status) =>
        inScaffold(OnboardingCard(status: status, onChanged: (_) {}, onRefresh: () {}, onOpenSetup: () {}));

    testWidgets('Shizuku not running: step 1 and an open-Shizuku button', (tester) async {
      final native = FakeNative(tester);
      await tester.pumpWidget(card(const SetupStatus(shizuku: ShizukuState.notRunning)));
      expect(find.text('ขั้นที่ 1 จาก 3'), findsOneWidget);
      expect(find.text(l10nTh().onboardingTitle), findsOneWidget);
      await tester.tap(find.text('เปิด Shizuku'));
      expect(native.called('openShizuku'), hasLength(1));
    });

    testWidgets('waiting for permission: step 2 and auto setup', (tester) async {
      await tester.pumpWidget(card(const SetupStatus(shizuku: ShizukuState.noPermission)));
      expect(find.text('ขั้นที่ 2 จาก 3'), findsOneWidget);
      expect(find.text('ตั้งค่าอัตโนมัติ'), findsOneWidget);
    });

    testWidgets('Shizuku missing: offers a re-check instead', (tester) async {
      await tester.pumpWidget(card(const SetupStatus(shizuku: ShizukuState.notInstalled)));
      expect(find.text('ตรวจอีกครั้ง'), findsOneWidget);
      expect(find.text('ตั้งค่าอัตโนมัติ'), findsNothing);
    });

    testWidgets('shows the last error', (tester) async {
      await tester.pumpWidget(card(const SetupStatus(shizuku: ShizukuState.ready, error: 'secure')));
      expect(find.textContaining(l10nTh().setupErrorSecure), findsOneWidget);
    });

    testWidgets('auto setup runs the native flow and reports the result', (tester) async {
      final native = FakeNative(tester, handlers: {'autoSetup': (_) => readySetup});
      SetupStatus? reported;
      await tester.pumpWidget(inScaffold(OnboardingCard(
        status: const SetupStatus(shizuku: ShizukuState.noPermission),
        onChanged: (s) => reported = s,
        onRefresh: () {},
      )));
      await tester.tap(find.text('ตั้งค่าอัตโนมัติ'));
      await tester.pumpAndSettle();
      expect(native.called('requestShizuku'), hasLength(1));
      expect(native.called('autoSetup'), hasLength(1));
      expect(reported?.ready, isTrue);
      expect(find.text(l10nTh().autoSetupDone), findsOneWidget);
    });
  });

  group('SetupCard', () {
    testWidgets('incomplete: required tags, usage access shortcut and auto setup', (tester) async {
      final native = FakeNative(tester);
      await tester.pumpWidget(inScaffold(SetupCard(
        status: const SetupStatus(shizuku: ShizukuState.ready, battery: true),
        onChanged: (_) {},
      )));
      expect(find.text('จำเป็น'), findsNWidgets(2));
      expect(find.text('ตั้งค่าอัตโนมัติ'), findsOneWidget);
      await tester.tap(find.text('เปิด'));
      expect(native.called('openUsageAccessSettings'), hasLength(1));
    });

    testWidgets('complete: no tags and a re-run button', (tester) async {
      await tester.pumpWidget(inScaffold(SetupCard(status: SetupStatus.fromMap(readySetup), onChanged: (_) {})));
      expect(find.text('จำเป็น'), findsNothing);
      expect(find.text('ตั้งค่าอัตโนมัติอีกครั้ง'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(4));
    });

    testWidgets('start-Shizuku hint when it is not usable', (tester) async {
      await tester.pumpWidget(inScaffold(SetupCard(status: const SetupStatus(), onChanged: (_) {})));
      expect(find.text(l10nTh().setupStartShizukuFirst), findsOneWidget);
    });
  });

  group('Updates', () {
    testWidgets('banner and about card offer the new version and install it', (tester) async {
      final native = FakeNative(tester, handlers: {
        'getAppVersion': (_) => '0.1.0-alpha.4',
        'checkUpdate': (_) => <String, Object?>{'version': '0.1.0-alpha.5', 'notes': 'x', 'size': 1},
        'installUpdate': (_) => 4,
      });
      final controller = UpdateController.instance;
      await controller.check();
      expect(controller.status, UpdateStatus.available);

      await tester.pumpWidget(inScaffold(Column(children: [
        UpdateBanner(controller: controller),
        AboutCard(controller: controller),
      ])));
      expect(find.text('มีเวอร์ชันใหม่ 0.1.0-alpha.5'), findsOneWidget);
      expect(find.text('เวอร์ชัน 0.1.0-alpha.4'), findsOneWidget);
      expect(find.text('มีเวอร์ชันใหม่: v0.1.0-alpha.5'), findsOneWidget);

      await tester.tap(find.text('อัปเดต').first);
      await tester.pumpAndSettle();
      expect(native.called('installUpdate'), hasLength(1));
      expect(find.text(l10nTh().updateNeedsPermission), findsOneWidget);
    });

    testWidgets('up to date: the banner hides and the about card can check again', (tester) async {
      final native = FakeNative(tester, handlers: {'checkUpdate': (_) => null});
      final controller = UpdateController.instance;
      await controller.check();
      expect(controller.status, UpdateStatus.upToDate);

      await tester.pumpWidget(inScaffold(Column(children: [
        UpdateBanner(controller: controller),
        AboutCard(controller: controller),
      ])));
      expect(find.textContaining('มีเวอร์ชันใหม่'), findsNothing);
      expect(find.text('เป็นเวอร์ชันล่าสุดแล้ว'), findsOneWidget);
      await tester.tap(find.text('ตรวจหาอัปเดต'));
      await tester.pumpAndSettle();
      expect(native.called('checkUpdate'), hasLength(2));
    });

    testWidgets('a failed check keeps the button and says so', (tester) async {
      FakeNative(tester, handlers: {'checkUpdate': (_) => throw Exception('offline')});
      final controller = UpdateController.instance;
      await controller.check();
      await tester.pumpWidget(inScaffold(AboutCard(controller: controller)));
      expect(find.text(l10nTh().updateCheckFailed), findsOneWidget);
      expect(find.text('ตรวจหาอัปเดต'), findsOneWidget);
    });

    test('install messages cover every result', () {
      final t = l10nTh();
      expect({for (final r in InstallResult.values) installMessage(t, r)}, hasLength(InstallResult.values.length));
    });
  });

  group('Shared pieces', () {
    testWidgets('status chip and screen header', (tester) async {
      await tester.pumpWidget(inScaffold(const Column(children: [
        ScreenHeader(title: 'Title', subtitle: 'Sub', trailing: StatusChip(label: 'พร้อมใช้งาน', active: true)),
        SectionLabel('Tools', trailing: 'hint'),
      ])));
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Sub'), findsOneWidget);
      expect(find.text('พร้อมใช้งาน'), findsOneWidget);
      expect(find.text('hint'), findsOneWidget);
    });

    testWidgets('segment meter fills the requested count', (tester) async {
      await tester.pumpWidget(inScaffold(const SegmentMeter(filled: 2, count: 3)));
      await tester.pumpAndSettle();
      final colors = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((c) => (c.decoration as BoxDecoration).color)
          .toList();
      expect(colors, hasLength(3));
      expect(colors[0], colors[1]);
      expect(colors[2], isNot(colors[0]));
    });

    testWidgets('hidden super resolution card still works if re-enabled', (tester) async {
      int? picked;
      await tester.pumpWidget(inScaffold(
        SuperResCard(level: 0, enabled: true, busy: false, onChanged: (v) => picked = v),
        locale: en,
      ));
      await tester.tap(find.text('Extreme'));
      expect(picked, 2);
    });
  });
}
