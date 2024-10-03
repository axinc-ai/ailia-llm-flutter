import 'dart:async';

import 'package:ailia_insight/ailia/ailia_llm.dart';
import 'package:ailia_insight/core/lib/logger.dart';
import 'package:ailia_insight/core/types/llm_input.dart';

const _logger = Logger(
  name: 'AiliaLLMRepository',
  loggerLevel: LoggerLevel.warn,
);

final class AiliaLLMRepository {
  final AiliaLLm _llm = AiliaLLm();
  AiliaLlmInferenceState? _inferenceState;
  bool _isModelLoaded = false;
  String _previousModelPath = '';

  void release() {
    _inferenceState?.dispose();
    _llm.dispose();
    _isModelLoaded = false;
  }

  Stream<int> loadModel(String modelPath, int n_ctx) {
    if (_previousModelPath == modelPath) {
      return StreamController<int>().stream;
    }
    _previousModelPath = modelPath;

    release();
    final controller = StreamController<int>();

    try {
      _llm.initialize(modelPath, n_ctx);
      _inferenceState = _llm.createInferenceState();
      _isModelLoaded = true;
    } catch (error) {
      final errorMessage =
          "Error occurred while opening the model. ${error.toString()}";
      _logger.error(errorMessage);
      controller.addError(errorMessage);
    } finally {
      controller.close();
    }
    return controller.stream;
  }

  Stream<String> setPromptMessages(
    List<LLMInput> messages,
  ) async* {
    if (_inferenceState == null || !_isModelLoaded) {
      _logger.debug('model is not loaded');
      return;
    }

    final promptMessage = messages.map((el) {
      final json = el.toMap();
      json['content'] = json['content'][0]!['text']!;
      return json;
    }).toList();

    final status = _inferenceState!.setPromptFromMessages(promptMessage);
    if (status != 0) {
      return;
    }

    _logger.debug('setPromptFromMessages status $status');

    // Retrieve the token from the model.
    String acc = "";
    int generatedTokenCount = 0;
    while (true) {
      final result = _inferenceState?.getNextToken();
      if (result == null) break;
      acc += result;
      generatedTokenCount += 1;
      _logger.debug(" => result.content = ${result}");
      yield result;
    }
    _logger.debug('model response is $acc');
    _logger.debug('model response token count is $generatedTokenCount');
    _logger.debug('done');
  }
}
