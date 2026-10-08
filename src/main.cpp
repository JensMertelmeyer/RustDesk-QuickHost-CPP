#include "portable_host.h"

namespace {

constexpr wchar_t kSingleInstanceMutexName[] =
  L"Local\\" PORTABLE_HOST_APP_NAME L"CppSingleInstance";

HWND WaitForRunningInstanceWindow(DWORD wait_ms) {
  const DWORD started = GetTickCount();
  while (true) {
    const HWND window = FindWindowW(PortableHostWindowClassName(), nullptr);
    if (window != nullptr) {
      return window;
    }
    if (GetTickCount() - started >= wait_ms) {
      break;
    }
    Sleep(100);
  }
  return nullptr;
}

void ActivateRunningInstanceWindow(HWND window) {
  if (window == nullptr) {
    return;
  }
  if (IsIconic(window)) {
    ShowWindowAsync(window, SW_RESTORE);
  } else {
    ShowWindowAsync(window, SW_SHOW);
  }
  SetForegroundWindow(window);
}

}  // namespace

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int) {
  HANDLE single_instance_mutex = CreateMutexW(nullptr, FALSE, kSingleInstanceMutexName);
  const DWORD mutex_error = GetLastError();
  const bool another_instance_exists = mutex_error == ERROR_ALREADY_EXISTS;

  if (another_instance_exists) {
    const HWND running_window = WaitForRunningInstanceWindow(10000);
    if (running_window != nullptr) {
      ActivateRunningInstanceWindow(running_window);
      if (single_instance_mutex != nullptr) {
        CloseHandle(single_instance_mutex);
      }
      return 0;
    }

    MessageBoxW(
        nullptr,
        L"Another " PORTABLE_HOST_APP_NAME L" Host instance is already starting or running.",
        PORTABLE_HOST_APP_NAME L" Host",
        MB_ICONWARNING | MB_OK);
    if (single_instance_mutex != nullptr) {
      CloseHandle(single_instance_mutex);
    }
    return 1;
  }

  PortableHostApp app;
  if (!app.Initialize(instance)) {
    MessageBoxW(
        nullptr,
        L"Failed to start the portable C++ host shell.",
        PORTABLE_HOST_APP_NAME L" Host",
        MB_ICONERROR | MB_OK);
    if (single_instance_mutex != nullptr) {
      CloseHandle(single_instance_mutex);
    }
    return 1;
  }
  const int exit_code = app.Run();
  if (single_instance_mutex != nullptr) {
    CloseHandle(single_instance_mutex);
  }
  return exit_code;
}
