import 'package:ai_hybrid_hub/core/router/app_router.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/automation/providers/overlay_state_provider.dart';
import 'package:ai_hybrid_hub/features/automation/widgets/companion_overlay.dart';
import 'package:ai_hybrid_hub/features/hub/widgets/hub_screen.dart';
import 'package:ai_hybrid_hub/features/webview/widgets/ai_webview_screen.dart';
import 'package:ai_hybrid_hub/shared/ui_constants.dart';
import 'package:auto_route/auto_route.dart';
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

  static final _appRouter = AppRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AI Hybrid Hub MVP',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: _appRouter.config(),
      debugShowCheckedModeBanner: false,
    );
  }
}

@RoutePage()
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final GlobalKey _overlayKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final initialIndex = ref.read(currentTabIndexProvider);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialIndex,
    );
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
    ref.listen(currentTabIndexProvider, (previous, next) {
      if (_tabController.index != next) {
        _tabController.animateTo(next);
      }
    });

    final currentIndex = ref.watch(currentTabIndexProvider);
    final overlayState = ref.watch(overlayManagerProvider);

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            sizing: StackFit.expand,
            children: const [
              HubScreen(),
              AiWebviewScreen(),
            ],
          ),
          // WHY: This new structure is robust.
          // Align handles the centering, and Transform applies the drag delta.
          // This removes the need for manual calculations and size measurements.
          Align(
            // We align to topCenter and will use the provider offset for fine-tuning.
            alignment: const Alignment(0, -0.8), // Pushes it towards the top.
            child: Transform.translate(
              offset: overlayState.position,
              child: DraggableCompanionOverlay(overlayKey: _overlayKey),
            ),
          ),
        ],
      ),
      bottomNavigationBar: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(icon: Icon(Icons.chat), text: 'Hub'),
          Tab(icon: Icon(Icons.web), text: 'AI Studio'),
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

    return AnimatedOpacity(
      opacity: shouldShow ? 1.0 : 0.0,
      duration: kShortAnimationDuration,
      child: IgnorePointer(
        ignoring: !shouldShow,
        child: GestureDetector(
          onPanUpdate: (details) {
            final overlayBox =
                overlayKey.currentContext?.findRenderObject() as RenderBox?;
            final overlaySize = overlayBox?.size ?? const Size(300, 150);

            // WHY: The logic is now simple: just tell the provider to update its
            // offset by the amount dragged. The provider handles clamping.
            ref
                .read(overlayManagerProvider.notifier)
                .updateClampedPosition(details.delta, screenSize, overlaySize);
          },
          child: CompanionOverlay(overlayKey: overlayKey),
        ),
      ),
    );
  }
}
