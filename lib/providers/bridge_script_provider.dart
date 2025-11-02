import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bridge_script_provider.g.dart';

@riverpod
Future<String> bridgeScript(Ref ref) async {
  return await rootBundle.loadString('assets/js/bridge.js');
}
