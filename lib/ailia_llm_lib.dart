import 'dart:ffi';
import 'dart:io';

String ailiaCommonGetLlmPath() {
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

DynamicLibrary ailiaCommonGetLibrary(String path) {
  final DynamicLibrary library;
  if (Platform.isIOS) {
    library = DynamicLibrary.process();
  } else {
    library = DynamicLibrary.open(path);
  }
  return library;
}
