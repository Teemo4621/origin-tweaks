import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:origin_tweaks/l10n/gen/app_localizations.dart';
import 'package:origin_tweaks/theme.dart';

const th = Locale('th');
const en = Locale('en');

AppLocalizations l10nTh() => lookupAppLocalizations(th);
AppLocalizations l10nEn() => lookupAppLocalizations(en);
AppLocalizations lookup(Locale locale) => lookupAppLocalizations(locale);

Widget localized(Widget home, {Locale locale = th}) => MaterialApp(
      theme: buildTheme(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

Widget inScaffold(Widget child, {Locale locale = th}) => localized(
      Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)),
      locale: locale,
    );

Future<void> usePhone(WidgetTester tester, {Size size = const Size(360, 760)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Map<String, Object?> tweakMap({bool enabled = false, List<(String, String?, String)> values = const []}) => {
      'enabled': enabled,
      'values': [
        for (final (key, value, expected) in values) {'key': key, 'value': value, 'expected': expected},
      ],
    };

const readySetup = <String, Object?>{
  'shizuku': 'ready',
  'helper': true,
  'secureSettings': true,
  'usageAccess': true,
  'battery': true,
};

class FakeNative {
  FakeNative(WidgetTester tester, {Map<String, Object? Function(MethodCall call)>? handlers}) {
    this.handlers.addAll(handlers ?? const {});
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final handler = this.handlers[call.method];
      return handler == null ? defaults(call) : handler(call);
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
  }

  static const channel = MethodChannel('origin_tweaks/native');

  final calls = <MethodCall>[];
  final handlers = <String, Object? Function(MethodCall call)>{};

  Object? defaults(MethodCall call) => switch (call.method) {
        'getSetupStatus' => readySetup,
        'getCurrent' => <String, Object?>{'value': '1:1::48:144', 'presetId': 'fps144'},
        'getTweak' => tweakMap(),
        'getThermalStatus' => 0,
        'listApps' => const <Object?>[],
        'getProfiles' => const <String, String>{},
        'isProfileServiceEnabled' => false,
        'hasUsageAccess' => true,
        'getAppVersion' => '0.1.0-alpha.4',
        _ => null,
      };

  Iterable<MethodCall> called(String method) => calls.where((c) => c.method == method);
}
