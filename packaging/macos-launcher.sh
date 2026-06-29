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

# ── Guile (from official LilyPond bundle) ─────────────────────────────────────
GUILE_VER="3.0"
export GUILE_LOAD_PATH="${LILY_DIR}/share/guile/${GUILE_VER}"
export GUILE_LOAD_COMPILED_PATH="${LILY_DIR}/lib/guile/${GUILE_VER}/ccache"
export GUILE_SYSTEM_EXTENSIONS_PATH="${LILY_DIR}/lib/guile/${GUILE_VER}/extensions"

# ── LilyPond (official self-relocating bundle) ────────────────────────────────
LILY_DIR="${RESOURCES}/lilypond"
export GUILE_SYSTEM_EXTENSIONS_PATH="${RESOURCES}/lib/guile/${GUILE_VER}/extensions"

# ── Evince Backend ────────────────────────────────────────────────────────────
BUNDLE="$(cd "$(dirname "$0")/../.."; pwd)"
export EV_BACKENDS_DIR="$BUNDLE/Contents/lib/evince/4/backends"
# we may or not need to add this export EVINCE_LIB="$BUNDLE/Contents/lib"
#exec "$BUNDLE/Contents/MacOS/denemo-bin" "$@"
# ── Denemo ────────────────────────────────────────────────────────────────────
export DENEMO_DATA_DIR="${RESOURCES}/share"

# ── PATH - MacOS dir first so lilypond and gs are found before system copies ──
export PATH="${BUNDLE}/Contents/MacOS:${PATH}"
export G_MESSAGES_DEBUG=all
exec "${BUNDLE}/Contents/MacOS/denemo-bin" "$@" 2>&1

