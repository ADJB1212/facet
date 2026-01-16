#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

void linux_wayland_init_app(void) {
  fprintf(stderr, "Wayland in not supported yet.\n");
  fprintf(stderr, "Please use XWayland for now.\n");
  exit(1);
}

bool linux_wayland_poll_events(void) { return false; }
void linux_wayland_present_frame(void) {}
bool linux_wayland_is_key_down(uint16_t k) { return false; }
bool linux_wayland_is_mouse_down(uint8_t b) { return false; }
void linux_wayland_get_last_click_position(float *x, float *y) {
  if (x)
    *x = 0;
  if (y)
    *y = 0;
}
