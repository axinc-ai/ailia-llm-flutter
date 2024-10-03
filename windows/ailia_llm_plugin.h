#ifndef FLUTTER_PLUGIN_AILIA_LLM_PLUGIN_H_
#define FLUTTER_PLUGIN_AILIA_LLM_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace ailia_llm {

class AiliaLlmPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  AiliaLlmPlugin();

  virtual ~AiliaLlmPlugin();

  // Disallow copy and assign.
  AiliaLlmPlugin(const AiliaLlmPlugin&) = delete;
  AiliaLlmPlugin& operator=(const AiliaLlmPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace ailia_llm

#endif  // FLUTTER_PLUGIN_AILIA_LLM_PLUGIN_H_
