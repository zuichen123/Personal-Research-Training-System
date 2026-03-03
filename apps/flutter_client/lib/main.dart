import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/logging/app_logger.dart';
import 'providers/app_provider.dart';
import 'screens/ai_screen.dart';
import 'screens/mistakes_screen.dart';
import 'screens/plans_screen.dart';
import 'screens/pomodoro_screen.dart';
import 'screens/practice_screen.dart';
import 'screens/questions_screen.dart';
import 'screens/resources_screen.dart';
import 'screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.instance.init();

  FlutterError.onError = (details) {
    AppLogger.instance.error(
      module: 'app',
      event: 'flutter.error',
      message: 'Flutter异常',
      error: details.exceptionAsString(),
      stack: details.stack.toString(),
    );
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.instance.error(
      module: 'app',
      event: 'platform.error',
      message: '平台异常',
      error: error.toString(),
      stack: stack.toString(),
    );
    return true;
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppProvider())],
      child: MaterialApp(
        title: '自学工具',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'MiSans',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0D47A1),
            brightness: Brightness.light,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          fontFamily: 'MiSans',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0D47A1),
            brightness: Brightness.dark,
          ),
        ),
        themeMode: ThemeMode.system,
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    QuestionsScreen(),
    MistakesScreen(),
    PracticeScreen(),
    ResourcesScreen(),
    PlansScreen(),
    PomodoroScreen(),
    AIScreen(),
    SettingsScreen(),
  ];

  static const _destinations = [
    _NavItem(
      icon: Icons.question_answer_outlined,
      selectedIcon: Icons.question_answer,
      label: '题库',
    ),
    _NavItem(
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
      label: '错题',
    ),
    _NavItem(
      icon: Icons.edit_note_outlined,
      selectedIcon: Icons.edit_note,
      label: '练习',
    ),
    _NavItem(
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder,
      label: '资料',
    ),
    _NavItem(
      icon: Icons.event_note_outlined,
      selectedIcon: Icons.event_note,
      label: '计划',
    ),
    _NavItem(
      icon: Icons.timer_outlined,
      selectedIcon: Icons.timer,
      label: '专注',
    ),
    _NavItem(
      icon: Icons.psychology_outlined,
      selectedIcon: Icons.psychology,
      label: 'AI',
    ),
    _NavItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: '设置',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().ensureDataForTab(_currentIndex);
    });
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
    context.read<AppProvider>().ensureDataForTab(index);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 800;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1100,
              selectedIndex: _currentIndex,
              onDestinationSelected: _onDestinationSelected,
              labelType: MediaQuery.sizeOf(context).width >= 1100
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              destinations: _destinations
                  .map(
                    (d) => NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: IndexedStack(index: _currentIndex, children: _screens),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: _destinations
            .map(
              (d) => NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
