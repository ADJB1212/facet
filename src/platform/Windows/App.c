#include <stdbool.h>
#include <stdint.h>
#include <windows.h>

extern uint32_t *zig_get_canvas_pixels();
extern size_t zig_get_canvas_width();
extern size_t zig_get_canvas_height();

static HWND hwnd;
static float last_click_x = 0.0f;
static float last_click_y = 0.0f;
static float mouse_x = 0.0f;
static float mouse_y = 0.0f;
static bool should_quit = false;

LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
  switch (msg) {
  case WM_CLOSE:
    should_quit = true;
    break;
  case WM_DESTROY:
    PostQuitMessage(0);
    break;
  case WM_LBUTTONDOWN:
  case WM_RBUTTONDOWN:
  case WM_MBUTTONDOWN:
    last_click_x = (float)(short)LOWORD(lParam);
    last_click_y = (float)(short)HIWORD(lParam);
    mouse_x = last_click_x;
    mouse_y = last_click_y;
    break;
  case WM_MOUSEMOVE:
    mouse_x = (float)(short)LOWORD(lParam);
    mouse_y = (float)(short)HIWORD(lParam);
    break;
  default:
    return DefWindowProc(hwnd, msg, wParam, lParam);
  }
  return 0;
}

void windows_init_app() {
  WNDCLASS wc = {0};
  wc.lpfnWndProc = WndProc;
  wc.hInstance = GetModuleHandle(NULL);
  wc.lpszClassName = "Facet";
  wc.hCursor = LoadCursor(NULL, IDC_ARROW);

  RegisterClass(&wc);

  size_t width = zig_get_canvas_width();
  size_t height = zig_get_canvas_height();

  RECT rect = {0, 0, (LONG)width, (LONG)height};
  AdjustWindowRect(&rect, WS_OVERLAPPEDWINDOW, FALSE);

  hwnd =
      CreateWindow(wc.lpszClassName, "Facet", WS_OVERLAPPEDWINDOW | WS_VISIBLE,
                   CW_USEDEFAULT, CW_USEDEFAULT, rect.right - rect.left,
                   rect.bottom - rect.top, NULL, NULL, wc.hInstance, NULL);
}

bool windows_poll_events() {
  MSG msg;
  while (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) {
    if (msg.message == WM_QUIT) {
      should_quit = true;
    }
    TranslateMessage(&msg);
    DispatchMessage(&msg);
  }
  return should_quit;
}

void windows_present_frame() {
  if (!hwnd)
    return;

  size_t width = zig_get_canvas_width();
  size_t height = zig_get_canvas_height();
  const uint32_t *pixels = zig_get_canvas_pixels();

  HDC hdc = GetDC(hwnd);

  BITMAPINFO bmi = {0};
  bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bmi.bmiHeader.biWidth = (LONG)width;
  bmi.bmiHeader.biHeight = -(LONG)height;
  bmi.bmiHeader.biPlanes = 1;
  bmi.bmiHeader.biBitCount = 32;
  bmi.bmiHeader.biCompression = BI_RGB;

  SetDIBitsToDevice(hdc, 0, 0, width, height, 0, 0, 0, height, pixels, &bmi,
                    DIB_RGB_COLORS);

  ReleaseDC(hwnd, hdc);
}

bool windows_is_key_down(uint16_t key_code) {
  return (GetAsyncKeyState(key_code) & 0x8000) != 0;
}

bool windows_is_mouse_down(uint8_t button) {
  int vkey = 0;
  switch (button) {
  case 0:
    vkey = VK_LBUTTON;
    break;
  case 1:
    vkey = VK_RBUTTON;
    break;
  case 2:
    vkey = VK_MBUTTON;
    break;
  default:
    return false;
  }
  return (GetAsyncKeyState(vkey) & 0x8000) != 0;
}

void windows_get_last_click_position(float *x, float *y) {
  *x = last_click_x;
  *y = last_click_y;
}

void windows_get_mouse_position(float *x, float *y) {
  *x = mouse_x;
  *y = mouse_y;
}
