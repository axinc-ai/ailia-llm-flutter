import 'dart:ffi';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:ffi/ffi.dart';

import 'ailia_llm.dart' as ailia_llm_dart;

import 'dart:ffi';
import 'dart:io';

String _ailiaCommonGetLlmPath() {
  if (Platform.isAndroid || Platform.isLinux) {
    return 'libailia_llm.so';
  }
  if (Platform.isMacOS) {
    return 'libailia_llm.dylib';
  }
  if (Platform.isWindows) {
    return 'ailia_llm.dll';
  }
  return 'internal';
}

DynamicLibrary _ailiaCommonGetLibrary(String path) {
  final DynamicLibrary library;
  if (Platform.isIOS) {
    library = DynamicLibrary.process();
  } else {
    library = DynamicLibrary.open(path);
  }
  return library;
}

class AiliaLLMModel {
  Pointer<Pointer<ailia_llm_dart.AILIALLM>> pLLm = nullptr;
  dynamic dllHandle;

  AiliaLLMModel() {
    dllHandle = ailia_llm_dart.ailiaLlmFFI(_ailiaCommonGetLibrary(_ailiaCommonGetLlmPath()));
  }

  /// Initialize the context using the given model and parameters.
  void open(String modelPath, int nCtx) {
    if (pLLm != nullptr) {
      if (pLLm.value != nullptr) {
        dllHandle.ailiaLLMDestory(pLLm.value);
      }
    }

    pLLm = malloc<Pointer<ailia_llm_dart.AILIALLM>>();
    pLLm.value = nullptr;

    var status = dllHandle.ailiaLLMCreate(pLLm, nCtx);
    if (status != 0) {
      throw Exception("ailiaLLMCreate returned an error status $status");
    }

    if (Platform.isWindows) {
      status = dllHandle.ailiaLLMOpenModelFileW(
          pLLm.value, modelPath.toNativeUtf16().cast<WChar>());
    } else {
      status = dllHandle.ailiaLLMOpenModelFileA(
          pLLm.value, modelPath.toNativeUtf8().cast<Char>());
    }
    if (status != 0) {
      throw Exception("ailiaLLMOpenModelFile returned an error status $status");
    }
  }

  /// Free memory allocated natively.
  void close() {
    if (pLLm != nullptr) {
      if (pLLm.value != nullptr) {
        dllHandle.ailiaLLMDestroy(pLLm.value);
        pLLm.value = nullptr;
      }
    }
  }

  /// Set the prompt to be process by the model.
  /// The prompt will be formatted according to the selected format.
  /// messages must be an array of object with two string properties
  /// named 'role' and 'content'.
  int setPrompt(List<Map<String, dynamic>> messages) {
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

        p.content = content.toNativeUtf8().cast<Char>();
        p.role = role.toNativeUtf8().cast<Char>();
      }

      return dllHandle.ailiaLLMSetPrompt(
          pLLm.value, messagesPtr, messages.length);
    } finally {
      // free string
      malloc.free(messagesPtr);
    }
  }

  String _pointerCharToString(Pointer<Char> pointer) {
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
  String? generate() {
    Pointer<Uint32> done = malloc<Uint32>();
    var status = dllHandle.ailiaLLMGenerate(
      pLLm.value,
      done,
    );

    int doneFlag = done.value;
    malloc.free(done);

    if (doneFlag == 1) {
      return null;
    }

    if (status != ailia_llm_dart.AILIA_LLM_STATUS_SUCCESS) {
      if (status == ailia_llm_dart.AILIA_LLM_STATUS_CONTEXT_FULL){
        return null;
      }
      throw Exception("ailiaLLMGenerate returned an error status $status");
    }

    // Try first with gBuff which is a buffer associated to this
    // prompt instance.
    final Pointer<UnsignedInt> size = malloc<UnsignedInt>();
    dllHandle.ailiaLLMGetDeltaTextSize(pLLm.value, size);

    final Pointer<Char> byteBuffer = malloc<Char>(size.value);
    dllHandle.ailiaLLMGetDeltaText(pLLm.value, byteBuffer, size.value);
    String deltaText = _pointerCharToString(byteBuffer);

    malloc.free(size);
    malloc.free(byteBuffer);

    return deltaText;
  }
}
