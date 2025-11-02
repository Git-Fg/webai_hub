import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_ready_provider.g.dart';

@riverpod
class AppReady extends _$AppReady {
  @override
  bool build() => false;

  void setReady() {
    state = true;
  }
}
