import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/automation/providers/overlay_state_provider.dart';
import 'package:ai_hybrid_hub/features/automation/widgets/companion_overlay.dart';
import 'package:ai_hybrid_hub/features/hub/widgets/hub_screen.dart';
import 'package:ai_hybrid_hub/features/webview/widgets/ai_webview_screen.dart';
import 'package:ai_hybrid_hub/shared/ui_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'main.g.dart';

@Riverpod(keepAlive: true)
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
  // A key to measure the overlay widget size for clamping drag within screen bounds
  final GlobalKey _overlayKey = GlobalKey();

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
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // WHY: Listen to provider changes to synchronize TabController
    ref.listen(currentTabIndexProvider, (previous, next) {
      if (_tabController.index != next) {
        _tabController.animateTo(next);
      }
    });

    final currentIndex = ref.watch(currentTabIndexProvider);
    // Screen size is handled inside the overlay widget

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
          // WHY: Moved Positioned here to be a direct child of Stack, fixing the layout error.
          // The positioning logic is now handled at the Stack level.
          Builder(
            builder: (context) {
              final overlayState = ref.watch(overlayManagerProvider);
              final screenSize = MediaQuery.of(context).size;
              final overlayBox =
                  _overlayKey.currentContext?.findRenderObject() as RenderBox?;
              final overlaySize = overlayBox?.size ?? const Size(300, 150);

              final position = overlayState.position;
              final top = (screenSize.height / 2) +
                  position.dy -
                  (overlaySize.height / 2);
              final left = (screenSize.width / 2) +
                  position.dx -
                  (overlaySize.width / 2);

              return Positioned(
                top: top,
                left: left,
                child: DraggableCompanionOverlay(overlayKey: _overlayKey),
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

class DraggableCompanionOverlay extends ConsumerWidget {
  const DraggableCompanionOverlay({
    required this.overlayKey,
    super.key,
  });

  final GlobalKey overlayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(automationStateProvider);
    final currentTabIndex = ref.watch(currentTabIndexProvider);
    final shouldShow =
        status != const AutomationStateData.idle() && currentTabIndex == 1;

    final screenSize = MediaQuery.of(context).size;
    final overlayBox =
        overlayKey.currentContext?.findRenderObject() as RenderBox?;
    final overlaySize =
        overlayBox?.size ?? const Size(300, 150); // Fallback size

    return AnimatedOpacity(
      opacity: shouldShow ? 1.0 : 0.0,
      duration: kShortAnimationDuration,
      child: IgnorePointer(
        ignoring: !shouldShow,
        // WHY: The Positioned widget was removed from here. The GestureDetector is now the root.
        child: GestureDetector(
          onPanUpdate: (details) {
            ref.read(overlayManagerProvider.notifier).updateClampedPosition(
                  details.delta,
                  screenSize,
                  overlaySize,
                );
          },
          child: Padding(
            padding: const EdgeInsets.all(kDefaultPadding),
            child: CompanionOverlay(overlayKey: overlayKey),
          ),
        ),
      ),
    );
  }
}
