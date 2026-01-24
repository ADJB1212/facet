# Facet

Facet is a Zig-based software rendering graphics library and game engine currently in early development. It provides a simple API for pixel manipulation, window management, and input handling across macOS, Windows, and Linux.

## Features

- **Software Renderer**: Direct pixel buffer manipulation for 2D and 3D graphics.
- **Window Management**: Custom windowing system for macOS (AppKit/CoreGraphics), Windows, and Linux (X11/Wayland).
- **No Heavy Dependencies**: Lightweight and built with minimal external dependencies.
- **Demos**: Includes several example projects to demonstrate capabilities:
  - **Asteroids**: A clone of the Asteroids arcade game.
  - **First Person**: A 3D software-rendered first-person perspective demo.
  - **Playground**: A testing ground for new features.

## Requirements

- **Zig**: Version 0.15.2 or later.

### Platform-Specific

- **macOS**: No additional requirements (uses system frameworks).
- **Windows**: No additional requirements (uses system frameworks).
- **Linux**: Requires X11 development libraries (e.g., `libx11-dev`).

## Getting Started

To run the included demos, use the `zig build` command followed by the demo name.

### Running Demos

**Asteroids Game:**

```bash
zig build asteroids
```

**3D First Person Demo:**

```bash
zig build fp
```

**Playground:**

```bash
zig build play
```

## Project Structure

- `src/`: Core library source code.
  - `canvas.zig`: Software renderer implementation.
  - `window.zig`: Window management and input.
  - `platform/`: Platform-specific backend code.
- `demos/`: Example applications using the library.

## License

See [LICENSE](LICENSE) file.
