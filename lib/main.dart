import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/session_app.dart';
import 'core/database/app_database.dart';
import 'features/vault/presentation/providers/auth_provider.dart';
import 'features/vault/presentation/providers/settings_provider.dart';
import 'features/vault/presentation/providers/vault_provider.dart';
import 'features/wardrobe/presentation/wardrobe_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await AppDatabase().database;
  }
  runApp(const PersonalAssistantApp());
}

class PersonalAssistantApp extends StatelessWidget {
  const PersonalAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(
            create: (_) => SettingsProvider()..loadSettings()),
        ChangeNotifierProxyProvider<AuthProvider, VaultProvider>(
          create: (_) => VaultProvider(),
          update: (_, auth, vault) => vault!..updateAuth(auth),
        ),
        ChangeNotifierProvider(create: (_) => WardrobeProvider()..loadItems()),
      ],
      child: const SessionApp(),
    );
  }
}
