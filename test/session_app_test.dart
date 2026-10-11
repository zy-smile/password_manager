import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:password_manager/app/session_app.dart';
import 'package:password_manager/features/vault/presentation/providers/auth_provider.dart';
import 'package:password_manager/features/vault/presentation/providers/settings_provider.dart';
import 'support/fakes.dart';

void main() {
  late SessionTestAuth auth;
  late SettingsProvider settings;
  late MemorySecureStorage storage;
  setUp(() {
    auth = SessionTestAuth();
    storage = MemorySecureStorage();
    settings = SettingsProvider(secureStorage: storage);
  });

  Widget app({DateTime Function()? now}) => MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ],
          child: SessionApp(
              now: now,
              unlockedHome: Scaffold(
                  body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => const Scaffold(
                                body: Text('sensitive editor')))),
                    child: const Text('open editor')),
              ))));

  testWidgets('immediate background lock destroys a pushed sensitive route',
      (tester) async {
    await settings.setAutoLockMinutes(0);
    await tester.pumpWidget(app());
    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();
    expect(find.text('sensitive editor'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(auth.isUnlocked, isFalse);
    // Flutter suspends frames while paused; verify the first resumed frame.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('sensitive editor'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    settings.dispose();
  });

  testWidgets('foreground idle locks, and user interaction restarts the timer',
      (tester) async {
    await settings.setAutoLockMinutes(1);
    await tester.pumpWidget(app());
    await tester.pump(const Duration(seconds: 50));
    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 50));
    expect(auth.isUnlocked, isTrue);
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(auth.isUnlocked, isFalse);
    expect(find.text('sensitive editor'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    settings.dispose();
  });

  testWidgets('resume after timeout locks even if hidden follows paused',
      (tester) async {
    var time = DateTime(2026, 10, 11, 12);
    await tester.pumpWidget(app(now: () => time));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    time = time.add(const Duration(minutes: 4));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    time = time.add(const Duration(minutes: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(auth.isUnlocked, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    settings.dispose();
  });
}
