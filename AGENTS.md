# Agent Instructions

This repository requires Alire GNAT 15. The root, tests, and tools crates pin
`gnat_native = "=15.2.1"`.

Do not run plain system `gnat*`, `gnatmake`, `gnatls`, `gnatprove`, or
`gprbuild` in this workspace. Use `alr exec -- ...` for compiler and builder
commands.

Preferred validation:

```sh
alr exec -- gnatls --version
alr build
alr test
alr exec -- gprbuild -P tools/guikit_check_all.gpr
tools/bin/check_all
```
