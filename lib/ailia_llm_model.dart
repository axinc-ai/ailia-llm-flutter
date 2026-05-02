import 'dart:ffi';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'dart:ffi';

import 'ailia_llm.dart' as ailia_llm_dart;

const String BACKEND_CPU = "CPU";
const String BACKEND_VULKAN = "Vulkan";
const String BACKEND_METAL = "Metal";

List<List<String>> _ailiaCommonGetLlmPath() {
  if (Platform.isAndroid || Platform.isLinux) {
    return [
      ['libailia_llm.so'],
      [BACKEND_CPU]
    ];
  }
  if (Platform.isMacOS) {
    return [
      ['libailia_llm.dylib'],
      [BACKEND_METAL]
    ];
  }
  if (Platform.isWindows) {
    return [
      ['ailia_llm_fallback.dll', 'ailia_llm.dll'],
      [BACKEND_CPU, BACKEND_VULKAN]
    ];
  }
  return [
    ['internal'],
    [BACKEND_CPU]
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

typedef VkEnumerateInstanceVersionNative = Int32 Function(
    Pointer<Uint32> apiVersion);
typedef VkEnumerateInstanceVersionDart = int Function(
    Pointer<Uint32> apiVersion);

class AiliaLLMModel {
  static List<List<String>> _backend = List<List<String>>.empty();

  Pointer<Pointer<ailia_llm_dart.AILIALLM>> pLLm = nullptr;
  DynamicLibrary? _library;
  dynamic dllHandle;
  String _currentBackend = "";
  bool _contextFull = false;
  Uint8List _buf = Uint8List(0);
  String _beforeText = "";
  bool _multimodalProjectorOpened = false;

  AiliaLLMModel() {}

  static bool checkVulkanVersion() {
    try {
      final DynamicLibrary vulkanLib = Platform.isWindows
          ? DynamicLibrary.open('vulkan-1.dll')
          : DynamicLibrary.open('libvulkan.so');
      final VkEnumerateInstanceVersionDart vkEnumerateInstanceVersion =
          vulkanLib.lookupFunction<VkEnumerateInstanceVersionNative,
              VkEnumerateInstanceVersionDart>('vkEnumerateInstanceVersion');
      final Pointer<Uint32> apiVersion = calloc<Uint32>();
      final int result = vkEnumerateInstanceVersion(apiVersion);
      bool available = false;
      if (result == 0) {
        final int version = apiVersion.value;
        final int variant = (version >> 29);
        final int major = (version >> 22) & 0x7F;
        final int minor = (version >> 12) & 0x3FF;
        available = variant  == 0 && (major > 1 || (major == 1 && minor >= 1));
        //print("Vulkan version ${major}.${minor}");
      }
      calloc.free(apiVersion);
      return available;
    } on Exception {
    } on ArgumentError {}
    return false;
  }

  static List<String> getBackendList() {
    if (_backend.length > 0) {
      return _backend[1];
    }
    _backend = List<List<String>>.empty(growable: true);
    _backend.add(List<String>.empty(growable: true));
    _backend.add(List<String>.empty(growable: true));
    List<List<String>> libraries = _ailiaCommonGetLlmPath();
    for (int i = 0; i < libraries[0].length; i++) {
      // Check Vulkan Supported Version
      if (libraries[1][i] == BACKEND_VULKAN) {
        if (checkVulkanVersion() == false) {
          continue;
        }
      }
      // Continue
      try {
        DynamicLibrary library = _ailiaCommonGetLibrary(libraries[0][i]);
        _backend[0].add(libraries[0][i]);
        _backend[1].add(libraries[1][i]);
        library.close();
      } on Exception {
      } on ArgumentError {}
    }
    return _backend[1];
  }

  /// Initialize the context using the given model and parameters.
  void open(String modelPath, int nCtx, {String backend = ""}) {
    if (pLLm != nullptr) {
      if (pLLm.value != nullptr) {
        dllHandle.ailiaLLMDestroy(pLLm.value);
      }
    }

    // Reset multimodal projector state when opening a new model
    _multimodalProjectorOpened = false;

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
        if (backendList[i] == backend) {
          _library = _ailiaCommonGetLibrary(_backend[0][i]);
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
    // Reset multimodal projector state when closing the model
    _multimodalProjectorOpened = false;
  }

  void setSamplingParams(int top_k, double top_p, double temp, int dist) {
    if (pLLm == nullptr) {
      throw Exception("ailia LLM not initialized.");
    }

    var status = dllHandle.ailiaLLMSetSamplingParams(
        pLLm.value, top_k, top_p, temp, dist);
    if (status != ailia_llm_dart.AILIA_LLM_STATUS_SUCCESS) {
      throw Exception("ailiaLLMGenerate returned an error status $status");
    }
  }

  /// Enable or disable thinking (reasoning output).
  /// Controls whether thinking models (e.g. Gemma4) output their reasoning process.
  /// Must be called before setPrompt.
  void setThinking(bool enable) {
    if (pLLm == nullptr) {
      throw Exception("ailia LLM not initialized.");
    }

    var status = dllHandle.ailiaLLMSetThinking(pLLm.value, enable ? 1 : 0);
    if (status != ailia_llm_dart.AILIA_LLM_STATUS_SUCCESS) {
      throw Exception("ailiaLLMSetThinking returned an error status $status");
    }
  }

  /// Check if any message in the list contains media_data.
  bool _hasMediaData(List<Map<String, dynamic>> messages) {
    for (var message in messages) {
      if (message.containsKey('media_data') && message['media_data'] != null) {
        final mediaData = message['media_data'];
        if (mediaData is List && mediaData.isNotEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  /// Set the prompt to be processed by the model.
  /// The prompt will be formatted according to the selected format.
  ///
  /// This unified method automatically detects if any message contains
  /// 'media_data' and routes to the appropriate internal API:
  /// - If media_data is present: uses SetMultimodalPrompt (requires projector to be loaded)
  /// - If no media_data: uses SetPrompt (text-only path)
  ///
  /// messages must be a list of maps with the following properties:
  /// - 'role' (String): The role (e.g., "system", "user", "assistant")
  /// - 'content' (String): The text content of the message
  /// - 'media_data' (List<Map<String, dynamic>>, optional): Media attachments, each containing:
  ///   - 'media_type' (String): Type of media (e.g., "image")
  ///   - 'file_path' (String): Path to the media file
  ///   - 'width' (int, optional): Media width in pixels
  ///   - 'height' (int, optional): Media height in pixels
  ///
  /// Throws an Exception if media_data is provided but multimodal projector
  /// is not loaded. Call openMultimodalProjectorFile() first in that case.
  void setPrompt(List<Map<String, dynamic>> messages) {
    if (pLLm == nullptr) {
      throw Exception("ailia LLM not initialized.");
    }

    bool hasMedia = _hasMediaData(messages);

    // If media_data exists, check that the multimodal projector is loaded
    if (hasMedia) {
      if (!_multimodalProjectorOpened) {
        throw Exception(
            "media_data was provided but multimodal projector is not loaded. "
            "Call openMultimodalProjectorFile() first to enable multimodal generation.");
      }
      // Use multimodal path
      _setMultimodalPromptInternal(messages);
    } else {
      // Use text-only path
      _setTextPromptInternal(messages);
    }
  }

  /// Internal implementation for text-only prompts.
  void _setTextPromptInternal(List<Map<String, dynamic>> messages) {
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
  }

  /// Ask the model to generate the next token.
  /// This function properly handle incomplete multi-byte utf8 character.
  String? generate() {
    if (pLLm == nullptr) {
      throw Exception("ailia LLM not initialized.");
    }

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

  // Open multimodal projector file
  void openMultimodalProjectorFile(String mmprojPath) {
    if (pLLm == nullptr) {
      throw Exception("ailia LLM not initialized.");
    }

    int status;
    if (Platform.isWindows) {
      Pointer<WChar> path = mmprojPath.toNativeUtf16().cast<WChar>();
      status = dllHandle.ailiaLLMOpenMultimodalProjectorFileW(pLLm.value, path);
      malloc.free(path);
    } else {
      Pointer<Char> path = mmprojPath.toNativeUtf8().cast<Char>();
      status = dllHandle.ailiaLLMOpenMultimodalProjectorFileA(pLLm.value, path);
      malloc.free(path);
    }
    if (status != ailia_llm_dart.AILIA_LLM_STATUS_SUCCESS) {
      throw Exception("ailiaLLMOpenMultimodalProjectorFile returned an error status $status");
    }
    _multimodalProjectorOpened = true;
  }

  // Get multimodal capabilities
  Map<String, bool> getMultimodalCapabilities() {
    if (pLLm == nullptr) {
      throw Exception("ailia LLM not initialized.");
    }

    final Pointer<UnsignedInt> visionSupport = malloc<UnsignedInt>();
    final Pointer<UnsignedInt> audioSupport = malloc<UnsignedInt>();

    int status = dllHandle.ailiaLLMGetMultimodalCapabilities(pLLm.value, visionSupport, audioSupport);

    bool vision = visionSupport.value != 0;
    bool audio = audioSupport.value != 0;

    malloc.free(visionSupport);
    malloc.free(audioSupport);

    if (status != ailia_llm_dart.AILIA_LLM_STATUS_SUCCESS) {
      throw Exception("ailiaLLMGetMultimodalCapabilities returned an error status $status");
    }

    return {"vision": vision, "audio": audio};
  }

  /// Internal implementation for multimodal prompts.
  void _setMultimodalPromptInternal(List<Map<String, dynamic>> messages) {
    // Allocate an array of AILIALLMMultimodalChatMessage and initialize it
    final messagesPtr = calloc<ailia_llm_dart.AILIALLMMultimodalChatMessage>(messages.length);

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

        // Handle media data if present
        if (messages[i].containsKey('media_data') && messages[i]['media_data'] != null) {
          final mediaList = messages[i]['media_data'] as List<Map<String, dynamic>>;
          if (mediaList.isNotEmpty) {
            final mediaPtr = calloc<ailia_llm_dart.AILIALLMMediaData>(mediaList.length);
            p.media_data = mediaPtr;
            p.media_count = mediaList.length;

            for (var j = 0; j < mediaList.length; j++) {
              final media = mediaList[j];
              final mediaData = mediaPtr[j];

              mediaData.media_type = (media['media_type'] as String).toNativeUtf8().cast<Char>();
              mediaData.file_path = (media['file_path'] as String).toNativeUtf8().cast<Char>();
              mediaData.data = nullptr;
              mediaData.data_size = 0;
              mediaData.width = media['width'] ?? 0;
              mediaData.height = media['height'] ?? 0;
            }
          } else {
            p.media_data = nullptr;
            p.media_count = 0;
          }
        } else {
          p.media_data = nullptr;
          p.media_count = 0;
        }
      }

      _contextFull = false;
      _buf = Uint8List(0);
      _beforeText = "";

      int status = dllHandle.ailiaLLMSetMultimodalPrompt(pLLm.value, messagesPtr, messages.length);
      if (status != ailia_llm_dart.AILIA_LLM_STATUS_SUCCESS) {
        if (status == ailia_llm_dart.AILIA_LLM_STATUS_CONTEXT_FULL) {
          _contextFull = true;
          return;
        }
        throw Exception("ailiaLLMSetMultimodalPrompt returned an error status $status");
      }
    } finally {
      // free strings and media data
      for (var i = 0; i < messages.length; i++) {
        final p = messagesPtr[i];
        if (p.content != nullptr) {
          malloc.free(p.content);
        }
        if (p.role != nullptr) {
          malloc.free(p.role);
        }
        if (p.media_data != nullptr) {
          for (var j = 0; j < p.media_count; j++) {
            final mediaData = p.media_data[j];
            if (mediaData.media_type != nullptr) {
              malloc.free(mediaData.media_type);
            }
            if (mediaData.file_path != nullptr) {
              malloc.free(mediaData.file_path);
            }
          }
          malloc.free(p.media_data);
        }
      }
      malloc.free(messagesPtr);
    }
  }

  /// Set multimodal prompt for generation with media attachments.
  ///
  /// @deprecated Use [setPrompt] instead. This method is deprecated and will
  /// be removed in a future version. The unified [setPrompt] method
  /// automatically detects media_data in messages and routes accordingly.
  ///
  /// messages must be a list of maps with the following properties:
  /// - 'role' (String): The role (e.g., "system", "user", "assistant")
  /// - 'content' (String): The text content with <__media__> placeholders
  /// - 'media_data' (List<Map<String, dynamic>>, optional): Media attachments
  @Deprecated('Use setPrompt() instead, which automatically detects media_data in messages.')
  void setMultimodalPrompt(List<Map<String, dynamic>> messages) {
    // Delegate to the unified setPrompt() method to ensure consistent behavior
    // and projector-loaded checks.
    setPrompt(messages);
  }
}
