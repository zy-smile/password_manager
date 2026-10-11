import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../features/vault/presentation/providers/auth_provider.dart';
import '../features/vault/presentation/providers/settings_provider.dart';
import '../features/vault/presentation/screens/lock_screen.dart';
import 'home_shell.dart';

/// Lives below the providers and owns the authenticated navigation tree.
class SessionApp extends StatefulWidget {
  const SessionApp(
      {super.key, this.unlockedHome = const HomeShell(), this.now});
  final Widget unlockedHome;
  final DateTime Function()? now;

  @override
  State<SessionApp> createState() => _SessionAppState();
}

class _SessionAppState extends State<SessionApp> with WidgetsBindingObserver {
  AuthProvider? _auth;
  SettingsProvider? _settings;
  Timer? _idleTimer;
  DateTime? _backgroundedAt;
  bool _inBackground = false;
  DateTime get _now => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    final settings = context.read<SettingsProvider>();
    if (_auth != auth || _settings != settings) {
      _auth?.removeListener(_resetIdleTimer);
      _settings?.removeListener(_resetIdleTimer);
      _auth = auth;
      _settings = settings;
      auth.addListener(_resetIdleTimer);
      settings.addListener(_resetIdleTimer);
      _resetIdleTimer();
    }
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_auth?.isUnlocked != true || _inBackground) return;
    final minutes = _settings!.autoLockMinutes;
    // Immediate means on leaving the app, not every foreground interaction.
    if (minutes > 0) {
      _idleTimer = Timer(Duration(minutes: minutes), _auth!.lock);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _inBackground = true;
      _idleTimer?.cancel();
      if (_auth?.isUnlocked != true) return;
      _backgroundedAt ??= _now;
      if (_settings!.autoLockMinutes == 0) _auth!.lock();
    } else if (state == AppLifecycleState.resumed) {
      _inBackground = false;
      final since = _backgroundedAt;
      if (_auth?.isUnlocked == true &&
          since != null &&
          _now.difference(since) >=
              Duration(minutes: _settings!.autoLockMinutes)) {
        _auth!.lock();
      }
      _backgroundedAt = null;
      _resetIdleTimer();
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _auth?.removeListener(_resetIdleTimer);
    _settings?.removeListener(_resetIdleTimer);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Listener(
      onPointerDown: (_) => _resetIdleTimer(),
      onPointerMove: (_) => _resetIdleTimer(),
      onPointerSignal: (_) => _resetIdleTimer(),
      child: Focus(
        onKeyEvent: (_, __) {
          _resetIdleTimer();
          return KeyEventResult.ignored;
        },
        child: MaterialApp(
          // Destroy pushed routes and sensitive text controllers on lock.
          key: ValueKey(auth.isUnlocked),
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          home: !auth.isInitialized
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : auth.isUnlocked
                  ? widget.unlockedHome
                  : const LockScreen(),
        ),
      ),
    );
  }
}
