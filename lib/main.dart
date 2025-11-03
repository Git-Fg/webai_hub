import 'package:ai_hybrid_hub/features/hub/widgets/hub_screen.dart';
import 'package:ai_hybrid_hub/features/webview/widgets/ai_webview_screen.dart';
import 'package:ai_hybrid_hub/features/automation/widgets/companion_overlay.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'main.g.dart';

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

  @override
  void initState() {
    super.initState();
    final initialIndex = ref.read(currentTabIndexProvider);
    _tabController =
        TabController(length: 2, vsync: this, initialIndex: initialIndex);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!mounted) return;
    final newIndex = _tabController.index;
      final currentProviderIndex = ref.read(currentTabIndexProvider);
      if (currentProviderIndex != newIndex) {
        ref.read(currentTabIndexProvider.notifier).changeTo(newIndex);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Écoute les changements du provider pour synchroniser le TabController
    ref.listen(currentTabIndexProvider, (previous, next) {
      if (_tabController.index != next) {
        _tabController.animateTo(next);
      }
    });

    final currentIndex = ref.watch(currentTabIndexProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Use IndexedStack - WebView will be built when tab switches to index 1
          IndexedStack(
          index: currentIndex,
          sizing: StackFit.expand,
          children: const [
            HubScreen(),
            // Remove const to allow widget to rebuild when tab changes
            AiWebviewScreen(),
          ],
          ),
          Consumer(
            builder: (context, ref, _) {
              final status = ref.watch(automationStateProvider);
              final currentTabIndex = ref.watch(currentTabIndexProvider);
              final shouldShow =
                  status != AutomationStatus.idle && currentTabIndex == 1;

              // Positioned must be a direct child of Stack
              return Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: AnimatedOpacity(
                  opacity: shouldShow ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: !shouldShow,
                    child: const CompanionOverlay(),
                  ),
                ),
              );
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
    );
  }
}
