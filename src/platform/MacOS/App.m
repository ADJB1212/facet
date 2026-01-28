#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"

#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>
#include <stdbool.h>

#pragma mark - Zig imports

extern const void *zig_get_canvas_pixels(void);
extern NSInteger zig_get_canvas_width(void);
extern NSInteger zig_get_canvas_height(void);
extern NSInteger zig_get_canvas_stride(void);

static bool keys[512] = {0};
static bool mouse_buttons[3] = {0};
static float last_click_x = 0.0f;
static float last_click_y = 0.0f;
static float mouse_x = 0.0f;
static float mouse_y = 0.0f;

#pragma mark - SoftwareView

@interface SoftwareView : NSView
@end

@implementation SoftwareView {
  CGImageRef _image;
  NSTrackingArea *_trackingArea;
}

- (BOOL)acceptsFirstResponder {
  return YES;
}

- (void)keyDown:(NSEvent *)event {
  if (event.keyCode < 512) {
    keys[event.keyCode] = true;
  }
}

- (void)keyUp:(NSEvent *)event {
  if (event.keyCode < 512) {
    keys[event.keyCode] = false;
  }
}

- (void)updateMousePosition:(NSEvent *)event {
  NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
  mouse_x = (float)point.x;
  mouse_y = (float)(self.bounds.size.height - point.y);
}

- (void)updateTrackingAreas {
  if (_trackingArea) {
    [self removeTrackingArea:_trackingArea];
    _trackingArea = nil;
  }

  _trackingArea = [[NSTrackingArea alloc]
      initWithRect:self.bounds
           options:NSTrackingMouseMoved | NSTrackingActiveInKeyWindow |
                   NSTrackingInVisibleRect
             owner:self
          userInfo:nil];
  [self addTrackingArea:_trackingArea];
  [super updateTrackingAreas];
}

- (void)mouseMoved:(NSEvent *)event {
  [self updateMousePosition:event];
}

- (void)mouseDragged:(NSEvent *)event {
  [self updateMousePosition:event];
}

- (void)rightMouseDragged:(NSEvent *)event {
  [self updateMousePosition:event];
}

- (void)otherMouseDragged:(NSEvent *)event {
  [self updateMousePosition:event];
}

- (void)mouseDown:(NSEvent *)event {
  [self updateMousePosition:event];
  last_click_x = mouse_x;
  last_click_y = mouse_y;
  mouse_buttons[0] = true;
}

- (void)mouseUp:(NSEvent *)event {
  mouse_buttons[0] = false;
}

- (void)rightMouseDown:(NSEvent *)event {
  [self updateMousePosition:event];
  last_click_x = mouse_x;
  last_click_y = mouse_y;
  mouse_buttons[1] = true;
}

- (void)rightMouseUp:(NSEvent *)event {
  mouse_buttons[1] = false;
}

- (void)otherMouseDown:(NSEvent *)event {
  [self updateMousePosition:event];
  last_click_x = mouse_x;
  last_click_y = mouse_y;
  if (event.buttonNumber == 2) {
    mouse_buttons[2] = true;
  }
}

- (void)otherMouseUp:(NSEvent *)event {
  if (event.buttonNumber == 2) {
    mouse_buttons[2] = false;
  }
}

- (void)dealloc {
  if (_trackingArea) {
    [self removeTrackingArea:_trackingArea];
    _trackingArea = nil;
  }
  if (_image) CGImageRelease(_image);
}

- (void)updateWithPixels:(const void *)pixels
                   width:(NSInteger)width
                  height:(NSInteger)height
                  stride:(NSInteger)stride {
  if (_image) {
    CGImageRelease(_image);
    _image = NULL;
  }

  size_t bytesPerRow = stride * 4;

  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

  CGBitmapInfo bitmapInfo =
      kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst;

  CGDataProviderRef provider =
      CGDataProviderCreateWithData(NULL, pixels, bytesPerRow * height, NULL);

  _image =
      CGImageCreate(width, height, 8, 32, bytesPerRow, colorSpace, bitmapInfo,
                    provider, NULL, false, kCGRenderingIntentDefault);

  CGDataProviderRelease(provider);
  CGColorSpaceRelease(colorSpace);

  [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
  if (!_image) return;

  CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
  CGContextSetInterpolationQuality(ctx, kCGInterpolationNone);
  CGContextDrawImage(ctx, self.bounds, _image);
}

@end

#pragma mark - Renderer

@interface Renderer : NSObject
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) SoftwareView *view;
@end

@implementation Renderer

+ (instancetype)shared {
  static Renderer *r;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    r = [[Renderer alloc] init];
  });
  return r;
}

- (void)createWindow {
  NSRect rect = NSMakeRect(0, 0, 800, 600);

  self.window = [[NSWindow alloc]
      initWithContentRect:rect
                styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                           NSWindowStyleMaskResizable)
                  backing:NSBackingStoreBuffered
                    defer:NO];

  self.view = [[SoftwareView alloc] initWithFrame:rect];
  self.window.contentView = self.view;
  [self.window setAcceptsMouseMovedEvents:YES];

  [self.window center];
  [self.window setTitle:@"Zig Software Renderer"];
  [self.window makeKeyAndOrderFront:nil];
}

@end

#pragma mark - AppDelegate

@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation AppDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:
    (NSApplication *)sender {
  return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
}

@end

#pragma mark - C API exported to Zig

void macos_init_app(void) {
  @autoreleasepool {
    NSApplication *app = [NSApplication sharedApplication];
    [app setActivationPolicy:NSApplicationActivationPolicyRegular];

    AppDelegate *delegate = [[AppDelegate alloc] init];
    [app setDelegate:delegate];

    [app finishLaunching];
    [[Renderer shared] createWindow];
    [app activateIgnoringOtherApps:YES];
  }
}

bool macos_poll_events(void) {
  @autoreleasepool {
    NSApplication *app = [NSApplication sharedApplication];
    NSEvent *event;
    while ((event = [app nextEventMatchingMask:NSEventMaskAny
                                     untilDate:[NSDate distantPast]
                                        inMode:NSDefaultRunLoopMode
                                       dequeue:YES])) {
      [app sendEvent:event];
    }
    [app updateWindows];

    if (app.windows.count == 0) {
      return true;
    }

    return false;
  }
}

void macos_present_frame(void) {
  @autoreleasepool {
    Renderer *r = [Renderer shared];
    const void *pixels = zig_get_canvas_pixels();
    NSInteger w = zig_get_canvas_width();
    NSInteger h = zig_get_canvas_height();
    NSInteger stride = zig_get_canvas_stride();

    [r.view updateWithPixels:pixels width:w height:h stride:stride];
  }
}

bool macos_is_key_down(uint16_t key_code) {
  if (key_code < 512) {
    return keys[key_code];
  }
  return false;
}

bool macos_is_mouse_down(uint8_t button) {
  if (button < 3) {
    return mouse_buttons[button];
  }
  return false;
}

void macos_get_last_click_position(float *x, float *y) {
  if (x) {
    *x = last_click_x;
  }
  if (y) {
    *y = last_click_y;
  }
}

void macos_get_mouse_position(float *x, float *y) {
  if (x) {
    *x = mouse_x;
  }
  if (y) {
    *y = mouse_y;
  }
}
