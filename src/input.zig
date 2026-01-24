const mouse = @import("user_input/mouse.zig");
const keyboard = @import("user_input/keyboard.zig");

pub const MouseButton = mouse.MouseButton;
pub const MousePosition = mouse.MousePosition;
pub const isMouseDown = mouse.isMouseDown;
pub const getLastClickPosition = mouse.getLastClickPosition;

pub const isKeyDown = keyboard.isKeyDown;
