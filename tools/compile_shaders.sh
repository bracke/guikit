#!/bin/sh
#  Regenerate the SPIR-V embedded in guikit-vulkan.adb from the GLSL beside it.
#
#  The shaders are compiled into the body as arrays of 32-bit words, because the
#  library has no assets directory and a caller should not have to ship files
#  next to their binary. That is fine, but for a long time it was ALL there was:
#  the words were committed with no source, so nobody could read what the GPU ran
#  or change it. This recovers the loop -- edit the GLSL, run this, commit both.
#
#  The word arrays this writes are the exact output of glslangValidator, so a run
#  with no shader edit leaves the file untouched.
#
#  Requires glslangValidator (Debian/Ubuntu: glslang-tools).
set -eu

root="$(dirname "$0")/.."
body="$root/src/guikit-vulkan.adb"

if ! command -v glslangValidator >/dev/null 2>&1; then
    echo "compile_shaders: glslangValidator not found (install glslang-tools)" >&2
    exit 1
fi

for stage in vert frag; do
    glslangValidator -V "$root/shaders/guikit.$stage" -o "/tmp/guikit.$stage.spv"
done

python3 - "$body" /tmp/guikit.vert.spv /tmp/guikit.frag.spv <<'PYTHON'
import struct, sys, textwrap

body, vert, frag = sys.argv[1], sys.argv[2], sys.argv[3]
source = open(body).read()

def words(path):
    data = open(path, "rb").read()
    return [w for (w,) in struct.iter_unpack("<I", data)]

def render(name, path):
    text = ", ".join(str(w) for w in words(path))
    lines = textwrap.wrap(text, width = 72)
    return (f"   {name} : aliased constant Shader_Code_Array :=\n"
            + "     [" + "\n      ".join(lines) + "];")

for name, path in (("Vertex_Shader_Code", vert), ("Fragment_Shader_Code", frag)):
    start = source.index(f"   {name} : aliased constant Shader_Code_Array :=")
    end = source.index("];", start) + len("];")
    source = source[:start] + render(name, path) + source[end:]

open(body, "w").write(source)
print(f"compile_shaders: {body} updated")
PYTHON

echo "compile_shaders: completed"
