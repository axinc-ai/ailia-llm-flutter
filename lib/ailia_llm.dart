import 'dart:ffi';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:ffi/ffi.dart';

import '../ffi/ailia_llm.dart' as ailia_llm_dart;
import './ailia_llm_lib.dart' as ailia_llm_lib;

enum AiliaLlmInferenceStatus {
  success,
}

class AiliaLlmInferenceState {
  AiliaLLm ailiaLlm;
  dynamic dllHandle;

  AiliaLlmInferenceState(this.ailiaLlm) {
    dllHandle = ailia_llm_dart.ailiaLlmFFI(ailia_llm_lib
        .ailiaCommonGetLibrary(ailia_llm_lib.ailiaCommonGetLlmPath()));
  }

  /// Free memory allocated natively.
  void dispose() {}

  /// Set the prompt to be process by the model.
  /// The prompt will be formatted according to the selected format.
  /// messages must be an array of object with two string properties
  /// named 'role' and 'content'.
  int setPromptFromMessages(List<Map<String, dynamic>> messages) {
    // Allocate an array of ailia_llm_chat_message_t and initialize it
    // with the messages data.
    final messagesPtr =
        calloc<ailia_llm_dart.AILIALLMChatMessage>(messages.length);

    try {
      for (var i = 0; i < messages.length; i++) {
        if (!messages[i].containsKey("content")) {
          throw Exception("missing 'content' property");
        }
        if (!messages[i].containsKey("role")) {
          throw Exception("missing 'role' property");
        }

        final content = messages[i]['content'] as String;
        final role = messages[i]['role'] as String;
        final p = messagesPtr[i];

        String roleStr = "system";
        if (role == "system") {
          roleStr = "system";
        } else if (role == "user") {
          roleStr = "user";
        } else if (role == "assistant") {
          roleStr = "assistant";
        } else {
          throw Exception("unknown 'role' property value '$role'");
        }
        p.content = content.toNativeUtf8().cast<Char>();
        p.role = roleStr.toNativeUtf8().cast<Char>();
      }

      return dllHandle.ailiaLLMSetPrompt(
          ailiaLlm.pLLm.value, messagesPtr, messages.length);
    } finally {
      // free string
      malloc.free(messagesPtr);
    }
  }

  String pointerCharToString(Pointer<Char> pointer) {
    var length = 0;
    while (pointer.elementAt(length).value != 0) {
      length++;
    }

    var buffer = Uint8List(length);
    for (var i = 0; i < length; i++) {
      buffer[i] = pointer.elementAt(i).value;
    }

    return utf8.decode(buffer);
  }

  /// Ask the model to generate the next token.
  /// This function properly handle incomplete multi-byte utf8 character.
  String? getNextToken() {
    Pointer<Bool> done = malloc<Bool>();
    var status = dllHandle.ailiaLLMGenerate(
      ailiaLlm.pLLm.value,
      done,
    );

    bool done_flag = done.value;
    malloc.free(done);

    if (done_flag == true) {
      return null;
    }

    if (status != 0) {
      return null;
    }

    // Try first with gBuff which is a buffer associated to this
    // prompt instance.
    final Pointer<UnsignedInt> size = malloc<UnsignedInt>();
    dllHandle.ailiaLLMGetDeltaTextSize(ailiaLlm.pLLm.value, size);

    final Pointer<Char> byteBuffer = malloc<Char>(size.value);
    dllHandle.ailiaLLMGetDeltaText(ailiaLlm.pLLm.value, byteBuffer, size.value);
    String deltaText = pointerCharToString(byteBuffer);

    malloc.free(size);
    malloc.free(byteBuffer);

    return deltaText;
  }

  static AiliaLlmInferenceStatus fromNative(int status) {
    switch (status) {
      case 0:
        return AiliaLlmInferenceStatus.success;
      default:
        throw Exception("Invalid ailia llm inference status $status");
    }
  }
}

class AiliaLLm {
  Pointer<Pointer<ailia_llm_dart.AILIALLM>> pLLm = nullptr;
  dynamic dllHandle;

  AiliaLLm() {
    dllHandle = ailia_llm_dart.ailiaLlmFFI(ailia_llm_lib
        .ailiaCommonGetLibrary(ailia_llm_lib.ailiaCommonGetLlmPath()));
  }

  /// Initialize the context using the given model and parameters.
  void initialize(String model_path, int n_ctx) {
    if (pLLm != nullptr) {
      if (pLLm.value != nullptr) {
        dllHandle.ailiaLLMDestory(pLLm.value);
      }
    }

    pLLm = malloc<Pointer<ailia_llm_dart.AILIALLM>>();
    pLLm.value = nullptr;

    var status = dllHandle.ailiaLLMCreate(pLLm, n_ctx);
    if (status != 0) {
      throw Exception("ailiaLLMCreate returned an error status $status");
    }
    if (Platform.isWindows) {
      status = dllHandle.ailiaLLMOpenModelFileW(
          pLLm.value, model_path.toNativeUtf16().cast<WChar>());
    } else {
      status = dllHandle.ailiaLLMOpenModelFileA(
          pLLm.value, model_path.toNativeUtf8().cast<Char>());
    }
    if (status != 0) {
      throw Exception("ailiaLLMOpenModelFile returned an error status $status");
    }
  }

  /// Free memory allocated natively.
  void dispose() {
    if (pLLm != nullptr) {
      if (pLLm.value != nullptr) {
        dllHandle.ailiaLLMDestroy(pLLm.value);
        pLLm.value = nullptr;
      }
    }
  }

  /// Create an inference state associated to this context.
  AiliaLlmInferenceState createInferenceState() {
    return AiliaLlmInferenceState(this);
  }
}
