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

#pragma mark - SoftwareView

@interface SoftwareView : NSView
@end

@implementation SoftwareView {
  CGImageRef _image;
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

- (void)dealloc {
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