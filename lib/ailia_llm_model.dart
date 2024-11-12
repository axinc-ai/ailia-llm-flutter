import 'dart:ffi';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:ffi/ffi.dart';

import 'ailia_llm.dart' as ailia_llm_dart;

List<List<String>> _ailiaCommonGetLlmPath() {
  if (Platform.isAndroid || Platform.isLinux) {
    return [
      ['libailia_llm.so'],
      ['CPU']
    ];
  }
  if (Platform.isMacOS) {
    return [
      ['libailia_llm.dylib'],
      ['Metal']
    ];
  }
  if (Platform.isWindows) {
    return [
      ['ailia_llm.dll', 'ailia_llm_vulkan.dll'],
      ['CPU', 'Vulkan']
    ];
  }
  return [
    ['internal'],
    ['CPU']
  ];
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
  static DynamicLibrary? _library = null;
  static List<List<String>> _backend = List<List<String>>.empty();

  Pointer<Pointer<ailia_llm_dart.AILIALLM>> pLLm = nullptr;
  dynamic dllHandle;
  String _currentBackend = "";
  bool _contextFull = false;
  Uint8List _buf = Uint8List(0);
  String _beforeText = "";
  List<Map<String, dynamic>> _prompt = List<Map<String, dynamic>>.empty();
  bool _existText = false;

  AiliaLLMModel() {}

  static List<String> getBackendList() {
    if (_backend.length > 0) {
      return _backend[1];
    }
    _backend = List<List<String>>.empty(growable: true);
    _backend.add(List<String>.empty(growable: true));
    _backend.add(List<String>.empty(growable: true));
    List<List<String>> libraries = _ailiaCommonGetLlmPath();
    for (int i = 0; i < libraries.length; i++) {
      try {
        _library = _ailiaCommonGetLibrary(libraries[0][i]);
        _backend[0].add(libraries[0][i]);
        _backend[1].add(libraries[1][i]);
        _library!.close();
      } on Exception {
      } on ArgumentError {}
    }
    return _backend[1];
  }

  /// Initialize the context using the given model and parameters.
  void open(String modelPath, int nCtx, {String backend = ""}) {
    if (pLLm != nullptr) {
      if (pLLm.value != nullptr) {
        dllHandle.ailiaLLMDestory(pLLm.value);
      }
    }

    if (backend == "") {
      backend = _backend[1][0];
    }

    if (_currentBackend != backend) {
      if (_library != null) {
        _library!.close();
        _library = null;
      }
      List<String> backendList = getBackendList();
      for (int i = 0; i < backendList.length; i++) {
        if (backendList[1][i] == backend) {
          _library = _ailiaCommonGetLibrary(backendList[0][i]);
          dllHandle = ailia_llm_dart.ailiaLlmFFI(_library!);
          _currentBackend = backend;
          break;
        }
      }
      if (_library == null) {
        throw Exception("ailiaLLM backend not found");
      }
    }

    pLLm = malloc<Pointer<ailia_llm_dart.AILIALLM>>();
    pLLm.value = nullptr;

    var status = dllHandle.ailiaLLMCreate(pLLm);
    if (status != 0) {
      throw Exception("ailiaLLMCreate returned an error status $status");
    }

    if (Platform.isWindows) {
      Pointer<WChar> path = modelPath.toNativeUtf16().cast<WChar>();
      status = dllHandle.ailiaLLMOpenModelFileW(pLLm.value, path, nCtx);
      malloc.free(path);
    } else {
      Pointer<Char> path = modelPath.toNativeUtf8().cast<Char>();
      status = dllHandle.ailiaLLMOpenModelFileA(pLLm.value, path, nCtx);
      malloc.free(path);
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
      malloc.free(pLLm);
      pLLm = nullptr;
    }
  }

  /// Set the prompt to be process by the model.
  /// The prompt will be formatted according to the selected format.
  /// messages must be an array of object with two string properties
  /// named 'role' and 'content'.
  void setPrompt(List<Map<String, dynamic>> messages) {
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

      _contextFull = false;
      _buf = Uint8List(0);
      _beforeText = "";

      int status =
          dllHandle.ailiaLLMSetPrompt(pLLm.value, messagesPtr, messages.length);
      if (status != ailia_llm_dart.AILIA_LLM_STATUS_SUCCESS) {
        if (status == ailia_llm_dart.AILIA_LLM_STATUS_CONTEXT_FULL) {
          _contextFull = true;
          return;
        }
        throw Exception("ailiaLLMSetPrompt returned an error status $status");
      }
    } finally {
      // free string
      for (var i = 0; i < messages.length; i++) {
        final p = messagesPtr[i];
        if (p.content != nullptr) {
          malloc.free(p.content);
        }
        if (p.role != nullptr) {
          malloc.free(p.role);
        }
      }
      malloc.free(messagesPtr);
    }

    _prompt = messages;
    _existText = false;
  }

  /// Ask the model to generate the next token.
  /// This function properly handle incomplete multi-byte utf8 character.
  String? generate() {
    if (pLLm == nullptr) {
      throw Exception("ailia LLM not initialized.");
    }
    String? result = _generate();
    if (result == null) {
      if (_existText == false) {
        for (int i = 0; i < 3; i++) {
          print("Retry LLM ${i}.");
          setPrompt(_prompt);
          result = _generate();
          if (result != null) {
            break;
          }
        }
      }
    } else {
      _existText = true;
    }
    return result;
  }

  String? _generate() {
    Pointer<Uint32> done = malloc<Uint32>();
    var status = dllHandle.ailiaLLMGenerate(
      pLLm.value,
      done,
    );
    int doneFlag = done.value;
    malloc.free(done);

    _contextFull = false;

    if (doneFlag == 1) {
      return null;
    }

    if (status != ailia_llm_dart.AILIA_LLM_STATUS_SUCCESS) {
      if (status == ailia_llm_dart.AILIA_LLM_STATUS_CONTEXT_FULL) {
        _contextFull = true;
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

    var buffer = Uint8List(size.value - 1);
    for (var i = 0; i < size.value - 1; i++) {
      buffer[i] = byteBuffer.elementAt(i).value;
    }

    Uint8List combinedUint8List = Uint8List(_buf.length + buffer.length);
    combinedUint8List.setRange(0, _buf.length, _buf);
    combinedUint8List.setRange(
        _buf.length, _buf.length + buffer.length, buffer);
    _buf = combinedUint8List;

    malloc.free(size);
    malloc.free(byteBuffer);

    String deltaText = "";
    try {
      String text = utf8.decode(_buf);
      if (_beforeText.length != text.length) {
        deltaText = text.substring(_beforeText.length);
      }
      _beforeText = text;
    } on FormatException catch (e) {
      // unicode decode error
    }

    return deltaText;
  }

  bool contextFull() {
    return _contextFull;
  }

  // Get token count
  int getTokenCount(String text) {
    if (pLLm == nullptr) {
      throw Exception("ailia LLM not initialized.");
    }

    final Pointer<UnsignedInt> count = malloc<UnsignedInt>();
    Pointer<Char> pText = text.toNativeUtf8().cast<Char>();
    dllHandle.ailiaLLMGetTokenCount(pLLm.value, count, pText);
    int retCount = count.value;
    malloc.free(count);
    return retCount;
  }
}
