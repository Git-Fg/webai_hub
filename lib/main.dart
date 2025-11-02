import 'package:ai_hybrid_hub/features/hub/widgets/hub_screen.dart';
import 'package:ai_hybrid_hub/features/webview/widgets/ai_webview_screen.dart';
import 'package:ai_hybrid_hub/features/automation/widgets/companion_overlay.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'main.g.dart';

final tabControllerProvider = Provider<TabController?>((ref) => null);

@riverpod
class CurrentTabIndex extends _$CurrentTabIndex {
  @override
  int build() => 0;

  void changeTo(int index) {
    if (state != index) {
      state = index;
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Hybrid Hub MVP',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      final newIndex = _tabController.index;
      ref.read(currentTabIndexProvider.notifier).changeTo(newIndex);

      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentIndex = newIndex;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        tabControllerProvider.overrideWithValue(_tabController),
      ],
      child: Scaffold(
        body: Stack(
          children: [
            Consumer(
              builder: (context, ref, _) {
                final tabIndex = ref.watch(currentTabIndexProvider);
                return IndexedStack(
                  index: tabIndex,
                  children: const [
                    HubScreen(),
                    AiWebviewScreen(),
                  ],
                );
              },
            ),
            Consumer(
              builder: (context, ref, _) {
                final status = ref.watch(automationStateProvider);

                if (status != AutomationStatus.idle && _currentIndex == 1) {
                  return const CompanionOverlay();
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        bottomNavigationBar: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.chat),
              text: 'Hub',
            ),
            Tab(
              icon: Icon(Icons.web),
              text: 'AI Studio',
            ),
          ],
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
        ),
      ),
    );
  }
}
