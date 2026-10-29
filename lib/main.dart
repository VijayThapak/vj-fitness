import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/diet.dart';
import 'screens/profile.dart';
import 'screens/today.dart';
import 'screens/workouts.dart';
import 'store.dart';
import 'widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VjFitApp());
  store.load();
}

const brandBlue = Color(0xFF1F5FBF);

class VjFitApp extends StatelessWidget {
  const VjFitApp({super.key});

  ThemeData _theme(Brightness b) {
    final cs = ColorScheme.fromSeed(seedColor: brandBlue, brightness: b);
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      appBarTheme: const AppBarTheme(centerTitle: false),
      cardTheme: const CardThemeData(margin: EdgeInsets.zero, clipBehavior: Clip.antiAlias),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VJ Fit',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: ListenableBuilder(
        listenable: store,
        builder: (context, _) => store.ready ? const HomeShell() : const _Splash(),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: brandBlue,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('VJ Fit', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
            SizedBox(height: 16),
            CircularProgressIndicator(color: Colors.white),
          ]),
        ),
      );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      store.saveNow();
    }
  }

  void goTo(int i) => setState(() => tab = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayScreen(onOpenDiet: () => goTo(2)),
      const WorkoutsScreen(),
      const DietScreen(),
      const ProfileScreen(),
    ];
    return PopScope(
      canPop: tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goTo(0);
      },
      child: Scaffold(
        body: IndexedStack(index: tab, children: pages),
        bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
          const RestTimerBar(),
          NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) {
              HapticFeedback.selectionClick();
              goTo(i);
            },
            destinations: const [
              NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Today'),
              NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: 'Workouts'),
              NavigationDestination(icon: Icon(Icons.restaurant_outlined), selectedIcon: Icon(Icons.restaurant), label: 'Diet'),
              NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Me'),
            ],
          ),
        ]),
      ),
    );
  }
}
