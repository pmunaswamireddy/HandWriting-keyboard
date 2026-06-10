#include "font_installer_plugin.h"

#include <windows.h>
#include <shlobj.h>
#include <string>
#include <filesystem>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

namespace font_installer {

// static
void FontInstallerPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(),
      "com.handwritingkeyboard/font_installer",
      &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FontInstallerPlugin>();
  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

FontInstallerPlugin::FontInstallerPlugin() {}
FontInstallerPlugin::~FontInstallerPlugin() {}

void FontInstallerPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  if (method_call.method_name() == "installFontWindows") {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!args) {
      result->Error("INVALID_ARGS", "Expected map arguments");
      return;
    }

    // Get font path from args
    auto fontPathIt = args->find(flutter::EncodableValue("fontPath"));
    if (fontPathIt == args->end()) {
      result->Error("MISSING_ARG", "fontPath is required");
      return;
    }
    std::string fontPath = std::get<std::string>(fontPathIt->second);

    // Convert to wide string for Windows API
    std::wstring widePath(fontPath.begin(), fontPath.end());

    // Step 1: Copy font to Windows Fonts directory
    wchar_t windowsDir[MAX_PATH];
    GetWindowsDirectoryW(windowsDir, MAX_PATH);
    std::wstring fontsDir = std::wstring(windowsDir) + L"\\Fonts\\";

    // Extract filename
    std::filesystem::path srcPath(widePath);
    std::wstring destPath = fontsDir + srcPath.filename().wstring();

    // Copy font file
    if (!CopyFileW(widePath.c_str(), destPath.c_str(), FALSE)) {
      DWORD err = GetLastError();
      result->Error("COPY_FAILED",
          "Failed to copy font to Windows\\Fonts. Error: " + std::to_string(err) +
          ". Try running as Administrator.");
      return;
    }

    // Step 2: Register font with system using AddFontResource
    int added = AddFontResourceW(destPath.c_str());
    if (added == 0) {
      result->Error("REGISTER_FAILED", "AddFontResource failed");
      return;
    }

    // Step 3: Write to registry so font persists across reboots
    std::string fontPathStr = fontPath;
    auto fontNameIt = args->find(flutter::EncodableValue("fontName"));
    std::string fontName = (fontNameIt != args->end())
        ? std::get<std::string>(fontNameIt->second)
        : "HandwritingKeyboard";
    fontName += " (TrueType)";

    HKEY hKey;
    RegOpenKeyExA(HKEY_LOCAL_MACHINE,
        "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Fonts",
        0, KEY_SET_VALUE, &hKey);
    std::string fileName = srcPath.filename().string();
    RegSetValueExA(hKey, fontName.c_str(), 0, REG_SZ,
        (const BYTE*)fileName.c_str(), (DWORD)fileName.size() + 1);
    RegCloseKey(hKey);

    // Step 4: Notify all apps of font change
    SendMessageTimeoutW(HWND_BROADCAST, WM_FONTCHANGE, 0, 0,
        SMTO_ABORTIFHUNG, 1000, nullptr);

    flutter::EncodableMap successMap;
    successMap[flutter::EncodableValue("success")] = flutter::EncodableValue(true);
    result->Success(flutter::EncodableValue(successMap));

  } else {
    result->NotImplemented();
  }
}

} // namespace font_installer
