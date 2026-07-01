#!/bin/bash
# Resolve the bundle path robustly even if cwd doesn't exist
SCRIPT="$0"
# Resolve symlinks
while [ -L "$SCRIPT" ]; do
    SCRIPT="$(readlink "$SCRIPT")"
done
BUNDLE="$(cd "$(dirname "$SCRIPT")/../.." 2>/dev/null && pwd)"
if [ -z "$BUNDLE" ]; then
    # Fallback: derive from script path directly
    BUNDLE="${0%/Contents/MacOS/*}"
fi
RESOURCES="${BUNDLE}/Contents/Resources"
LIBS="${BUNDLE}/Contents/libs"
# ── Dylibs ────────────────────────────────────────────────────────────────────
export DYLD_LIBRARY_PATH="${LIBS}:${DYLD_LIBRARY_PATH:-}"

# ── GTK / GDK ─────────────────────────────────────────────────────────────────
export XDG_DATA_DIRS="${RESOURCES}/share:/usr/local/share:/usr/share"
export GSETTINGS_SCHEMA_DIR="${RESOURCES}/share/glib-2.0/schemas:${GSETTINGS_SCHEMA_DIR:-}"
export GDK_PIXBUF_MODULE_FILE="${RESOURCES}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"
export GTK_PATH="${RESOURCES}/lib/gtk-3.0"
export PANGO_LIBDIR="${LIBS}"

# ── Fontconfig ────────────────────────────────────────────────────────────────
export FONTCONFIG_FILE="${RESOURCES}/etc/fonts/fonts.conf"
#only enable when explicitly requested
if [ "${DENEMO_DEBUG:-0}" = "1" ]; then
	export FC_DEBUG=4
fi

# ── LilyPond (official self-relocating bundle) ────────────────────────────────
LILY_DIR="${RESOURCES}/lilypond"
export PATH="${LILY_DIR}/bin:${LILY_DIR}/libexec:${BUNDLE}/Contents/MacOS:${PATH}"

# ── Guile (from bundled LilyPond, shared with Denemo) ─────────────────────────
GUILE_VER="3.0"
export GUILE_LOAD_PATH="${RESOURCES}/share/guile/3.0"
export GUILE_LOAD_COMPILED_PATH="${RESOURCES}/lib/guile/3.0/ccache"
export GUILE_SYSTEM_EXTENSIONS_PATH="${RESOURCES}/lib/guile/3.0/extensions"
# ── Evince Backend ────────────────────────────────────────────────────────────
export EV_BACKENDS_DIR="${BUNDLE}/Contents/lib/evince/4/backends"

# ── Denemo ────────────────────────────────────────────────────────────────────
export DENEMO_DATA_DIR="${RESOURCES}/share"

exec "${BUNDLE}/Contents/MacOS/denemo-bin" "$@" 2>&1
