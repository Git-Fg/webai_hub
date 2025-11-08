import 'package:ai_hybrid_hub/core/router/app_router.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/automation/providers/overlay_state_provider.dart';
import 'package:ai_hybrid_hub/features/automation/widgets/companion_overlay.dart';
import 'package:ai_hybrid_hub/features/hub/widgets/hub_screen.dart';
import 'package:ai_hybrid_hub/features/settings/models/general_settings.dart';
import 'package:ai_hybrid_hub/features/webview/widgets/ai_webview_screen.dart';
import 'package:ai_hybrid_hub/shared/ui_constants.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
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

  // WHY: Initialize Hive in a platform-agnostic way.
  await Hive.initFlutter();

  // WHY: Register the generated adapter for our settings model.
  Hive.registerAdapter<GeneralSettingsData>(GeneralSettingsDataAdapter());

  // WHY: Open the box that will store our settings. This makes it available
  // synchronously later in the app.
  await Hive.openBox<GeneralSettingsData>('general_settings_box');

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
          // WHY: This declarative structure is robust.
          // The overlay's base position is aligned to the top-center,
          // and the provider's offset is applied as a pure delta from that point.
          Positioned.fill(
            child: Align(
              alignment: Alignment.topCenter,
              child: Transform.translate(
                offset: overlayState.position,
                child: Padding(
                  padding: const EdgeInsets.only(top: kDefaultPadding),
                  child: DraggableCompanionOverlay(overlayKey: _overlayKey),
                ),
              ),
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

    return AnimatedOpacity(
      opacity: shouldShow ? 1.0 : 0.0,
      duration: kShortAnimationDuration,
      child: IgnorePointer(
        ignoring: !shouldShow,
        child: GestureDetector(
          onPanUpdate: (details) {
            // The provider now simply accumulates the raw drag delta.
            ref
                .read(overlayManagerProvider.notifier)
                .updatePosition(details.delta);
          },
          child: CompanionOverlay(overlayKey: overlayKey),
        ),
      ),
    );
  }
}
