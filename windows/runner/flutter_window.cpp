#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <cwchar>
#include <filesystem>
#include <optional>
#include <string>
#include <system_error>
#include <variant>

#include "flutter/generated_plugin_registrant.h"

namespace {

std::filesystem::path GetExecutableDirectory() {
  std::wstring buffer(MAX_PATH, L'\0');
  while (true) {
    DWORD length = ::GetModuleFileNameW(
        nullptr, buffer.data(), static_cast<DWORD>(buffer.size()));
    if (length == 0) {
      return {};
    }
    if (length < buffer.size()) {
      buffer.resize(length);
      return std::filesystem::path(buffer).parent_path();
    }
    if (buffer.size() > 32768) {
      return {};
    }
    buffer.resize(buffer.size() * 2);
  }
}

bool IsWindowsLightTheme() {
  DWORD value = 1;
  DWORD data_size = sizeof(value);
  const LONG status = ::RegGetValueW(
      HKEY_CURRENT_USER,
      L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
      L"AppsUseLightTheme", RRF_RT_REG_DWORD, nullptr, &value, &data_size);
  if (status != ERROR_SUCCESS) {
    return true;
  }
  return value != 0;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  RegisterAppIconChannel();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  return true;
}

void FlutterWindow::OnDestroy() {
  if (app_icon_channel_) {
    app_icon_channel_->SetMethodCallHandler(nullptr);
    app_icon_channel_ = nullptr;
  }
  if (HWND hwnd = GetHandle()) {
    if (custom_big_icon_) {
      ::SendMessage(hwnd, WM_SETICON, ICON_BIG, 0);
    }
    if (custom_small_icon_) {
      ::SendMessage(hwnd, WM_SETICON, ICON_SMALL, 0);
    }
  }
  ReleaseCustomIcons();

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::RegisterAppIconChannel() {
  app_icon_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "eros/app_icon",
          &flutter::StandardMethodCodec::GetInstance());

  app_icon_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "setAppIcon") {
          result->NotImplemented();
          return;
        }
        const auto* style = call.arguments()
                                ? std::get_if<std::string>(call.arguments())
                                : nullptr;
        if (!style) {
          result->Error("invalid_arguments",
                        "Expected app icon style string");
          return;
        }
        std::string error_code;
        std::string error_message;
        if (!ApplyAppIcon(*style, &error_code, &error_message)) {
          result->Error(error_code, error_message);
          return;
        }
        result->Success();
      });
}

bool FlutterWindow::ApplyAppIcon(const std::string& style,
                                 std::string* error_code,
                                 std::string* error_message) {
  auto set_error = [&](const char* code, const char* message) {
    if (error_code) {
      *error_code = code;
    }
    if (error_message) {
      *error_message = message;
    }
  };

  if (style != "auto" && style != "monochrome" && style != "light" &&
      style != "dark" && style != "purple") {
    set_error("invalid_app_icon", "Expected auto, light, dark, or purple");
    return false;
  }

  const std::filesystem::path exe_dir = GetExecutableDirectory();
  if (exe_dir.empty()) {
    set_error("exe_dir_unavailable", "Failed to resolve executable directory");
    return false;
  }

  const std::filesystem::path images_dir =
      exe_dir / L"data" / L"flutter_assets" / L"assets" / L"images";
  const bool want_light =
      (style == "light") ||
      ((style == "auto" || style == "monochrome") && IsWindowsLightTheme());
  const wchar_t* icon_name = nullptr;
  if (style == "purple") {
    icon_name = L"app_icon_purple.ico";
  } else if (want_light) {
    icon_name = L"app_icon_light.ico";
  } else {
    icon_name = L"app_icon_dark.ico";
  }

  std::filesystem::path icon_path = images_dir / icon_name;
  std::error_code ec;
  if (!std::filesystem::exists(icon_path, ec)) {
    if (want_light) {
      const std::filesystem::path fallback_path =
          images_dir / L"app_icon_mono.ico";
      ec.clear();
      if (std::filesystem::exists(fallback_path, ec)) {
        icon_path = fallback_path;
      } else {
        set_error("icon_not_found", "App icon asset file was not found");
        return false;
      }
    } else {
      set_error("icon_not_found", "App icon asset file was not found");
      return false;
    }
  }

  const int big_cx = ::GetSystemMetrics(SM_CXICON);
  const int big_cy = ::GetSystemMetrics(SM_CYICON);
  const int small_cx = ::GetSystemMetrics(SM_CXSMICON);
  const int small_cy = ::GetSystemMetrics(SM_CYSMICON);

  HICON new_big = static_cast<HICON>(::LoadImageW(
      nullptr, icon_path.c_str(), IMAGE_ICON, big_cx, big_cy, LR_LOADFROMFILE));
  HICON new_small = static_cast<HICON>(::LoadImageW(
      nullptr, icon_path.c_str(), IMAGE_ICON, small_cx, small_cy,
      LR_LOADFROMFILE));
  if (!new_big || !new_small) {
    if (new_big) {
      ::DestroyIcon(new_big);
    }
    if (new_small) {
      ::DestroyIcon(new_small);
    }
    set_error("load_icon_failed", "LoadImageW failed to load app icon");
    return false;
  }

  HWND hwnd = GetHandle();
  if (!hwnd) {
    ::DestroyIcon(new_big);
    ::DestroyIcon(new_small);
    set_error("window_unavailable", "Window handle is unavailable");
    return false;
  }

  ::SendMessage(hwnd, WM_SETICON, ICON_BIG, reinterpret_cast<LPARAM>(new_big));
  ::SendMessage(hwnd, WM_SETICON, ICON_SMALL,
                reinterpret_cast<LPARAM>(new_small));

  ReleaseCustomIcons();
  custom_big_icon_ = new_big;
  custom_small_icon_ = new_small;
  current_icon_style_ = (style == "monochrome") ? "auto" : style;
  return true;
}

void FlutterWindow::ReleaseCustomIcons() {
  if (custom_big_icon_) {
    ::DestroyIcon(custom_big_icon_);
    custom_big_icon_ = nullptr;
  }
  if (custom_small_icon_) {
    ::DestroyIcon(custom_small_icon_);
    custom_small_icon_ = nullptr;
  }
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_SETTINGCHANGE:
      if (lparam != 0 &&
          std::wcscmp(reinterpret_cast<const wchar_t*>(lparam),
                      L"ImmersiveColorSet") == 0 &&
          current_icon_style_ == "auto") {
        try {
          ApplyAppIcon("auto", nullptr, nullptr);
        } catch (...) {
        }
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
