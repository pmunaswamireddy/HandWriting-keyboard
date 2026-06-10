#ifndef FONT_INSTALLER_PLUGIN_H_
#define FONT_INSTALLER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <memory>

namespace font_installer {

class FontInstallerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  FontInstallerPlugin();
  virtual ~FontInstallerPlugin();

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

} // namespace font_installer

#endif // FONT_INSTALLER_PLUGIN_H_
