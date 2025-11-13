import 'dart:async';

import 'package:ai_hybrid_hub/core/database/database_provider.dart';
import 'package:ai_hybrid_hub/core/database/seed_presets.dart';
import 'package:ai_hybrid_hub/core/providers/talker_provider.dart';
import 'package:ai_hybrid_hub/core/router/app_router.dart';
import 'package:ai_hybrid_hub/features/automation/providers/companion_overlay_visibility_provider.dart';
import 'package:ai_hybrid_hub/features/automation/widgets/automation_state_observer.dart';
import 'package:ai_hybrid_hub/features/automation/widgets/companion_overlay.dart';
import 'package:ai_hybrid_hub/features/hub/providers/active_conversation_provider.dart';
import 'package:ai_hybrid_hub/features/hub/widgets/hub_screen.dart';
import 'package:ai_hybrid_hub/features/presets/providers/presets_provider.dart';
import 'package:ai_hybrid_hub/features/settings/models/general_settings.dart';
import 'package:ai_hybrid_hub/features/settings/providers/general_settings_provider.dart';
import 'package:ai_hybrid_hub/features/webview/widgets/ai_webview_screen.dart';
import 'package:auto_route/auto_route.dart';
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

  // WHY: Open the box that will store app state (like selected preset IDs).
  // This makes it available synchronously after app initialization.
  await Hive.openBox<dynamic>('app_state_box');

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

    // 1. Seed presets if they don't exist
    await seedPresets(container);

    // 2. Prune old conversations if count exceeds maxConversationHistory
    await db.pruneOldConversations(settings.maxConversationHistory);

    // 3. Load last session if enabled
    if (settings.persistSessionOnRestart) {
      try {
        final lastConversation = await db.getMostRecentConversation();
        if (lastConversation != null) {
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
      title: 'AI Hybrid Hub',
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
    with TickerProviderStateMixin {
  TabController? _tabController;
  final GlobalKey _overlayKey = GlobalKey();

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presetsAsync = ref.watch(presetsProvider);

    ref.listen(currentTabIndexProvider, (_, next) {
      if (_tabController?.index != next) {
        _tabController?.animateTo(next);
      }
    });

    return AutomationStateObserver(
      child: Scaffold(
        body: Stack(
          children: [
            presetsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(child: Text('Error: $err')),
              data: (presets) {
                return IndexedStack(
                  index: ref.watch(currentTabIndexProvider),
                  children: [
                    const HubScreen(),
                    // WHY: Filter out groups (presets with null providerId) as they don't need WebView screens
                    ...presets.where((preset) => preset.providerId != null).map(
                      (preset) {
                        return AiWebviewScreen(
                          key: ValueKey(preset.id), // CRITICAL
                          preset: preset,
                        );
                      },
                    ),
                  ],
                );
              },
            ),
            Consumer(
              builder: (context, ref, _) {
                final isVisible = ref.watch(companionOverlayVisibilityProvider);
                return Visibility(
                  visible: isVisible,
                  child: CompanionOverlay(overlayKey: _overlayKey),
                );
              },
            ),
          ],
        ),
        bottomNavigationBar: presetsAsync.when(
          data: (presets) {
            // WHY: Filter out groups from tabs as they don't have WebView screens
            final presetsWithProviders = presets
                .where((p) => p.providerId != null)
                .toList();
            final totalTabs = 1 + presetsWithProviders.length;

            // NEW: CONSOLIDATED LOGIC
            // If controller doesn't exist or its length is wrong, create/update it.
            if (_tabController == null || _tabController!.length != totalTabs) {
              _tabController?.dispose(); // Dispose old one if it exists
              _tabController = TabController(
                length: totalTabs,
                vsync: this,
                // Sync initial index with the provider state
                initialIndex: ref
                    .read(currentTabIndexProvider)
                    .clamp(0, totalTabs - 1),
              );
            }
            // END NEW LOGIC

            // Controller is guaranteed to be non-null after the consolidated logic
            final controller = _tabController;
            if (controller == null) {
              return const SizedBox.shrink();
            }

            final tabs = [
              const Tab(icon: Icon(Icons.chat), text: 'Hub'),
              ...presetsWithProviders.map((p) => Tab(text: p.name)),
            ];
            return TabBar(
              controller: controller,
              isScrollable: tabs.length > 4,
              tabs: tabs,
              onTap: (index) {
                ref.read(currentTabIndexProvider.notifier).changeTo(index);
              },
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
