#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // Register deep link protocol handler for cactusapp://
  {
    HKEY hKey;
    const wchar_t* subKey = L"SOFTWARE\\Classes\\cactusapp";
    if (RegCreateKeyExW(HKEY_CURRENT_USER, subKey, 0, nullptr, 0, KEY_WRITE, nullptr, &hKey, nullptr) == ERROR_SUCCESS) {
      const wchar_t* defaultValue = L"URL:cactusapp Protocol";
      RegSetValueExW(hKey, nullptr, 0, REG_SZ, (const BYTE*)defaultValue, static_cast<DWORD>((wcslen(defaultValue) + 1) * sizeof(wchar_t)));
      const wchar_t* urlProtocol = L"";
      RegSetValueExW(hKey, L"URL Protocol", 0, REG_SZ, (const BYTE*)urlProtocol, static_cast<DWORD>((wcslen(urlProtocol) + 1) * sizeof(wchar_t)));

      HKEY hCmdKey;
      if (RegCreateKeyExW(hKey, L"shell\\open\\command", 0, nullptr, 0, KEY_WRITE, nullptr, &hCmdKey, nullptr) == ERROR_SUCCESS) {
        wchar_t exePath[MAX_PATH];
        GetModuleFileNameW(nullptr, exePath, MAX_PATH);
        std::wstring cmd = std::wstring(exePath) + L" \"%1\"";
        RegSetValueExW(hCmdKey, nullptr, 0, REG_SZ, (const BYTE*)cmd.c_str(), static_cast<DWORD>((cmd.length() + 1) * sizeof(wchar_t)));
        RegCloseKey(hCmdKey);
      }
      RegCloseKey(hKey);
    }
  }

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"my_cactus", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
