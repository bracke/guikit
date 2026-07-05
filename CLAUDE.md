# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`guikit` is an app-independent, immediate-mode GUI toolkit for Ada 2022, backed by Vulkan + GLFW (`df_vulkan`, `openglada_glfw`) with text rasterization via `textrender`. It was extracted from the `files` desktop file manager; its consumers are the sibling `../files` (file manager) and `../launcher` (app launcher) crates. See `README.md` for the package tour.

## Build & test

Built with Alire (`alr`), which wraps GNAT and the `.gpr` files.

- `alr build` — compile the library (`libGuikit.a`). Style is checked at compile time, so a clean build passes style.
- `alr test` — run the AUnit suite. It lives in `tests/` as its **own crate** (`tests/alire.toml`, `tests/guikit_tests.gpr`, sources under `tests/tests/src/`), depending on `guikit` + `aunit`. Add a test by writing a `Guikit_Suite.*` child and registering it in `guikit_suite.adb`.

## The one rule that matters: caller owns policy

Widgets and layout are **domain-free and policy-free**. A `Guikit.Widgets` procedure takes the draw-command vectors `in out` (`Rectangles`, `Text`), plus clip size, geometry, colours, and **already-fitted** text — and only appends rectangles/glyphs. The **caller** keeps everything else: localization, text fitting/truncation, state→colour mapping, hit regions, and accessibility nodes. Never pull application concerns (localization, file-domain types, hit-testing policy) into guikit. When unsure whether something belongs here, it belongs in the consumer unless it is genuinely generic to any GUI app.

Corollary: guikit must **never** depend on a consumer. No `with Files.*` / `with Launcher.*`, ever. Dependencies point one way (consumer → guikit).

## Dependencies

`alire.toml` pins `textrender` to `../textrender` (a relative path, not a published crate); `df_vulkan` / `openglada_glfw` resolve from the Alire index. Builds fail unless `../textrender` exists as a sibling checkout.

## Code style (enforced by the compiler)

From `guikit.gpr` / the Alire config, and failing the build if violated: Ada 2022 (`-gnat2022`, `-gnatX`), 120-character max line (`-gnatyM120`), UTF-8 source (`-gnatW8`), unused-entity warnings (`-gnatwU`). Match the existing code: **3-space indentation**, and **GNATdoc `@param`/`@return` comments before every new public declaration** (see any `.ads`). `config/` is Alire-generated — do not hand-edit it.
