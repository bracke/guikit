# guikit

An app-independent, immediate-mode GUI toolkit for Ada 2022, backed by Vulkan +
GLFW (via `df_vulkan` and `openglada_glfw`). Extracted from the `files` desktop
file manager so it can be reused by other applications.

## What's inside

- **`Guikit.Draw`** — the renderer-agnostic draw-command model (rectangles,
  triangles, text, icons, borders, carets), colors/palette, `Layout_Metrics`,
  text-render result types, and the accessibility-node model.
- **`Guikit.Vulkan`** — the GLFW + Vulkan rendering backend (window, 4×/8× MSAA
  submission, present) that consumes the draw commands.
- **`Guikit.Palette`** — generic fuzzy search + ranking for a command-palette or
  searchable list: build a vector of `Item`s (an opaque id plus searchable
  identifier/label/description/shortcut strings), call `Search`, and get them
  scored and ordered best-first (exact over prefix over substring, stronger field
  over weaker, stable tiebreaker); an empty query keeps input order.
- **`Guikit.Widgets`** — emit-to-vectors draw widgets:
  - *chrome* — close button, menu panel, menu row, scrollbar, tooltip, caret,
    marquee, focus ring, drop shadow, input field;
  - *controls* — labelled button, toggle switch, number stepper, segmented selector;
  - *composites* — palette result row (background + selection accent + label,
    shortcut and description).
- **`Guikit.Layout`** — pure geometry helpers: caret advance, scrollbar, toolbar,
  bottom-bar, filter, settings and palette layouts + result-row/hit-testing,
  label measuring, and overflow-safe arithmetic.
- **`Guikit.Input`** — input primitives (`Key_Code`, `Modifier_Set`,
  `Navigation_Direction`).
- **`Guikit.Utf8`** — display-width measurement and whitespace token splitting
  (ASCII, C1, and Unicode space separators).
- **`Guikit.Frame_Analysis`** — structural framebuffer analysis for headless GPU
  test gates.

The packages carry no dependency on any host application: `Guikit.*` builds
standalone (`alr build` → `libGuikit.a`). The host owns all policy — it supplies
the domain data, computes geometry, resolves state colours, localizes and fits
label text, and registers its own hit regions and accessibility nodes; the
widgets only emit rectangles and text into the command vectors it passes in
(`in out`). That boundary keeps the toolkit reusable and lets the host layer it
however it likes (e.g. overlay vs. base layer).

## Build

```sh
alr build
```

Requires sibling checkouts of its pinned dependencies where applicable.

## License

MIT OR Apache-2.0 WITH LLVM-exception.
