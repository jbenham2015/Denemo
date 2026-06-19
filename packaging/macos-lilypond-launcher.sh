#!/bin/bash
SCRIPT="$0"
while [ -L "$SCRIPT" ]; do SCRIPT="$(readlink "$SCRIPT")"; done
BUNDLE="$(cd "$(dirname "$SCRIPT")/../.." && pwd)"
RESOURCES="${BUNDLE}/Contents/Resources"
LIBS="${BUNDLE}/Contents/libs"

GUILE_VER="3.0"
LILY_VER=$(ls "${RESOURCES}/share/lilypond/" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+' | sort -V | tail -1)
LILY_VER="${LILY_VER:-2.26.0}"

export DYLD_LIBRARY_PATH="${LIBS}:${DYLD_LIBRARY_PATH:-}"
export GUILE_LOAD_PATH="${RESOURCES}/share/guile/${GUILE_VER}:${RESOURCES}/share/guile/site/${GUILE_VER}:${RESOURCES}/share/lilypond/${LILY_VER}/scm"
export GUILE_LOAD_COMPILED_PATH="${RESOURCES}/lib/guile/${GUILE_VER}/ccache:${RESOURCES}/lib/guile/${GUILE_VER}/site-ccache"
export GUILE_SYSTEM_EXTENSIONS_PATH="${RESOURCES}/lib/guile/${GUILE_VER}/extensions"
export LILYPOND_DATADIR="${RESOURCES}/share/lilypond/${LILY_VER}"
export FONTCONFIG_PATH="${RESOURCES}/etc/fonts"
export FONTCONFIG_FILE="${RESOURCES}/etc/fonts/fonts.conf"

exec "${BUNDLE}/Contents/MacOS/lilypond-bin" "$@"
