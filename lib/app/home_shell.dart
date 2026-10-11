import 'package:flutter/material.dart';

import 'package:password_manager/features/vault/presentation/screens/home_screen.dart';
import 'package:password_manager/features/vault/presentation/screens/settings_screen.dart';
import 'package:password_manager/features/wardrobe/presentation/screens/wardrobe_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static void switchTab(BuildContext context, int index) {
    context.findAncestorStateOfType<_HomeShellState>()?.setTab(index);
  }

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  void setTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),
          WardrobeScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setTab(index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.lock_outline_rounded),
            selectedIcon: Icon(Icons.lock_rounded),
            label: '密码箱',
          ),
          NavigationDestination(
            icon: Icon(Icons.checkroom_outlined),
            selectedIcon: Icon(Icons.checkroom_rounded),
            label: '衣服',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
