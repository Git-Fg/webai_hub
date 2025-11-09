import 'dart:async';

import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:ai_hybrid_hub/core/providers/talker_provider.dart';
import 'package:ai_hybrid_hub/core/router/app_router.dart';
import 'package:ai_hybrid_hub/features/automation/automation_state_provider.dart';
import 'package:ai_hybrid_hub/features/automation/providers/overlay_state_provider.dart';
import 'package:ai_hybrid_hub/features/automation/widgets/automation_state_observer.dart';
import 'package:ai_hybrid_hub/features/automation/widgets/companion_overlay.dart';
import 'package:ai_hybrid_hub/features/hub/providers/active_conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/widgets/hub_screen.dart';
import 'package:ai_hybrid_hub/features/settings/models/general_settings.dart';
import 'package:ai_hybrid_hub/features/settings/providers/general_settings_provider.dart';
import 'package:ai_hybrid_hub/features/webview/bridge/javascript_bridge.dart';
import 'package:ai_hybrid_hub/features/webview/widgets/ai_webview_screen.dart';
import 'package:ai_hybrid_hub/shared/ui_constants.dart';
import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger.dart';

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

  // WHY: Create ProviderContainer before runApp to perform startup logic.
  // This allows us to access providers synchronously during initialization.
  // WHY: Create a single Talker instance for both the observer and provider override.
  // This ensures a single source of truth for the logger instance from the very beginning.
  final talker = TalkerFlutter.init(
    settings: TalkerSettings(),
  );
  final container = ProviderContainer(
    overrides: [
      // WHY: Override the provider with the instance we just created to ensure
      // consistency between the observer and any code that reads the provider.
      talkerProvider.overrideWithValue(talker),
    ],
    observers: [
      // WHY: This observer automatically logs all Riverpod provider state changes
      // and errors, providing comprehensive visibility into the app's state management.
      TalkerRiverpodObserver(talker: talker),
    ],
  );

  // Perform startup tasks (prune conversations, restore session if enabled)
  await _runStartupLogic(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}

// WHY: This function handles all startup tasks that need to run before the app UI is displayed.
// It prunes old conversations and optionally restores the last active conversation.
Future<void> _runStartupLogic(ProviderContainer container) async {
  try {
    final settings = await container.read(generalSettingsProvider.future);
    final db = container.read(appDatabaseProvider);
    final talker = container.read(talkerProvider);

    // 1. Prune old conversations if count exceeds maxConversationHistory
    await db.pruneOldConversations(settings.maxConversationHistory);

    // 2. Load last session if enabled
    if (settings.persistSessionOnRestart) {
      try {
        final allConversations = await (db.select(
          db.conversations,
        )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();
        if (allConversations.isNotEmpty) {
          final lastConversation = allConversations.first;
          container
              .read(activeConversationIdProvider.notifier)
              .set(lastConversation.id);
        }
      } on Exception catch (e, st) {
        // WHY: If session restore fails, log but don't crash - app can start without restored session
        talker.handle(e, st, 'Session restore error (non-fatal)');
      }
    }
  } on Exception catch (e, st) {
    // WHY: If startup logic fails, we log the error but don't crash the app.
    // The app can still function without restoring the session or pruning conversations.
    final talker = container.read(talkerProvider);
    talker.handle(e, st, 'Startup logic error');
  }
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

      // WHY: Pre-warm the JavaScript bridge as soon as the user switches to the WebView tab.
      // This eliminates the bridge-ready wait time when the user sends a prompt,
      // making the UI feel significantly more responsive.
      if (next == 1) {
        // 1 is the index of the WebView tab
        unawaited(
          Future(() async {
            try {
              await ref.read(javaScriptBridgeProvider).waitForBridgeReady();
              ref.read(talkerProvider).info('[Pre-warm] Bridge is ready.');
            } on Object catch (e) {
              // WHY: Silently ignore errors, as this is a non-critical optimization.
              ref
                  .read(talkerProvider)
                  .debug('[Pre-warm] Bridge pre-warm failed silently: $e');
            }
          }),
        );
      }
    });

    final currentIndex = ref.watch(currentTabIndexProvider);

    return AutomationStateObserver(
      child: Scaffold(
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
            DraggableCompanionOverlay(overlayKey: _overlayKey),
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
    final overlayState = ref.watch(overlayManagerProvider);

    final shouldShow =
        status.maybeWhen(
          refining: (messageCount, isExtracting) => true,
          needsLogin: (onResume) => true,
          orElse: () => false,
        ) &&
        currentTabIndex == 1;
    final isDraggable = status.maybeWhen(
      refining: (messageCount, isExtracting) => true,
      orElse: () => false,
    );
    final isCentered = status.maybeWhen(
      needsLogin: (onResume) => true,
      orElse: () => false,
    );

    return Align(
      alignment: isCentered ? Alignment.center : Alignment.topCenter,
      child: AnimatedOpacity(
        opacity: shouldShow ? 1.0 : 0.0,
        duration: kShortAnimationDuration,
        child: IgnorePointer(
          ignoring: !shouldShow,
          child: Transform.translate(
            offset: isDraggable ? overlayState.position : Offset.zero,
            child: Padding(
              padding: const EdgeInsets.all(kDefaultPadding),
              child: isDraggable
                  ? GestureDetector(
                      onPanUpdate: (details) {
                        ref
                            .read(overlayManagerProvider.notifier)
                            .updatePosition(details.delta);
                      },
                      child: CompanionOverlay(overlayKey: overlayKey),
                    )
                  : CompanionOverlay(overlayKey: overlayKey),
            ),
          ),
        ),
      ),
    );
  }
}
