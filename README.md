# guikit

An app-independent, immediate-mode GUI toolkit for Ada 2022, backed by Vulkan +
GLFW (via `df_vulkan` and `openglada_glfw`). Extracted from the `files` desktop
file manager so it can be reused by other applications.

## What's inside

- **`Guikit.Draw`** — the renderer-agnostic draw-command model (rectangles, text,
  icons, borders, carets), colors/palette, `Layout_Metrics`, text-render result
  types, and the accessibility-node model.
- **`Guikit.Vulkan`** — the GLFW + Vulkan rendering backend (window, submission,
  present) that consumes the draw commands.
- **`Guikit.Widgets`** — generic draw widgets: close button, panel, scrollbar,
  context menu, tooltip, caret, marquee, segmented selector, focus ring, drop
  shadow, input field.
- **`Guikit.Layout`** — pure geometry helpers (caret advance, scrollbar, toolbar,
  settings layouts, label measuring).
- **`Guikit.Input`** — input primitives (`Key_Code`, `Modifier_Set`,
  `Navigation_Direction`).
- **`Guikit.Utf8`** — display-width measurement.
- **`Guikit.Frame_Analysis`** — structural framebuffer analysis for headless GPU
  test gates.

The packages carry no dependency on any host application: `Guikit.*` builds
standalone (`alr build` → `libGuikit.a`). The host supplies the domain data,
computes geometry + colors, registers its own hit regions, and calls the widgets
to draw.

## Build

```sh
alr build
```

Requires sibling checkouts of its pinned dependencies where applicable.

## License

MIT OR Apache-2.0 WITH LLVM-exception.
