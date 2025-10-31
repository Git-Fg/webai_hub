import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shared/models/ai_provider.dart';
import 'features/hub/widgets/hub_screen.dart';
import 'features/webview/widgets/ai_webview_tab.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable WebView debugging for development
  if (!kIsWeb && kDebugMode && defaultTargetPlatform == TargetPlatform.android) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
  }

  runApp(const ProviderScope(child: AIHybridHubApp()));
}

class AIHybridHubApp extends StatelessWidget {
  const AIHybridHubApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Hybrid Hub',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const MainTabController(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainTabController extends StatefulWidget {
  const MainTabController({Key? key}) : super(key: key);

  @override
  State<MainTabController> createState() => _MainTabControllerState();
}

class _MainTabControllerState extends State<MainTabController>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5, // Fixed 5 tabs: Hub + 4 AI providers
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // Prevent swipe navigation
        children: [
          // Tab 1: Native Hub
          const HubScreen(),

          // Tab 2-5: AI Provider WebViews
          AIWebViewTab(provider: AIProvider.aistudio),
          AIWebViewTab(provider: AIProvider.qwen),
          AIWebViewTab(provider: AIProvider.zai),
          AIWebViewTab(provider: AIProvider.kimi),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade800,
            width: 0.5,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.deepPurpleAccent,
        indicatorWeight: 2,
        labelColor: Colors.deepPurpleAccent,
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        tabs: const [
          Tab(
            icon: Icon(Icons.hub),
            text: 'Hub',
            height: 60,
          ),
          Tab(
            icon: Icon(Icons.auto_awesome),
            text: 'AI Studio',
            height: 60,
          ),
          Tab(
            icon: Icon(Icons.cloud),
            text: 'Qwen',
            height: 60,
          ),
          Tab(
            icon: Icon(Icons.flash_on),
            text: 'Z-ai',
            height: 60,
          ),
          Tab(
            icon: Icon(Icons.document_scanner),
            text: 'Kimi',
            height: 60,
          ),
        ],
      ),
    );
  }
}