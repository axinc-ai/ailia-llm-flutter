#include "include/ailia_llm/ailia_llm_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "ailia_llm_plugin.h"

void AiliaLlmPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  ailia_llm::AiliaLlmPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
