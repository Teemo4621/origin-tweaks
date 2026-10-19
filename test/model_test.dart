import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origin_tweaks/models/preset.dart';
import 'package:origin_tweaks/native/native_bridge.dart';
import 'package:origin_tweaks/screens/profiles_screen.dart';
import 'package:origin_tweaks/theme.dart';
import 'package:origin_tweaks/widgets/onboarding_card.dart';
import 'package:origin_tweaks/widgets/tool_list.dart';

import 'support.dart';

Map<String, dynamic> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('Preset', () {
    test('fromId resolves known ids only', () {
      for (final preset in Preset.values) {
        expect(Preset.fromId(preset.id), preset);
      }
      expect(Preset.fromId('fps60'), isNull);
      expect(Preset.fromId(''), isNull);
      expect(Preset.fromId(null), isNull);
    });

    test('fps pairs match the native presets', () {
      expect([for (final p in Preset.values) p.fps], [null, 90, 120, 144]);
      expect([for (final p in Preset.values) p.sourceFps], [null, 45, 60, 48]);
    });

    test('only off is disabled and only 144 is tested', () {
      expect(Preset.values.where((p) => !p.enabled), [Preset.off]);
      expect(Preset.values.where((p) => p.tested), [Preset.fps144]);
    });

    test('meter fills one more segment per step and is empty when off', () {
      expect([for (final p in Preset.values) p.meterLevel], [0, 2, 3, 4]);
    });

    test('labels per locale', () {
      expect(Preset.off.label(l10nTh()), 'ปิด');
      expect(Preset.off.label(l10nEn()), 'Off');
      for (final preset in Preset.values.skip(1)) {
        expect(preset.label(l10nTh()), '${preset.fps} FPS');
        expect(preset.label(l10nEn()), '${preset.fps} FPS');
      }
    });
  });

  group('ApplyResult', () {
    test('codes map to FrameGen RESULT_* constants', () {
      expect(ApplyResult.fromCode(0), ApplyResult.ok);
      expect(ApplyResult.fromCode(1), ApplyResult.failed);
      expect(ApplyResult.fromCode(2), ApplyResult.blocked);
      expect(ApplyResult.fromCode(3), ApplyResult.noPermission);
      expect(ApplyResult.fromCode(4), ApplyResult.noHelper);
    });

    test('unknown codes fall back to failed', () {
      for (final code in [null, -1, 5, 99]) {
        expect(ApplyResult.fromCode(code), ApplyResult.failed, reason: 'code $code');
      }
    });

    test('messages per locale', () {
      final t = l10nTh();
      expect(ApplyResult.ok.message(t, Preset.fps144), 'เปิด 144 FPS แล้ว');
      expect(ApplyResult.ok.message(t, Preset.off), 'ปิดแทรกเฟรมแล้ว');
      expect(ApplyResult.noHelper.message(t, Preset.fps90), 'ยังตั้งค่าครั้งแรกไม่เสร็จ');
      expect(ApplyResult.noPermission.message(t, Preset.fps90), 'ยังตั้งค่าครั้งแรกไม่เสร็จ');
      expect(ApplyResult.failed.message(t, Preset.fps90), 'ตั้งค่าไม่สำเร็จ');
      expect(ApplyResult.blocked.message(t, Preset.fps90), t.applyBlocked);
      final e = l10nEn();
      expect(ApplyResult.ok.message(e, Preset.fps144), '144 FPS enabled');
      expect(ApplyResult.ok.message(e, Preset.off), 'Frame generation turned off');
    });
  });

  group('CurrentSetting', () {
    test('no value means off', () {
      expect(const CurrentSetting().effective, Preset.off);
      expect(const CurrentSetting().isCustom, isFalse);
    });

    test('a known preset wins over the raw value', () {
      const setting = CurrentSetting(value: '1:1::48:144', preset: Preset.fps144);
      expect(setting.effective, Preset.fps144);
      expect(setting.isCustom, isFalse);
    });

    test('an unknown value is custom', () {
      const setting = CurrentSetting(value: '1:105:26574:72:144');
      expect(setting.effective, isNull);
      expect(setting.isCustom, isTrue);
    });
  });

  group('SetupStatus', () {
    test('fromMap reads every flag and the error', () {
      final status = SetupStatus.fromMap({...readySetup, 'error': 'secure'});
      expect(status.shizuku, ShizukuState.ready);
      expect(status.ready, isTrue);
      expect(status.complete, isTrue);
      expect(status.doneCount, SetupStatus.totalSteps);
      expect(status.error, 'secure');
    });

    test('missing keys default to not done', () {
      final status = SetupStatus.fromMap(const {});
      expect(status.shizuku, ShizukuState.notRunning);
      expect(status.doneCount, 0);
      expect(status.ready, isFalse);
    });

    test('ready needs helper and secure settings; complete needs all four', () {
      expect(const SetupStatus(helper: true).ready, isFalse);
      expect(const SetupStatus(helper: true, secureSettings: true).ready, isTrue);
      expect(const SetupStatus(helper: true, secureSettings: true, usageAccess: true).complete, isFalse);
    });

    test('Shizuku is usable when ready or waiting for permission', () {
      expect(const SetupStatus(shizuku: ShizukuState.ready).shizukuUsable, isTrue);
      expect(const SetupStatus(shizuku: ShizukuState.noPermission).shizukuUsable, isTrue);
      for (final state in [ShizukuState.notRunning, ShizukuState.notInstalled, ShizukuState.unsupported]) {
        expect(SetupStatus(shizuku: state).shizukuUsable, isFalse, reason: '$state');
      }
    });

    test('unknown Shizuku state ids fall back to not running', () {
      expect(ShizukuState.fromId('noPermission'), ShizukuState.noPermission);
      expect(ShizukuState.fromId('bogus'), ShizukuState.notRunning);
      expect(ShizukuState.fromId(null), ShizukuState.notRunning);
    });

    test('onboarding counts its three steps', () {
      expect(OnboardingCard.completedSteps(const SetupStatus()), 0);
      expect(OnboardingCard.completedSteps(const SetupStatus(shizuku: ShizukuState.noPermission)), 1);
      expect(OnboardingCard.completedSteps(const SetupStatus(shizuku: ShizukuState.ready)), 2);
      expect(OnboardingCard.completedSteps(const SetupStatus(helper: true, secureSettings: true)), 3);
    });
  });

  group('ThermalLevel', () {
    test('maps PowerManager thermal status codes', () {
      expect(ThermalLevel.fromCode(null), ThermalLevel.normal);
      for (final code in [0, 1, 2]) {
        expect(ThermalLevel.fromCode(code), ThermalLevel.normal, reason: 'code $code');
      }
      expect(ThermalLevel.fromCode(3), ThermalLevel.severe);
      for (final code in [4, 5, 6]) {
        expect(ThermalLevel.fromCode(code), ThermalLevel.critical, reason: 'code $code');
      }
    });
  });

  group('Tweak', () {
    test('ids match the Kotlin Tweaks registry', () {
      expect([for (final t in Tweak.values) t.id], ['monster_plus', 'hawkeye', 'touch_boost']);
    });

    test('the home list shows every tweak once, Monster+ last', () {
      expect(toolOrder.toSet(), Tweak.values.toSet());
      expect(toolOrder.last, Tweak.monsterPlus);
    });

    test('only Monster+ is flagged as running hot', () {
      expect(Tweak.values.where((t) => t.runsHot), [Tweak.monsterPlus]);
    });

    test('sheet bodies use the existing card copy unchanged', () {
      final arb = _arb('th');
      final t = l10nTh();
      expect(Tweak.monsterPlus.body(t), arb['monsterPlusBody']);
      expect(Tweak.hawkeye.body(t), arb['hawkeyeBody']);
      expect(Tweak.touchBoost.body(t), arb['touchBoostBody']);
      expect(Tweak.monsterPlus.body(l10nEn()), _arb('en')['monsterPlusBody']);
    });

    test('status parses values and flags drift only while enabled', () {
      final on = TweakStatus.fromMap(tweakMap(enabled: true, values: [
        ('system/power_save_type', '8', '8'),
        ('secure/power_save_type', '1', '8'),
      ]));
      expect(on.values.map((v) => v.matches), [true, false]);
      expect(on.overwritten, isTrue);

      final off = TweakStatus.fromMap(tweakMap(values: [('secure/power_save_type', '1', '8')]));
      expect(off.overwritten, isFalse);

      final unread = TweakStatus.fromMap(tweakMap(enabled: true, values: [('system/x', null, '1')]));
      expect(unread.values.single.matches, isFalse);
      expect(TweakStatus.fromMap(const {}).values, isEmpty);
    });
  });

  group('Update and install results', () {
    test('install codes match Updater constants', () {
      expect(InstallResult.fromCode(0), InstallResult.started);
      expect(InstallResult.fromCode(1), InstallResult.downloadFailed);
      expect(InstallResult.fromCode(2), InstallResult.checksumFailed);
      expect(InstallResult.fromCode(3), InstallResult.failed);
      expect(InstallResult.fromCode(4), InstallResult.needsPermission);
      expect(InstallResult.fromCode(null), InstallResult.failed);
    });

    test('update info tolerates missing fields', () {
      final info = UpdateInfo.fromMap({'version': '0.1.0-alpha.5', 'size': 12.0});
      expect(info.version, '0.1.0-alpha.5');
      expect(info.size, 12);
      expect(info.notes, isEmpty);
      expect(UpdateInfo.fromMap(const {}).version, isEmpty);
    });
  });

  group('App lists', () {
    const apps = [
      AppEntry(packageName: 'com.b.app', label: 'Beta', isGame: false),
      AppEntry(packageName: 'com.z.game', label: 'Zeta', isGame: true),
      AppEntry(packageName: 'com.a.game', label: 'alpha', isGame: true),
    ];

    test('games first, then case-insensitive by name', () {
      expect(sortApps(apps).map((a) => a.label), ['alpha', 'Zeta', 'Beta']);
    });

    test('search matches label or package, ignoring case and spaces', () {
      final sorted = sortApps(apps);
      expect(filterApps(sorted, 'z.GAME').single.label, 'Zeta');
      expect(filterApps(sorted, ' BETA ').single.label, 'Beta');
      expect(filterApps(sorted, '  ').length, 3);
      expect(filterApps(sorted, 'nothing'), isEmpty);
    });

    test('filters by kind', () {
      final profiles = {'com.b.app': Preset.fps120};
      expect(filterByKind(apps, AppFilter.games, profiles).map((a) => a.label), ['Zeta', 'alpha']);
      expect(filterByKind(apps, AppFilter.configured, profiles).single.label, 'Beta');
      expect(filterByKind(apps, AppFilter.all, profiles).length, 3);
      expect(filterByKind(apps, AppFilter.configured, const {}), isEmpty);
    });
  });

  group('Localization', () {
    test('Thai and English define the same keys', () {
      final thKeys = _arb('th').keys.where((k) => !k.startsWith('@')).toSet();
      final enKeys = _arb('en').keys.where((k) => !k.startsWith('@')).toSet();
      expect(thKeys.difference(enKeys), isEmpty, reason: 'missing in English');
      expect(enKeys.difference(thKeys), isEmpty, reason: 'missing in Thai');
    });

    test('no translation is empty', () {
      for (final lang in ['th', 'en']) {
        _arb(lang).forEach((key, value) {
          if (!key.startsWith('@') && value is String) expect(value.trim(), isNotEmpty, reason: '$lang:$key');
        });
      }
    });

    test('placeholders survive translation', () {
      final t = l10nTh();
      final e = l10nEn();
      expect(t.setupStepOf(2, 3), 'ขั้นที่ 2 จาก 3');
      expect(e.setupStepOf(2, 3), 'Step 2 of 3');
      expect(t.updateBannerTitle('0.2.0'), contains('0.2.0'));
      expect(e.presetFor('PUBG', '120 FPS'), 'FPS for PUBG: 120 FPS');
      expect(t.tweakEnabled(t.hawkeyeTitle), 'เปิดภาพคมชัด Hawk-eyeแล้ว');
      expect(e.profilesConfiguredCount(1), '1 app configured');
      expect(e.profilesConfiguredCount(3), '3 apps configured');
    });
  });

  group('Theme', () {
    test('is dark with the instrument-panel palette and bundled fonts', () {
      final theme = buildTheme();
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, Palette.ground);
      expect(theme.colorScheme.primary, Palette.accent);
      expect(theme.textTheme.bodyMedium?.fontFamily, Fonts.body);
    });

    test('text on the main surfaces meets WCAG AA contrast', () {
      double luminance(Color c) => c.computeLuminance();
      double ratio(Color a, Color b) {
        final hi = luminance(a) > luminance(b) ? luminance(a) : luminance(b);
        final lo = luminance(a) > luminance(b) ? luminance(b) : luminance(a);
        return (hi + 0.05) / (lo + 0.05);
      }

      for (final bg in [Palette.ground, Palette.surface, Palette.raised]) {
        expect(ratio(Palette.text, bg), greaterThan(4.5));
        expect(ratio(Palette.muted, bg), greaterThan(4.5));
        expect(ratio(Palette.accent, bg), greaterThan(4.5));
      }
      expect(ratio(Palette.onAccent, Palette.accent), greaterThan(4.5));
      expect(ratio(Palette.onAccentSoft, Palette.accent), greaterThan(4.5));
      expect(ratio(Palette.heatText, Palette.heatSoft), greaterThan(4.5));
      expect(ratio(Palette.ground, Palette.text), greaterThan(4.5));
    });

    test('the launcher icon background matches the app ground colour', () {
      final xml = File('android/app/src/main/res/drawable/ic_launcher_background.xml').readAsStringSync();
      final hex = Palette.ground.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0');
      expect(xml, contains('#$hex'));
    });
  });
}
