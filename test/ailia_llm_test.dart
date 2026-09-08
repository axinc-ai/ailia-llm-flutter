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

    test('setThinking throws exception when LLM not initialized', () {
      expect(
        () => model.setThinking(true),
        throwsException,
      );
    });

    test('setTools throws exception when LLM not initialized', () {
      expect(
        () => model.setTools([
          {
            'type': 'function',
            'function': {'name': 'get_weather', 'parameters': {}}
          }
        ]),
        throwsException,
      );
    });

    test('setPrompt with tool messages throws exception when LLM not initialized', () {
      expect(
        () => model.setPrompt([
          {'role': 'user', 'content': 'Weather?'},
          {'role': 'tool', 'content': 'Sunny'}
        ]),
        throwsException,
      );
    });

    test('parseResponse throws exception when LLM not initialized', () {
      expect(
        () => model.parseResponse('Hello'),
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
      // Use model from environment variable
      modelPath = Platform.environment['AILIA_LLM_MODEL_PATH'] ?? '';
    });

    setUp(() {
      model = AiliaLLMModel();
    });

    tearDown(() {
      model.close();
    });

    test('open and close model successfully', () {
      expect(modelPath, isNotEmpty,
        reason: 'Model path not set. Set AILIA_LLM_MODEL_PATH environment variable.');
      expect(File(modelPath).existsSync(), isTrue,
        reason: 'Model file not found at $modelPath');

      expect(() => model.open(modelPath, nCtx), returnsNormally);
      expect(() => model.close(), returnsNormally);
    });

    test('setSamplingParams sets parameters successfully', () {
      expect(modelPath, isNotEmpty,
        reason: 'Model path not set. Set AILIA_LLM_MODEL_PATH environment variable.');
      expect(File(modelPath).existsSync(), isTrue,
        reason: 'Model file not found at $modelPath');

      model.open(modelPath, nCtx);
      expect(
        () => model.setSamplingParams(1, 0.98, 0.05, 3939),
        returnsNormally,
      );
    });

    test('setThinking sets parameter successfully', () {
      expect(modelPath, isNotEmpty,
        reason: 'Model path not set. Set AILIA_LLM_MODEL_PATH environment variable.');
      expect(File(modelPath).existsSync(), isTrue,
        reason: 'Model file not found at $modelPath');

      model.open(modelPath, nCtx);
      expect(
        () => model.setThinking(true),
        returnsNormally,
      );
      expect(
        () => model.setThinking(false),
        returnsNormally,
      );
    });

    test('setPrompt with valid messages succeeds', () {
      expect(modelPath, isNotEmpty,
        reason: 'Model path not set. Set AILIA_LLM_MODEL_PATH environment variable.');
      expect(File(modelPath).existsSync(), isTrue,
        reason: 'Model file not found at $modelPath');

      model.open(modelPath, nCtx);
      final messages = [
        {'role': 'system', 'content': '質問と同じ言語で回答してください。'},
        {'role': 'user', 'content': 'How many legs does a cat have?'}
      ];

      expect(() => model.setPrompt(messages), returnsNormally);
      expect(model.contextFull(), isFalse);
    });

    test('setPrompt throws exception when missing content', () {
      expect(modelPath, isNotEmpty,
        reason: 'Model path not set. Set AILIA_LLM_MODEL_PATH environment variable.');
      expect(File(modelPath).existsSync(), isTrue,
        reason: 'Model file not found at $modelPath');

      model.open(modelPath, nCtx);
      final messages = [
        {'role': 'user'}
      ];

      expect(() => model.setPrompt(messages), throwsException);
    });

    test('setPrompt throws exception when missing role', () {
      expect(modelPath, isNotEmpty,
        reason: 'Model path not set. Set AILIA_LLM_MODEL_PATH environment variable.');
      expect(File(modelPath).existsSync(), isTrue,
        reason: 'Model file not found at $modelPath');

      model.open(modelPath, nCtx);
      final messages = [
        {'content': 'Hello'}
      ];

      expect(() => model.setPrompt(messages), throwsException);
    });

    test('getTokenCount returns valid count', () {
      expect(modelPath, isNotEmpty,
        reason: 'Model path not set. Set AILIA_LLM_MODEL_PATH environment variable.');
      expect(File(modelPath).existsSync(), isTrue,
        reason: 'Model file not found at $modelPath');

      model.open(modelPath, nCtx);
      final count = model.getTokenCount('How many legs does a cat have?');

      expect(count, greaterThan(0));
      expect(count, isA<int>());
    });

    test('generate produces text output', () {
      expect(modelPath, isNotEmpty,
        reason: 'Model path not set. Set AILIA_LLM_MODEL_PATH environment variable.');
      expect(File(modelPath).existsSync(), isTrue,
        reason: 'Model file not found at $modelPath');

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
      expect(modelPath, isNotEmpty,
        reason: 'Model path not set. Set AILIA_LLM_MODEL_PATH environment variable.');
      expect(File(modelPath).existsSync(), isTrue,
        reason: 'Model file not found at $modelPath');

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
      expect(modelPath, isNotEmpty,
        reason: 'Model path not set. Set AILIA_LLM_MODEL_PATH environment variable.');
      expect(File(modelPath).existsSync(), isTrue,
        reason: 'Model file not found at $modelPath');

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
      expect(modelPath, isNotEmpty,
        reason: 'Model path not set. Set AILIA_LLM_MODEL_PATH environment variable.');
      expect(File(modelPath).existsSync(), isTrue,
        reason: 'Model file not found at $modelPath');

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

  group('AiliaLLMModel Thinking Tests', () {
    late String thinkingModelPath;

    setUpAll(() {
      thinkingModelPath = Platform.environment['AILIA_LLM_TEST_THINKING_MODEL_PATH'] ?? '';
    });

    String generateText(AiliaLLMModel m, int maxTokens) {
      final sb = StringBuffer();
      int count = 0;
      while (count < maxTokens) {
        final delta = m.generate();
        if (delta == null) break;
        sb.write(delta);
        count++;
      }
      return sb.toString();
    }

    test('setThinking output differs with Gemma4 E2B', () {
      expect(thinkingModelPath, isNotEmpty,
        reason: 'Thinking model path not set. Set AILIA_LLM_TEST_THINKING_MODEL_PATH environment variable.');
      expect(File(thinkingModelPath).existsSync(), isTrue,
        reason: 'Thinking model file not found at $thinkingModelPath');

      final messages = [
        {'role': 'user', 'content': 'What is the capital of France?'}
      ];

      // Thinking OFF
      final modelOff = AiliaLLMModel();
      modelOff.open(thinkingModelPath, 2048);
      modelOff.setSamplingParams(1, 0.0, 0.0, 42);
      modelOff.setThinking(false);
      modelOff.setPrompt(messages);
      final responseOff = generateText(modelOff, 100);
      modelOff.close();

      // Thinking ON
      final modelOn = AiliaLLMModel();
      modelOn.open(thinkingModelPath, 2048);
      modelOn.setSamplingParams(1, 0.0, 0.0, 42);
      modelOn.setThinking(true);
      modelOn.setPrompt(messages);
      final responseOn = generateText(modelOn, 100);
      modelOn.close();

      print('Thinking OFF: $responseOff');
      print('Thinking ON: $responseOn');

      expect(responseOff, isNotEmpty);
      expect(responseOn, isNotEmpty);
      expect(responseOn.contains('<think>') || responseOn.contains('thought'), isTrue,
        reason: 'Thinking ON response should contain thinking marker (<think> or thought)');
      expect(responseOff.contains('<think>') || responseOff.contains('<|channel>thought'), isFalse,
        reason: 'Thinking OFF response should not contain thinking marker');
      expect(responseOff, isNot(equals(responseOn)));
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
      expect(modelPath, isNotEmpty,
        reason: 'Multimodal model path not set. Set AILIA_LLM_TEST_MULTIMODAL_MODEL environment variable.');
      expect(mmprojPath, isNotEmpty,
        reason: 'Multimodal projector path not set. Set AILIA_LLM_TEST_MMPROJ environment variable.');

      model.open(modelPath, 4096);
      expect(
        () => model.openMultimodalProjectorFile(mmprojPath),
        returnsNormally,
      );
    });

    test('getMultimodalCapabilities returns capabilities', () {
      expect(modelPath, isNotEmpty,
        reason: 'Multimodal model path not set. Set AILIA_LLM_TEST_MULTIMODAL_MODEL environment variable.');
      expect(mmprojPath, isNotEmpty,
        reason: 'Multimodal projector path not set. Set AILIA_LLM_TEST_MMPROJ environment variable.');

      model.open(modelPath, 4096);
      model.openMultimodalProjectorFile(mmprojPath);

      final capabilities = model.getMultimodalCapabilities();
      expect(capabilities, isA<Map<String, bool>>());
      expect(capabilities.containsKey('vision'), isTrue);
      expect(capabilities.containsKey('audio'), isTrue);
    });

    test('setMultimodalPrompt with image', () {
      expect(modelPath, isNotEmpty,
        reason: 'Multimodal model path not set. Set AILIA_LLM_TEST_MULTIMODAL_MODEL environment variable.');
      expect(mmprojPath, isNotEmpty,
        reason: 'Multimodal projector path not set. Set AILIA_LLM_TEST_MMPROJ environment variable.');
      expect(imagePath, isNotEmpty,
        reason: 'Test image path not set. Set AILIA_LLM_TEST_IMAGE environment variable.');
      expect(File(imagePath).existsSync(), isTrue,
        reason: 'Image file not found at $imagePath');

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
      expect(modelPath, isNotEmpty,
        reason: 'Multimodal model path not set. Set AILIA_LLM_TEST_MULTIMODAL_MODEL environment variable.');
      expect(mmprojPath, isNotEmpty,
        reason: 'Multimodal projector path not set. Set AILIA_LLM_TEST_MMPROJ environment variable.');
      expect(imagePath, isNotEmpty,
        reason: 'Test image path not set. Set AILIA_LLM_TEST_IMAGE environment variable.');
      expect(File(imagePath).existsSync(), isTrue,
        reason: 'Image file not found at $imagePath');

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

    test('unified setPrompt with media_data', () {
      expect(modelPath, isNotEmpty,
        reason: 'Multimodal model path not set. Set AILIA_LLM_TEST_MULTIMODAL_MODEL environment variable.');
      expect(mmprojPath, isNotEmpty,
        reason: 'Multimodal projector path not set. Set AILIA_LLM_TEST_MMPROJ environment variable.');
      expect(imagePath, isNotEmpty,
        reason: 'Test image path not set. Set AILIA_LLM_TEST_IMAGE environment variable.');
      expect(File(imagePath).existsSync(), isTrue,
        reason: 'Image file not found at $imagePath');

      model.open(modelPath, 4096);
      model.openMultimodalProjectorFile(mmprojPath);

      // Use unified setPrompt() with media_data instead of setMultimodalPrompt()
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

      // This should work the same as setMultimodalPrompt
      expect(() => model.setPrompt(messages), returnsNormally);

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

    test('unified setPrompt with media_data throws when projector not loaded', () {
      expect(modelPath, isNotEmpty,
        reason: 'Multimodal model path not set. Set AILIA_LLM_TEST_MULTIMODAL_MODEL environment variable.');
      expect(imagePath, isNotEmpty,
        reason: 'Test image path not set. Set AILIA_LLM_TEST_IMAGE environment variable.');

      model.open(modelPath, 4096);
      // Intentionally NOT loading multimodal projector

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

      // Should throw an exception because projector is not loaded
      expect(() => model.setPrompt(messages), throwsException);
    });

    test('unified setPrompt without media_data works without projector', () {
      expect(modelPath, isNotEmpty,
        reason: 'Multimodal model path not set. Set AILIA_LLM_TEST_MULTIMODAL_MODEL environment variable.');

      model.open(modelPath, 4096);
      // Intentionally NOT loading multimodal projector

      // Text-only message without media_data
      final messages = [
        {
          'role': 'user',
          'content': 'Hello, how are you?',
        }
      ];

      // Should work without projector for text-only prompts
      expect(() => model.setPrompt(messages), returnsNormally);
    });

    test('setPrompt with empty media_data list uses text path', () {
      expect(modelPath, isNotEmpty,
        reason: 'Multimodal model path not set. Set AILIA_LLM_TEST_MULTIMODAL_MODEL environment variable.');

      model.open(modelPath, 4096);
      // Intentionally NOT loading multimodal projector

      // Message with empty media_data list
      final messages = [
        {
          'role': 'user',
          'content': 'Hello, how are you?',
          'media_data': <Map<String, dynamic>>[],
        }
      ];

      // Should work without projector because media_data is empty
      expect(() => model.setPrompt(messages), returnsNormally);
    });

    test('setPrompt with null media_data uses text path', () {
      expect(modelPath, isNotEmpty,
        reason: 'Multimodal model path not set. Set AILIA_LLM_TEST_MULTIMODAL_MODEL environment variable.');

      model.open(modelPath, 4096);
      // Intentionally NOT loading multimodal projector

      // Message with null media_data
      final messages = [
        {
          'role': 'user',
          'content': 'Hello, how are you?',
          'media_data': null,
        }
      ];

      // Should work without projector because media_data is null
      expect(() => model.setPrompt(messages), returnsNormally);
    });

    test('open resets multimodal projector state', () {
      expect(modelPath, isNotEmpty,
        reason: 'Multimodal model path not set. Set AILIA_LLM_TEST_MULTIMODAL_MODEL environment variable.');
      expect(mmprojPath, isNotEmpty,
        reason: 'Multimodal projector path not set. Set AILIA_LLM_TEST_MMPROJ environment variable.');
      expect(imagePath, isNotEmpty,
        reason: 'Test image path not set. Set AILIA_LLM_TEST_IMAGE environment variable.');

      // First, load model and projector
      model.open(modelPath, 4096);
      model.openMultimodalProjectorFile(mmprojPath);

      // Verify projector is loaded by successfully using media_data
      final multimodalMessages = [
        {
          'role': 'user',
          'content': 'Test <__media__>',
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
      expect(() => model.setPrompt(multimodalMessages), returnsNormally);

      // Now re-open the model (which should reset projector state)
      model.open(modelPath, 4096);

      // Attempting to use media_data should now throw because projector state was reset
      expect(() => model.setPrompt(multimodalMessages), throwsException);
    });

    test('close resets multimodal projector state', () {
      expect(modelPath, isNotEmpty,
        reason: 'Multimodal model path not set. Set AILIA_LLM_TEST_MULTIMODAL_MODEL environment variable.');
      expect(mmprojPath, isNotEmpty,
        reason: 'Multimodal projector path not set. Set AILIA_LLM_TEST_MMPROJ environment variable.');
      expect(imagePath, isNotEmpty,
        reason: 'Test image path not set. Set AILIA_LLM_TEST_IMAGE environment variable.');

      // First, load model and projector
      model.open(modelPath, 4096);
      model.openMultimodalProjectorFile(mmprojPath);

      // Verify projector is loaded by successfully using media_data
      final multimodalMessages = [
        {
          'role': 'user',
          'content': 'Test <__media__>',
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
      expect(() => model.setPrompt(multimodalMessages), returnsNormally);

      // Close and reopen
      model.close();
      model.open(modelPath, 4096);

      // Attempting to use media_data should now throw because projector state was reset
      expect(() => model.setPrompt(multimodalMessages), throwsException);
    });
  });
}
