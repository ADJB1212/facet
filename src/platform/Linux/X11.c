#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern const uint32_t *zig_get_canvas_pixels(void);
extern size_t zig_get_canvas_width(void);
extern size_t zig_get_canvas_height(void);
extern size_t zig_get_canvas_stride(void);

static Display *display = NULL;
static Window window;
static int screen;
static bool keys[512] = {0};
static bool mouse_buttons[3] = {0};
static float last_click_x = 0.0f;
static float last_click_y = 0.0f;
static Atom wm_delete_window;
static XImage *ximage = NULL;
static GC gc;
static bool window_closed = false;

void linux_x11_init_app(void) {
  display = XOpenDisplay(NULL);
  if (!display) {
    fprintf(stderr, "Cannot open display\n");
    exit(1);
  }
  screen = DefaultScreen(display);

  size_t width = zig_get_canvas_width();
  size_t height = zig_get_canvas_height();
  if (width == 0)
    width = 800;
  if (height == 0)
    height = 600;

  window = XCreateSimpleWindow(display, RootWindow(display, screen), 10, 10,
                               width, height, 1, BlackPixel(display, screen),
                               WhitePixel(display, screen));

  XSelectInput(display, window,
               ExposureMask | KeyPressMask | KeyReleaseMask | ButtonPressMask |
                   ButtonReleaseMask | StructureNotifyMask);

  XStoreName(display, window, "Zig Facet App");

  wm_delete_window = XInternAtom(display, "WM_DELETE_WINDOW", False);
  XSetWMProtocols(display, window, &wm_delete_window, 1);

  XMapWindow(display, window);
  gc = XCreateGC(display, window, 0, NULL);

  XEvent e;
  while (1) {
    XNextEvent(display, &e);
    if (e.type == MapNotify)
      break;
  }
}

bool linux_x11_poll_events(void) {
  if (!display)
    return true;
  if (window_closed)
    return true;

  while (XPending(display) > 0) {
    XEvent event;
    XNextEvent(display, &event);

    switch (event.type) {
    case ClientMessage:
      if ((Atom)event.xclient.data.l[0] == wm_delete_window) {
        window_closed = true;
        return true;
      }
      break;
    case KeyPress:
      if (event.xkey.keycode < 512) {
        keys[event.xkey.keycode] = true;
      }
      break;
    case KeyRelease:
      if (event.xkey.keycode < 512) {

        keys[event.xkey.keycode] = false;
      }
      break;
    case ButtonPress:
      if (event.xbutton.button >= 1 && event.xbutton.button <= 3) {
        mouse_buttons[event.xbutton.button - 1] = true;
        last_click_x = (float)event.xbutton.x;

        last_click_y = (float)event.xbutton.y;
      }
      break;
    case ButtonRelease:
      if (event.xbutton.button >= 1 && event.xbutton.button <= 3) {
        mouse_buttons[event.xbutton.button - 1] = false;
      }
      break;
    case ConfigureNotify:

      break;
    }
  }
  return false;
}

void linux_x11_present_frame(void) {
  if (!display || window_closed)
    return;

  const uint32_t *pixels = zig_get_canvas_pixels();
  size_t width = zig_get_canvas_width();
  size_t height = zig_get_canvas_height();

  if (ximage && (ximage->width != width || ximage->height != height)) {
    XDestroyImage(ximage);
    ximage = NULL;
  }

  if (!ximage) {

    char *data = (char *)pixels;

    ximage = XCreateImage(display, DefaultVisual(display, screen),
                          DefaultDepth(display, screen), ZPixmap, 0, data,
                          width, height, 32, 0);
  } else {
    ximage->data = (char *)pixels;
  }

  XPutImage(display, window, gc, ximage, 0, 0, 0, 0, width, height);

  ximage->data = NULL;
}

bool linux_x11_is_key_down(uint16_t key_code) {
  if (key_code < 512)
    return keys[key_code];
  return false;
}

bool linux_x11_is_mouse_down(uint8_t button) {
  if (button < 3)
    return mouse_buttons[button];
  return false;
}

void linux_x11_get_last_click_position(float *x, float *y) {
  if (x)
    *x = last_click_x;
  if (y)
    *y = last_click_y;
}
