import 'package:ai_hybrid_hub/features/presets/widgets/presets_management_screen.dart';
import 'package:ai_hybrid_hub/features/settings/widgets/settings_screen.dart';
import 'package:ai_hybrid_hub/main.dart';
import 'package:auto_route/auto_route.dart';

part 'app_router.gr.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: MainRoute.page, initial: true),
    AutoRoute(page: SettingsRoute.page),
    AutoRoute(page: PresetsManagementRoute.page),
  ];
}
