import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/logging/app_logger.dart';
import 'providers/ai_agent_provider.dart';
import 'providers/app_provider.dart';
import 'screens/agent_chat_hub_screen.dart';
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

CardThemeData _cardTheme(ColorScheme cs) => CardThemeData(
  elevation: 1,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  clipBehavior: Clip.antiAlias,
);

AppBarTheme _appBarTheme(ColorScheme cs) => AppBarTheme(
  centerTitle: true,
  scrolledUnderElevation: 2,
  backgroundColor: cs.surface,
  surfaceTintColor: cs.primary,
);

NavigationBarThemeData _navBarTheme(ColorScheme cs) => NavigationBarThemeData(
  indicatorColor: cs.primaryContainer.withValues(alpha: 0.8),
  indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
  height: 72,
);

FloatingActionButtonThemeData _fabTheme(ColorScheme cs) =>
    FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
    );

InputDecorationTheme _inputTheme(ColorScheme cs) => InputDecorationTheme(
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
);

DialogThemeData _dialogTheme(ColorScheme cs) => DialogThemeData(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => AIAgentProvider()),
      ],
      child: MaterialApp(
        title: '自学工具',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: const MainScreen(),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final cs = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4338CA),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'MiSans',
      colorScheme: cs,
      cardTheme: _cardTheme(cs),
      appBarTheme: _appBarTheme(cs),
      navigationBarTheme: _navBarTheme(cs),
      floatingActionButtonTheme: _fabTheme(cs),
      inputDecorationTheme: _inputTheme(cs),
      dialogTheme: _dialogTheme(cs),
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
    AgentChatHubScreen(),
    QuestionsScreen(),
    MistakesScreen(),
    PracticeScreen(),
    PomodoroScreen(),
  ];

  static const _destinations = [
    _NavItem(
      icon: Icons.psychology_outlined,
      selectedIcon: Icons.psychology,
      label: 'AI',
    ),
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
      icon: Icons.timer_outlined,
      selectedIcon: Icons.timer,
      label: '专注',
    ),
  ];

  static const _drawerItems = [
    _NavItem(
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder,
      label: '学习资料',
    ),
    _NavItem(
      icon: Icons.event_note_outlined,
      selectedIcon: Icons.event_note,
      label: '计划管理',
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

  void _openDrawerScreen(BuildContext context, int drawerIndex) {
    Navigator.of(context).pop();

    final provider = context.read<AppProvider>();
    Widget screen;
    switch (drawerIndex) {
      case 0:
        provider.ensureResourcesLoaded();
        screen = const ResourcesScreen();
        break;
      case 1:
        provider.ensurePlansLoaded();
        screen = const PlansScreen();
        break;
      case 2:
        provider.ensureAILoaded();
        provider.ensureProfileLoaded();
        screen = const SettingsScreen();
        break;
      default:
        return;
    }

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _buildDrawer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primaryContainer,
                  cs.primary.withValues(alpha: 0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(Icons.school, size: 32, color: cs.primary),
                const SizedBox(width: 12),
                Text(
                  '自学工具',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          ..._drawerItems.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return ListTile(
              leading: Icon(item.icon),
              title: Text(item.label),
              onTap: () => _openDrawerScreen(context, i),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 800;

    if (isWide) {
      return Scaffold(
        drawer: _buildDrawer(context),
        body: Stack(
          children: [
            Row(
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
            Positioned(
              left: 10,
              bottom: 10,
              child: SafeArea(
                child: Builder(
                  builder: (ctx) => IconButton.filledTonal(
                    icon: const Icon(Icons.menu),
                    tooltip: '更多功能',
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      drawer: _buildDrawer(context),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: '更多功能',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(_destinations[_currentIndex].label),
      ),
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
