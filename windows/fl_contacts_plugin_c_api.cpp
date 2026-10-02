#include "include/fl_contacts/fl_contacts_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "fl_contacts_plugin.h"

void FlContactsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  fl_contacts::FlContactsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
