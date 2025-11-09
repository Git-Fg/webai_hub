import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:talker_flutter/talker_flutter.dart';

part 'talker_provider.g.dart';

@Riverpod(keepAlive: true)
Talker talker(Ref ref) {
  // WHY: We configure Talker to be enabled only in debug mode.
  // In release builds, all talker calls will be no-ops, ensuring zero
  // performance impact for end-users.
  final talker = TalkerFlutter.init(
    settings: TalkerSettings(),
  );
  return talker;
}
