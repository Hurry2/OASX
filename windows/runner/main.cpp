#include <algorithm>

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr wchar_t kSkipParentConsoleArg[] = L"--skip-parent-console";
constexpr char kSkipParentConsoleArgUtf8[] = "--skip-parent-console";
constexpr wchar_t kAllowMultiInstanceArg[] = L"--allow-multi-instance";
constexpr char kAllowMultiInstanceArgUtf8[] = "--allow-multi-instance";

// Window class registered by Win32Window (windows/runner/win32_window.cpp).
//
// Do NOT rename it: the file_picker plugin resolves its parent window with
// FindWindowA on this exact class name (file_picker_windows.dart). The price is
// that the name is the stock Flutter template default, so other Flutter apps
// share it -- which is why the process executable is compared below too.
//
// The helpers below are compiled only for non-Debug builds: Debug does not use
// them, and leaving them in trips /W4 "unreferenced local function" -- the
// project builds with /WX, where a warning is an error.
#ifndef _DEBUG
constexpr wchar_t kAppWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr DWORD kImagePathSize = MAX_PATH * 2;

/// Returns the file name part of a path (tolerates a \\?\ prefix and '/').
const wchar_t* FileNameOf(const wchar_t* path) {
  const wchar_t* name = path;
  for (const wchar_t* cursor = path; *cursor != L'\0'; ++cursor) {
    if (*cursor == L'\\' || *cursor == L'/') {
      name = cursor + 1;
    }
  }
  return name;
}

/// File name of the running executable, e.g. oasx.exe.
const wchar_t* CurrentExecutableName() {
  static wchar_t name[kImagePathSize] = {};
  if (name[0] == L'\0') {
    wchar_t path[kImagePathSize] = {};
    if (::GetModuleFileNameW(nullptr, path, kImagePathSize) == 0) {
      return L"";
    }
    wcscpy_s(name, FileNameOf(path));
  }
  return name;
}

/// True when the window belongs to another running OASX (same class, same exe).
bool IsOtherOasxWindow(HWND window) {
  wchar_t class_name[256] = {};
  if (::GetClassNameW(window, class_name, _countof(class_name)) == 0 ||
      _wcsicmp(class_name, kAppWindowClassName) != 0) {
    return false;
  }

  DWORD process_id = 0;
  ::GetWindowThreadProcessId(window, &process_id);
  if (process_id == 0 || process_id == ::GetCurrentProcessId()) {
    return false;
  }

  HANDLE process =
      ::OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process_id);
  if (process == nullptr) {
    return false;
  }
  wchar_t image_path[kImagePathSize] = {};
  DWORD size = kImagePathSize;
  const BOOL query_ok =
      ::QueryFullProcessImageNameW(process, 0, image_path, &size);
  ::CloseHandle(process);
  if (!query_ok) {
    return false;
  }
  // Compare file names only: the same OASX counts as one instance wherever it is
// installed (including a UNC share), and path spelling differences fall away.
  return _wcsicmp(FileNameOf(image_path), CurrentExecutableName()) == 0;
}

struct FindInstanceState {
  HWND found = nullptr;
};

BOOL CALLBACK FindInstanceCallback(HWND window, LPARAM param) {
  auto* state = reinterpret_cast<FindInstanceState*>(param);
  if (!IsOtherOasxWindow(window)) {
    return TRUE;
  }
  state->found = window;
  return FALSE;  // one match is enough
}
#endif  // !_DEBUG

/// Single instance: when an OASX is already running, bring its window back and
/// return true so the caller can exit instead of starting a second process.
///
/// Without this, clicking the shortcut while the app is minimized (or hidden to
/// the tray) starts another process: two windows, two tray icons.
/// Only active in non-Debug builds, so `flutter run` keeps working while a
/// release build is open. Pass `--allow-multi-instance` to start a second
/// instance on purpose (e.g. to compare two backends).
bool ActivateRunningInstance() {
#ifndef _DEBUG
  FindInstanceState state;
  ::EnumWindows(&FindInstanceCallback, reinterpret_cast<LPARAM>(&state));
  if (state.found == nullptr) {
    return false;
  }
  // Minimized to the taskbar -> SW_RESTORE; hidden to the tray -> SW_SHOWNORMAL.
  ::ShowWindow(state.found,
               ::IsIconic(state.found) ? SW_RESTORE : SW_SHOWNORMAL);
  ::BringWindowToTop(state.found);
  ::SetForegroundWindow(state.found);
  return true;
#else
  return false;
#endif
}

/// Scans the command line for one switch.
bool HasCommandLineFlag(const wchar_t* flag) {
  int argc = 0;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return false;
  }

  bool found = false;
  for (int i = 1; i < argc; ++i) {
    if (wcscmp(argv[i], flag) == 0) {
      found = true;
      break;
    }
  }

  ::LocalFree(argv);
  return found;
}

bool HasSkipParentConsoleFlag() {
  return HasCommandLineFlag(kSkipParentConsoleArg);
}

void RemoveInternalArguments(std::vector<std::string>& arguments) {
  for (const char* flag :
       {kSkipParentConsoleArgUtf8, kAllowMultiInstanceArgUtf8}) {
    arguments.erase(std::remove(arguments.begin(), arguments.end(), flag),
                    arguments.end());
  }
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Already running -> raise the existing window; do not start a second process.
  if (!HasCommandLineFlag(kAllowMultiInstanceArg) &&
      ActivateRunningInstance()) {
    return EXIT_SUCCESS;
  }

  const bool skip_parent_console = HasSkipParentConsoleFlag();

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!skip_parent_console &&
      !::AttachConsole(ATTACH_PARENT_PROCESS) &&
      ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  RemoveInternalArguments(command_line_arguments);

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"oasx", origin, size)) {
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
