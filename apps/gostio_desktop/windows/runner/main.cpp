#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

// The origin is given in logical pixels and scaled by the monitor it lands on,
// so the work area has to be divided by the same factor before the window is
// measured against it.
Win32Window::Point CentredOrigin(const Win32Window::Size& size) {
  RECT work_area;
  if (!::SystemParametersInfo(SPI_GETWORKAREA, 0, &work_area, 0)) {
    return Win32Window::Point(10, 10);
  }

  const double scale = ::GetDpiForSystem() / 96.0;
  const double left = work_area.left / scale;
  const double top = work_area.top / scale;
  const double width = (work_area.right - work_area.left) / scale;
  const double height = (work_area.bottom - work_area.top) / scale;

  const double x = left + (width - size.width) / 2;
  const double y = top + (height - size.height) / 2;

  return Win32Window::Point(static_cast<unsigned int>(x < left ? left : x),
                            static_cast<unsigned int>(y < top ? top : y));
}

}  // namespace

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

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Size size(1440, 900);
  Win32Window::Point origin = CentredOrigin(size);
  if (!window.Create(L"Gostio", origin, size)) {
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
