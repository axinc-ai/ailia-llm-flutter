import 'package:flutter_test/flutter_test.dart';
import 'package:ailia_llm/ailia_llm.dart';
/*
import 'package:ailia_llm/ailia_llm_platform_interface.dart';
import 'package:ailia_llm/ailia_llm_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAiliaLlmPlatform
    with MockPlatformInterfaceMixin
    implements AiliaLlmPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final AiliaLlmPlatform initialPlatform = AiliaLlmPlatform.instance;

  test('$MethodChannelAiliaLlm is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAiliaLlm>());
  });

  test('getPlatformVersion', () async {
    AiliaLlm ailiaLlmPlugin = AiliaLlm();
    MockAiliaLlmPlatform fakePlatform = MockAiliaLlmPlatform();
    AiliaLlmPlatform.instance = fakePlatform;

    expect(await ailiaLlmPlugin.getPlatformVersion(), '42');
  });
}
*/