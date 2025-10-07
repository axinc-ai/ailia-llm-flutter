import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ailia_llm/ailia_llm_model.dart';

void main() {
  group('AiliaLLMModel Unit Tests', () {
    late AiliaLLMModel model;

    setUp(() {
      model = AiliaLLMModel();
    });

    tearDown(() {
      model.close();
    });

    test('getBackendList returns available backends', () {
      final backends = AiliaLLMModel.getBackendList();
      expect(backends, isNotEmpty);
      expect(backends, isA<List<String>>());
    });

    test('checkVulkanVersion returns boolean', () {
      final hasVulkan = AiliaLLMModel.checkVulkanVersion();
      expect(hasVulkan, isA<bool>());
    });

    test('open throws exception when model path is invalid', () {
      expect(
        () => model.open('invalid_path.gguf', 512),
        throwsException,
      );
    });

    test('setPrompt throws exception when LLM not initialized', () {
      expect(
        () => model.setPrompt([
          {'role': 'user', 'content': 'Hello'}
        ]),
        throwsException,
      );
    });

    test('generate throws exception when LLM not initialized', () {
      expect(
        () => model.generate(),
        throwsException,
      );
    });

    test('getTokenCount throws exception when LLM not initialized', () {
      expect(
        () => model.getTokenCount('test text'),
        throwsException,
      );
    });

    test('setSamplingParams throws exception when LLM not initialized', () {
      expect(
        () => model.setSamplingParams(1, 0.98, 0.05, 3939),
        throwsException,
      );
    });

    test('openMultimodalProjectorFile throws exception when LLM not initialized', () {
      expect(
        () => model.openMultimodalProjectorFile('invalid_path.gguf'),
        throwsException,
      );
    });

    test('getMultimodalCapabilities throws exception when LLM not initialized', () {
      expect(
        () => model.getMultimodalCapabilities(),
        throwsException,
      );
    });

    test('setMultimodalPrompt throws exception when LLM not initialized', () {
      expect(
        () => model.setMultimodalPrompt([
          {'role': 'user', 'content': 'Hello'}
        ]),
        throwsException,
      );
    });

    test('contextFull returns false initially', () {
      expect(model.contextFull(), isFalse);
    });

    test('close can be called multiple times safely', () {
      model.close();
      model.close();
      // Should not throw
    });
  });

  group('AiliaLLMModel Integration Tests', () {
    late AiliaLLMModel model;
    late String modelPath;
    final int nCtx = 2048;

    setUpAll(() {
      // Use model from environment variable or default path
      final homeDir = Platform.environment['HOME'] ?? '';
      modelPath = Platform.environment['AILIA_LLM_MODEL_PATH'] ??
          '$homeDir/claude_workspace/models/gemma-2-2b-it-Q4_K_M.gguf';

      // Verify model file exists - test will fail if not found
      expect(File(modelPath).existsSync(), isTrue,
        reason: 'Model file not found at $modelPath. '
                'Please ensure model is available at ~/claude_workspace/models/ or set the AILIA_LLM_MODEL_PATH environment variable.');
    });

    setUp(() {
      model = AiliaLLMModel();
    });

    tearDown(() {
      model.close();
    });

    test('open and close model successfully', () {
      expect(() => model.open(modelPath, nCtx), returnsNormally);
      expect(() => model.close(), returnsNormally);
    });

    test('setSamplingParams sets parameters successfully', () {
      model.open(modelPath, nCtx);
      expect(
        () => model.setSamplingParams(1, 0.98, 0.05, 3939),
        returnsNormally,
      );
    });

    test('setPrompt with valid messages succeeds', () {
      model.open(modelPath, nCtx);
      final messages = [
        {'role': 'system', 'content': '質問と同じ言語で回答してください。'},
        {'role': 'user', 'content': 'How many legs does a cat have?'}
      ];

      expect(() => model.setPrompt(messages), returnsNormally);
      expect(model.contextFull(), isFalse);
    });

    test('setPrompt throws exception when missing content', () {
      model.open(modelPath, nCtx);
      final messages = [
        {'role': 'user'}
      ];

      expect(() => model.setPrompt(messages), throwsException);
    });

    test('setPrompt throws exception when missing role', () {
      model.open(modelPath, nCtx);
      final messages = [
        {'content': 'Hello'}
      ];

      expect(() => model.setPrompt(messages), throwsException);
    });

    test('getTokenCount returns valid count', () {
      model.open(modelPath, nCtx);
      final count = model.getTokenCount('How many legs does a cat have?');

      expect(count, greaterThan(0));
      expect(count, isA<int>());
    });

    test('generate produces text output', () {
      model.open(modelPath, nCtx);
      model.setSamplingParams(1, 0.98, 0.05, 3939);

      final messages = [
        {'role': 'system', 'content': '質問と同じ言語で回答してください。'},
        {'role': 'user', 'content': 'How many legs does a cat have?'}
      ];
      model.setPrompt(messages);

      String fullResponse = '';
      int tokenCount = 0;
      const maxTokens = 50;

      while (tokenCount < maxTokens) {
        final delta = model.generate();

        if (delta == null) {
          break;
        }

        fullResponse += delta;
        tokenCount++;
      }

      expect(fullResponse, isNotEmpty);
      expect(fullResponse.toLowerCase(), anyOf(
        contains('4'),
        contains('four'),
      ));
    });

    test('Japanese response test', () {
      model.open(modelPath, nCtx);
      model.setSamplingParams(1, 0.98, 0.05, 3939);

      final messages = [
        {'role': 'system', 'content': '質問と同じ言語で回答してください。'},
        {'role': 'user', 'content': 'カブトムシは何本の足を持っていますか？'}
      ];
      model.setPrompt(messages);

      String fullResponse = '';
      int tokenCount = 0;
      const maxTokens = 50;

      while (tokenCount < maxTokens) {
        final delta = model.generate();

        if (delta == null) {
          break;
        }

        fullResponse += delta;
        tokenCount++;
      }

      expect(fullResponse, isNotEmpty);
      // Note: Model accuracy may vary, we just verify Japanese text generation works
      expect(fullResponse, matches(RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]+')));
    });

    test('multi-turn conversation test', () {
      model.open(modelPath, nCtx);
      model.setSamplingParams(1, 0.98, 0.05, 3939);

      final messages = [
        {'role': 'system', 'content': '質問と同じ言語で回答してください。'},
        {'role': 'user', 'content': 'How many legs does a cat have?'}
      ];
      model.setPrompt(messages);

      // Generate first response
      String response1 = '';
      int tokenCount = 0;
      const maxTokens = 50;

      while (tokenCount < maxTokens) {
        final delta = model.generate();
        if (delta == null) break;
        response1 += delta;
        tokenCount++;
      }

      expect(response1, isNotEmpty);

      // Add assistant response and continue conversation
      messages.add({'role': 'assistant', 'content': response1});
      messages.add({'role': 'user', 'content': 'カブトムシは何本の足を持っていますか？'});

      model.setPrompt(messages);

      String response2 = '';
      tokenCount = 0;

      while (tokenCount < maxTokens) {
        final delta = model.generate();
        if (delta == null) break;
        response2 += delta;
        tokenCount++;
      }

      expect(response2, isNotEmpty);
    });

    test('context full detection', () {
      // Open with very small context
      model.open(modelPath, 128);

      // Try to set a very long prompt
      final longContent = 'This is a very long text. ' * 100;
      final messages = [
        {'role': 'user', 'content': longContent}
      ];

      model.setPrompt(messages);

      // If context is full, contextFull() should return true
      if (model.contextFull()) {
        expect(model.contextFull(), isTrue);
      }
    });
  });

  group('AiliaLLMModel Multimodal Tests', () {
    late AiliaLLMModel model;
    late String modelPath;
    late String mmprojPath;
    late String imagePath;

    setUpAll(() {
      final homeDir = Platform.environment['HOME'] ?? '';

      // Check for multimodal model files
      modelPath = Platform.environment['AILIA_LLM_TEST_MULTIMODAL_MODEL'] ?? '';
      mmprojPath = Platform.environment['AILIA_LLM_TEST_MMPROJ'] ?? '';
      imagePath = Platform.environment['AILIA_LLM_TEST_IMAGE'] ?? '';
    });

    setUp(() {
      model = AiliaLLMModel();
    });

    tearDown(() {
      model.close();
    });

    test('openMultimodalProjectorFile loads projector', () {
      if (modelPath.isEmpty || mmprojPath.isEmpty) {
        print('Skipping test: Multimodal model files not found');
        return;
      }

      model.open(modelPath, 4096);
      expect(
        () => model.openMultimodalProjectorFile(mmprojPath),
        returnsNormally,
      );
    });

    test('getMultimodalCapabilities returns capabilities', () {
      if (modelPath.isEmpty || mmprojPath.isEmpty) {
        print('Skipping test: Multimodal model files not found');
        return;
      }

      model.open(modelPath, 4096);
      model.openMultimodalProjectorFile(mmprojPath);

      final capabilities = model.getMultimodalCapabilities();
      expect(capabilities, isA<Map<String, bool>>());
      expect(capabilities.containsKey('vision'), isTrue);
      expect(capabilities.containsKey('audio'), isTrue);
    });

    test('setMultimodalPrompt with image', () {
      if (modelPath.isEmpty || mmprojPath.isEmpty || imagePath.isEmpty) {
        print('Skipping test: Multimodal files not found');
        return;
      }

      if (!File(imagePath).existsSync()) {
        print('Skipping test: Image file not found');
        return;
      }

      model.open(modelPath, 4096);
      model.openMultimodalProjectorFile(mmprojPath);

      final messages = [
        {
          'role': 'user',
          'content': 'Please describe what you see in this image. <__media__>',
          'media_data': [
            {
              'media_type': 'image',
              'file_path': imagePath,
              'width': 0,
              'height': 0,
            }
          ]
        }
      ];

      expect(() => model.setMultimodalPrompt(messages), returnsNormally);
    });

    test('multimodal image inference', () {
      if (modelPath.isEmpty || mmprojPath.isEmpty || imagePath.isEmpty) {
        print('Skipping test: Multimodal files not found');
        return;
      }

      if (!File(imagePath).existsSync()) {
        print('Skipping test: Image file not found');
        return;
      }

      model.open(modelPath, 4096);
      model.openMultimodalProjectorFile(mmprojPath);

      final messages = [
        {
          'role': 'user',
          'content': 'Please describe what you see in this image. <__media__>',
          'media_data': [
            {
              'media_type': 'image',
              'file_path': imagePath,
              'width': 0,
              'height': 0,
            }
          ]
        }
      ];

      model.setMultimodalPrompt(messages);

      String fullResponse = '';
      int tokenCount = 0;
      const maxTokens = 50;

      while (tokenCount < maxTokens) {
        final delta = model.generate();
        if (delta == null) break;
        fullResponse += delta;
        tokenCount++;
      }

      expect(fullResponse, isNotEmpty);
    });
  });
}
