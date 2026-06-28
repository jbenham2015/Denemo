#!/bin/bash
# packaging/bundle-macos.sh
# Creates a self-contained Denemo.app bundle and DMG for macOS.
# Run after `make install` with HOMEBREW_PREFIX set (default: /opt/homebrew).
#
# Usage:
#   ./packaging/bundle-macos.sh [--prefix /opt/homebrew] [--version 2.6]
#
# Requirements (all available via Homebrew):
#   brew install dylibbundler create-dmg

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────

HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/opt/homebrew}"
DENEMO_VERSION="${DENEMO_VERSION:-$(grep AC_INIT configure.ac | grep -oE '[0-9]+.[0-9]+(.[0-9]+)?' | head -1)}"
DENEMO_VERSION="${DENEMO_VERSION:-unknown}"
BINARY="${HOMEBREW_PREFIX}/bin/denemo"
SHARE_DIR="${HOMEBREW_PREFIX}/share/denemo"
LOCALE_DIR="${HOMEBREW_PREFIX}/share/locale"
APP_NAME="Denemo"
APP_BUNDLE="${APP_NAME}.app"
STAGING_DIR="$(pwd)/macos_staging"
APP_DIR="${STAGING_DIR}/${APP_BUNDLE}"
RESOURCES="${APP_DIR}/Contents/Resources"
LILY_VERSION="2.26.0"
LILY_BASE="https://gitlab.com/api/v4/projects/lilypond%2Flilypond/packages/generic/lilypond/${LILY_VERSION}"
LILY_DIR="${RESOURCES}/lilypond"
DMG_NAME="Denemo-${DENEMO_VERSION}-macOS.dmg"
SCRIPT_DIR="$(cd "$(dirname "$0")"; pwd)"

# ── Sanity checks ─────────────────────────────────────────────────────────────

if [ ! -f "${BINARY}" ]; then
    echo "ERROR: denemo binary not found at ${BINARY}" >&2
    echo "  Run 'make install' first." >&2
    exit 1
fi

for tool in dylibbundler create-dmg; do
    if ! command -v "$tool" > /dev/null 2>&1; then
        echo "ERROR: '$tool' not found." >&2
        echo "  brew install dylibbundler create-dmg" >&2
        exit 1
    fi
done

echo "Bundling Denemo ${DENEMO_VERSION}..."
echo "  Binary:  ${BINARY}"
echo "  Data:    ${SHARE_DIR}"
echo "  Output:  ${APP_DIR}"

# ── 1. Create .app skeleton ───────────────────────────────────────────────────

rm -rf "${STAGING_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"
mkdir -p "${APP_DIR}/Contents/libs"

# ── 2. Copy Info.plist ────────────────────────────────────────────────────────

cat > "${APP_DIR}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>Denemo</string>
  <key>CFBundleExecutable</key>
  <string>denemo</string>
  <key>CFBundleIconFile</key>
  <string>denemo.icns</string>
  <key>CFBundleIdentifier</key>
  <string>org.gnu.denemo</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Denemo</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${DENEMO_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${DENEMO_VERSION}</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeExtensions</key>
      <array>
        <string>denemo</string>
      </array>
      <key>CFBundleTypeName</key>
      <string>Denemo Score</string>
      <key>CFBundleTypeRole</key>
      <string>Editor</string>
    </dict>
  </array>
  <key>LSMinimumSystemVersion</key>
  <string>12.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2024 Denemo contributors. Licensed under the GNU GPL.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF
# ── 3. Copy binary ────────────────────────────────────────────────────────────
cp "${BINARY}" "${APP_DIR}/Contents/MacOS/denemo"
chmod +x "${APP_DIR}/Contents/MacOS/denemo"
# ── 4. Create icon ────────────────────────────────────────────────────────────
# Convert the installed PNG to .icns using macOS sips + iconutil.
# Falls back gracefully if the PNG is missing.
# Source icon from the checked-out repo
SRCDIR="$(cd "$(dirname "$0")/.." && pwd)"
PNG_ICON="${SRCDIR}/pixmaps/org.denemo.Denemo.png"

if [ ! -f "${PNG_ICON}" ]; then
    PNG_ICON="${SRCDIR}/pixmaps/denemo128x128.png"
fi

ICNS_OUT="${APP_DIR}/Contents/Resources/denemo.icns"
if [ -f "${PNG_ICON}" ]; then
    echo "Creating .icns from ${PNG_ICON}..."
    ICONSET_DIR="$(mktemp -d)/denemo.iconset"
    mkdir -p "${ICONSET_DIR}"
    for size in 16 32 64 128; do
        sips -z ${size} ${size} "${PNG_ICON}" \
            --out "${ICONSET_DIR}/icon_${size}x${size}.png" > /dev/null
        double=$((size * 2))
        sips -z ${double} ${double} "${PNG_ICON}" \
            --out "${ICONSET_DIR}/icon_${size}x${size}@2x.png" > /dev/null
    done
    # 128 is our max source size - don't upscale beyond that
    iconutil -c icns "${ICONSET_DIR}" -o "${ICNS_OUT}"
    rm -rf "$(dirname ${ICONSET_DIR})"
else
    echo "WARNING: No icon found, bundle will have no icon"
fi


# ── 5. Copy application data into Resources ───────────────────────────────────

echo "Copying application data..."
cp -R "${SHARE_DIR}" "${APP_DIR}/Contents/Resources/share"

# Copy locale files for installed languages
if [ -d "${LOCALE_DIR}" ]; then
    mkdir -p "${APP_DIR}/Contents/Resources/share/locale"
    # Only copy denemo translations, not all of Homebrew's locale
    find "${LOCALE_DIR}" -name "denemo.mo" | while read mo; do
        lang=$(echo "$mo" | sed "s|${LOCALE_DIR}/||" | cut -d/ -f1)
        mkdir -p "${APP_DIR}/Contents/Resources/share/locale/${lang}/LC_MESSAGES"
        cp "$mo" "${APP_DIR}/Contents/Resources/share/locale/${lang}/LC_MESSAGES/"
    done
fi
# -- 5b. Bundle LilyPond
# ── Bundle official LilyPond release (includes gs in libexec/) ───────────────
# Download and extract ARM64 build
ARM_TARBALL="lilypond-${LILY_VERSION}-darwin-arm64.tar.gz"
echo "  Downloading ${ARM_TARBALL}..."
if ! curl -fL "${LILY_BASE}/${ARM_TARBALL}" -o "/tmp/${ARM_TARBALL}"; then
    echo "ERROR: Failed to download ARM64 LilyPond" >&2
    exit 1
fi

# Extract and inspect contents
echo "  Extracting ${ARM_TARBALL}..."
mkdir -p /tmp/lily-arm64 && tar -xz -f "/tmp/${ARM_TARBALL}" -C /tmp/lily-arm64 --strip-components=1

# List what was actually extracted for debugging
echo "  Archive contents:"
ls -la /tmp/ | grep lilypond

# Find the actual extracted directory (might have a different prefix)
if [ -z "${ARM_DIR}" ]; then
    echo "ERROR: Could not find extracted ARM64 LilyPond directory" >&2
    tar -tzf "/tmp/${ARM_TARBALL}" | head -20
    exit 1
fi

# Verify the share directory exists in the found location
if [ ! -d "${ARM_DIR}/share" ]; then
    echo "ERROR: share directory not found in ${ARM_DIR}" >&2
    echo "  Actual contents of ${ARM_DIR}:"
    ls -la "${ARM_DIR}/" 2>/dev/null || echo "  Directory not readable"
    exit 1
fi

rm "/tmp/${ARM_TARBALL}"

# Download and extract x86_64 build (same validation)
X86_TARBALL="lilypond-${LILY_VERSION}-darwin-x86_64.tar.gz"
echo "  Downloading ${X86_TARBALL}..."
if ! curl -fL "${LILY_BASE}/${X86_TARBALL}" -o "/tmp/${X86_TARBALL}"; then
    echo "ERROR: Failed to download x86_64 LilyPond" >&2
    exit 1
fi

echo "  Extracting ${X86_TARBALL}..."
mkdir -p /tmp/lily-x86_64 && tar -xz -f "/tmp/${X86_TARBALL}" -C /tmp/lily-x86_64 --strip-components=1

if [ -z "${X86_DIR}" ]; then
    echo "ERROR: Could not find extracted x86_64 LilyPond directory" >&2
    exit 1
fi

if [ ! -d "${X86_DIR}/share" ]; then
    echo "ERROR: share directory not found in ${X86_DIR}" >&2
    echo "  Actual contents of ${X86_DIR}:"
    ls -la "${X86_DIR}/" 2>/dev/null || echo "  Directory not readable"
    exit 1
fi

rm "/tmp/${X86_TARBALL}"

ARM_DIR="/tmp/lily-arm64"
X86_DIR="/tmp/lily-x86_64"

# Verify directories exist
if [ ! -d "${ARM_DIR}/share" ]; then
    echo "ERROR: ARM64 LilyPond share directory not found at ${ARM_DIR}/share" >&2
    echo "  Download may have failed or archive structure changed" >&2
    exit 1
fi

if [ ! -d "${X86_DIR}/share" ]; then
    echo "ERROR: x86_64 LilyPond share directory not found at ${X86_DIR}/share" >&2
    echo "  Download may have failed or archive structure changed" >&2
    exit 1
fi

# Copy the data tree from arm64 (identical between architectures)
cp -R "${ARM_DIR}/share"   "${LILY_DIR}/share"
cp -R "${ARM_DIR}/lib"     "${LILY_DIR}/lib"
cp -R "${ARM_DIR}/etc"     "${LILY_DIR}/etc"
cp -R "${ARM_DIR}/libexec" "${LILY_DIR}/libexec"
mkdir -p "${LILY_DIR}/bin"

# Make universal binaries for everything in bin/ and libexec/
for dir in bin libexec; do
    for arm_bin in "${ARM_DIR}/${dir}/"*; do
        name=$(basename "${arm_bin}")
        x86_bin="${X86_DIR}/${dir}/${name}"
        dest="${LILY_DIR}/${dir}/${name}"
        if [ -f "${x86_bin}" ]; then
            file "${arm_bin}" | grep -q "Mach-O" || { cp "${arm_bin}" "${dest}"; continue; }
            lipo -create "${arm_bin}" "${x86_bin}" -output "${dest}"
            codesign --force --sign - "${dest}"
            echo "  universal: ${dir}/${name}"
        else
            cp "${arm_bin}" "${dest}"
            chmod +x "${dest}"
        fi
    done
done

echo "LilyPond ${LILY_VERSION} bundled."


# Detect installed Guile version (handles 3.0, future 3.2, etc.)
GUILE_VER=$(ls "${HOMEBREW_PREFIX}/share/guile/" | grep -E '^[0-9]+\.[0-9]+$' | sort -V | tail -1)
echo "=== Bundling Guile ${GUILE_VER} ==="

# 1. Scheme source tree (ice-9/, srfi/, system/, …)
mkdir -p "${RESOURCES}/share/guile/${GUILE_VER}"
cp -R "${HOMEBREW_PREFIX}/share/guile/${GUILE_VER}/" \
      "${RESOURCES}/share/guile/${GUILE_VER}/"

# 2. Site directory (may be empty but must exist)
mkdir -p "${RESOURCES}/share/guile/site/${GUILE_VER}"
if [ -d "${HOMEBREW_PREFIX}/share/guile/site/${GUILE_VER}" ]; then
  cp -R "${HOMEBREW_PREFIX}/share/guile/site/${GUILE_VER}/" \
        "${RESOURCES}/share/guile/site/${GUILE_VER}/"
fi

# 3. Pre-compiled .go cache (speeds startup)
mkdir -p "${RESOURCES}/lib/guile/${GUILE_VER}/ccache"
if [ -d "${HOMEBREW_PREFIX}/lib/guile/${GUILE_VER}/ccache" ]; then
  cp -R "${HOMEBREW_PREFIX}/lib/guile/${GUILE_VER}/ccache/" \
        "${RESOURCES}/lib/guile/${GUILE_VER}/ccache/"
fi

# 4. Site compiled cache (usually empty; must exist for the env var to be valid)
mkdir -p "${RESOURCES}/lib/guile/${GUILE_VER}/site-ccache"
if [ -d "${HOMEBREW_PREFIX}/lib/guile/${GUILE_VER}/site-ccache" ]; then
  cp -R "${HOMEBREW_PREFIX}/lib/guile/${GUILE_VER}/site-ccache/" \
        "${RESOURCES}/lib/guile/${GUILE_VER}/site-ccache/"
fi

# 5. Extensions (.so plugins Guile loads at runtime)
mkdir -p "${RESOURCES}/lib/guile/${GUILE_VER}/extensions"
if [ -d "${HOMEBREW_PREFIX}/lib/guile/${GUILE_VER}/extensions" ]; then
  cp -R "${HOMEBREW_PREFIX}/lib/guile/${GUILE_VER}/extensions/" \
        "${RESOURCES}/lib/guile/${GUILE_VER}/extensions/"
fi

echo "=== Guile bundle contents ==="
du -sh "${RESOURCES}/share/guile/" 2>/dev/null
du -sh "${RESOURCES}/lib/guile/"   2>/dev/null

# ── Install Denemo launcher ─────────────────────────────────────────────────────────
mv "${APP_DIR}/Contents/MacOS/denemo" \
   "${APP_DIR}/Contents/MacOS/denemo-bin"
cp "${SCRIPT_DIR}/macos-launcher.sh" "${APP_DIR}/Contents/MacOS/denemo"
chmod +x "${APP_DIR}/Contents/MacOS/denemo"
# ── 7. Bundle dylibs ──────────────────────────────────────────────────────────
# dylibbundler copies all non-system Homebrew dylibs into Contents/libs/
# and rewrites the binary's load paths to @executable_path/../libs/

echo "Bundling dylibs..."
dylibbundler \
    --bundle-deps \
    --create-dir \
    --dest-dir "${APP_DIR}/Contents/libs/" \
    --fix-file "${APP_DIR}/Contents/MacOS/denemo-bin" \
    --install-path "@executable_path/../libs/" \
    --overwrite-dir \
    --search-path "${HOMEBREW_PREFIX}/lib" \
    --search-path "/usr/local/lib" \
    --search-path "${HOMEBREW_PREFIX}/opt/guile/lib" \
    --search-path "${HOMEBREW_PREFIX}/opt/gtk+3/lib" \
    --search-path "${HOMEBREW_PREFIX}/opt/glib/lib" \
    --search-path "${HOMEBREW_PREFIX}/opt/pango/lib" \
    --search-path "${HOMEBREW_PREFIX}/opt/cairo/lib" \
    --search-path "${HOMEBREW_PREFIX}/opt/evince/lib" \
    || true

# ============================================================
# Bundle Evince Backends (Universal Binary)
# ============================================================
BACKENDS_DIR="${APP_DIR}/Contents/lib/evince/4/backends"
LIBS_DIR="${APP_DIR}/Contents/libs"
INTEL="/usr/local/Cellar/evince/48.4/lib/evince/4/backends"
ARM="/opt/homebrew/Cellar/evince/48.4/lib/evince/4/backends"

mkdir -p "${BACKENDS_DIR}"

# --- Step 1: lipo all backends into universal binaries ---
for BACKEND in comicsdocument djvudocument pdfdocument psdocument tiffdocument xpsdocument; do
    lipo -create \
        "${INTEL}/lib${BACKEND}.so" \
        "${ARM}/lib${BACKEND}.so" \
        -output "${BACKENDS_DIR}/lib${BACKEND}.so"
    chmod 644 "${BACKENDS_DIR}/lib${BACKEND}.so"
done

# Copy descriptor files (plain text, arch-independent)
cp "${INTEL}/"*.evince-backend "${BACKENDS_DIR}/"
chmod 644 "${BACKENDS_DIR}/"*.evince-backend

# --- Step 2: Rewrite hardcoded Cellar paths in each .so ---
# Convention: @loader_path/../../libs/ points to Contents/libs/
#             @loader_path/../../lib/libevdocument3.4.dylib for evince's own lib

RPATH="@loader_path/../../libs"
EVINCE_LIB="@loader_path/../../libs/libevdocument3.4.dylib"

rewrite() {
    local SO="$1"
    local OLD_X86="$2"
    local OLD_ARM="$3"
    local NEW="$4"
    install_name_tool -change "${OLD_X86}" "${NEW}" "${SO}" 2>/dev/null || true
    install_name_tool -change "${OLD_ARM}" "${NEW}" "${SO}" 2>/dev/null || true
}

for SO in "${BACKENDS_DIR}/"*.so; do
    echo "Rewriting: $(basename ${SO})"

    # evince's own library
    rewrite "$SO" \
        "/usr/local/Cellar/evince/48.4/lib/libevdocument3.4.dylib" \
        "/opt/homebrew/Cellar/evince/48.4/lib/libevdocument3.4.dylib" \
        "${EVINCE_LIB}"

    # Common deps (already in your bundle)
    rewrite "$SO" "/usr/local/opt/cairo/lib/libcairo.2.dylib"               "/opt/homebrew/opt/cairo/lib/libcairo.2.dylib"               "${RPATH}/libcairo.2.dylib"
    rewrite "$SO" "/usr/local/opt/gdk-pixbuf/lib/libgdk_pixbuf-2.0.0.dylib" "/opt/homebrew/opt/gdk-pixbuf/lib/libgdk_pixbuf-2.0.0.dylib" "${RPATH}/libgdk_pixbuf-2.0.0.dylib"
    rewrite "$SO" "/usr/local/opt/glib/lib/libgobject-2.0.0.dylib"          "/opt/homebrew/opt/glib/lib/libgobject-2.0.0.dylib"          "${RPATH}/libgobject-2.0.0.dylib"
    rewrite "$SO" "/usr/local/opt/glib/lib/libglib-2.0.0.dylib"             "/opt/homebrew/opt/glib/lib/libglib-2.0.0.dylib"             "${RPATH}/libglib-2.0.0.dylib"
    rewrite "$SO" "/usr/local/opt/glib/lib/libgio-2.0.0.dylib"              "/opt/homebrew/opt/glib/lib/libgio-2.0.0.dylib"              "${RPATH}/libgio-2.0.0.dylib"
    rewrite "$SO" "/usr/local/opt/gettext/lib/libintl.8.dylib"              "/opt/homebrew/opt/gettext/lib/libintl.8.dylib"              "${RPATH}/libintl.8.dylib"
    rewrite "$SO" "/usr/local/opt/gtk+3/lib/libgtk-3.0.dylib"               "/opt/homebrew/opt/gtk+3/lib/libgtk-3.0.dylib"               "${RPATH}/libgtk-3.0.dylib"
    rewrite "$SO" "/usr/local/opt/pango/lib/libpango-1.0.0.dylib"           "/opt/homebrew/opt/pango/lib/libpango-1.0.0.dylib"           "${RPATH}/libpango-1.0.0.dylib"

    # Backend-specific deps — bundle these too if not already present
    rewrite "$SO" "/usr/local/opt/poppler/lib/libpoppler-glib.8.dylib"      "/opt/homebrew/opt/poppler/lib/libpoppler-glib.8.dylib"      "${RPATH}/libpoppler-glib.8.dylib"
    rewrite "$SO" "/usr/local/opt/djvulibre/lib/libdjvulibre.21.dylib"      "/opt/homebrew/opt/djvulibre/lib/libdjvulibre.21.dylib"      "${RPATH}/libdjvulibre.21.dylib"
    rewrite "$SO" "/usr/local/opt/libarchive/lib/libarchive.13.dylib"       "/opt/homebrew/opt/libarchive/lib/libarchive.13.dylib"       "${RPATH}/libarchive.13.dylib"
    rewrite "$SO" "/usr/local/opt/libtiff/lib/libtiff.6.dylib"              "/opt/homebrew/opt/libtiff/lib/libtiff.6.dylib"              "${RPATH}/libtiff.6.dylib"
    rewrite "$SO" "/usr/local/opt/libspectre/lib/libspectre.1.dylib"        "/opt/homebrew/opt/libspectre/lib/libspectre.1.dylib"        "${RPATH}/libspectre.1.dylib"
    rewrite "$SO" "/usr/local/opt/libgxps/lib/libgxps.2.dylib"              "/opt/homebrew/opt/libgxps/lib/libgxps.2.dylib"              "${RPATH}/libgxps.2.dylib"

    codesign --force --sign - "${SO}"
done

# --- Step 3: Bundle the backend-specific libs if not already present ---
# TODO These are NOT common GTK deps — check if your existing bundle script handles them.
for LIB in \
    "poppler/lib/libpoppler-glib.8.dylib" \
    "djvulibre/lib/libdjvulibre.21.dylib" \
    "libarchive/lib/libarchive.13.dylib" \
    "libtiff/lib/libtiff.6.dylib" \
    "libspectre/lib/libspectre.1.dylib" \
    "libgxps/lib/libgxps.2.dylib"
do
    LIBNAME=$(basename "$LIB")
    if [ ! -f "${LIBS_DIR}/${LIBNAME}" ]; then
        echo "Bundling missing lib: ${LIBNAME}"
        lipo -create \
            "/usr/local/opt/${LIB}" \
            "/opt/homebrew/opt/${LIB}" \
            -output "${LIBS_DIR}/${LIBNAME}"
        codesign --force --sign - "${LIBS_DIR}/${LIBNAME}"
    else
        echo "Already bundled: ${LIBNAME}"
    fi
done
# ── 8. Bundle GDK pixbuf loaders ─────────────────────────────────────────────
# GTK needs pixbuf loaders to render images; copy and update the cache.

GDK_PIXBUF_DIR="${HOMEBREW_PREFIX}/lib/gdk-pixbuf-2.0"
if [ -d "${GDK_PIXBUF_DIR}" ]; then
    echo "Copying GDK pixbuf loaders..."
    mkdir -p "${APP_DIR}/Contents/Resources/lib"
    cp -R "${GDK_PIXBUF_DIR}" "${APP_DIR}/Contents/Resources/lib/"
fi

# ── 9. Bundle GLib schemas ────────────────────────────────────────────────────

SCHEMAS_DIR="${HOMEBREW_PREFIX}/share/glib-2.0/schemas"
if [ -d "${SCHEMAS_DIR}" ]; then
    echo "Copying GLib schemas..."
    mkdir -p "${APP_DIR}/Contents/Resources/share/glib-2.0"
    cp -R "${SCHEMAS_DIR}" "${APP_DIR}/Contents/Resources/share/glib-2.0/"
fi

# ── 10. Bundle Fonts ──────────────────────────────────────────────────────────
# Bundle fontconfig
if [ -d "${HOMEBREW_PREFIX}/etc/fonts" ]; then
    mkdir -p "${APP_DIR}/Contents/Resources/etc/fonts"
    cp -R "${HOMEBREW_PREFIX}/etc/fonts/" \
          "${APP_DIR}/Contents/Resources/etc/fonts/"
    echo "  Fontconfig bundled"
fi

# Bundle fonts
if [ -d "${HOMEBREW_PREFIX}/share/fonts" ]; then
    mkdir -p "${APP_DIR}/Contents/Resources/share/fonts"
    cp -R "${HOMEBREW_PREFIX}/share/fonts/" \
          "${APP_DIR}/Contents/Resources/share/fonts/"
    echo "  Fonts bundled"
fi
# Bundle hicolor icon theme
if [ -d "${HOMEBREW_PREFIX}/share/icons/hicolor" ]; then
    mkdir -p "${APP_DIR}/Contents/Resources/share/icons/hicolor"
    cp -R "${HOMEBREW_PREFIX}/share/icons/hicolor/" \
          "${APP_DIR}/Contents/Resources/share/icons/hicolor/"
fi

# Bundle Adwaita theme (provides check-symbolic.svg and other assets)
if [ -d "${HOMEBREW_PREFIX}/share/icons/Adwaita" ]; then
    mkdir -p "${APP_DIR}/Contents/Resources/share/icons/Adwaita"
    cp -R "${HOMEBREW_PREFIX}/share/icons/Adwaita/" \
          "${APP_DIR}/Contents/Resources/share/icons/Adwaita/"
fi

# Bundle GDK pixbuf loaders
GDK_PIXBUF_DIR="${HOMEBREW_PREFIX}/lib/gdk-pixbuf-2.0"
if [ -d "${GDK_PIXBUF_DIR}" ]; then
    mkdir -p "${APP_DIR}/Contents/Resources/lib/gdk-pixbuf-2.0"
    cp -R "${GDK_PIXBUF_DIR}/" \
          "${APP_DIR}/Contents/Resources/lib/gdk-pixbuf-2.0/"
    # Update the loaders.cache paths to point inside the bundle
    GDK_PIXBUF_CACHE="${APP_DIR}/Contents/Resources/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"
    if [ -f "${GDK_PIXBUF_CACHE}" ]; then
        sed -i '' "s|${HOMEBREW_PREFIX}/lib/gdk-pixbuf-2.0|@executable_path/../Resources/lib/gdk-pixbuf-2.0|g" \
            "${GDK_PIXBUF_CACHE}"
    fi
fi

# Bundle Pango
if [ -d "${HOMEBREW_PREFIX}/lib/pango" ]; then
    mkdir -p "${APP_DIR}/Contents/libs/pango"
    cp -R "${HOMEBREW_PREFIX}/lib/pango/" \
          "${APP_DIR}/Contents/libs/pango/"
fi

# Bundle fontconfig
mkdir -p "${APP_DIR}/Contents/Resources/etc/fonts"
if [ -d "${HOMEBREW_PREFIX}/etc/fonts" ]; then
    cp -R "${HOMEBREW_PREFIX}/etc/fonts/" \
          "${APP_DIR}/Contents/Resources/etc/fonts/"
fi
# Add system font fallback to fontconfig
cp "${SRCDIR}/packaging/macos-fonts.conf" "${APP_DIR}/Contents/Resources/etc/fonts/fonts.conf"

# Bundle Denemo's own fonts (denemo.ttf etc)
if [ -d "${HOMEBREW_PREFIX}/share/fonts" ]; then
    mkdir -p "${APP_DIR}/Contents/Resources/share/fonts"
    cp -R "${HOMEBREW_PREFIX}/share/fonts/" \
          "${APP_DIR}/Contents/Resources/share/fonts/"
fi


# ── 11. Create DMG ────────────────────────────────────────────────────────────

echo "Creating DMG: ${DMG_NAME}..."
rm -f "${DMG_NAME}"

create-dmg \
    --volname "Denemo ${DENEMO_VERSION}" \
    --volicon "${ICNS_OUT}" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "${APP_BUNDLE}" 150 185 \
    --hide-extension "${APP_BUNDLE}" \
    --app-drop-link 450 185 \
    "${DMG_NAME}" \
    "${STAGING_DIR}/" \
    2>&1 | tail -5 || {
        # create-dmg may exit non-zero on first run due to DS_Store; that's ok
        echo "  (create-dmg warning ignored)"
    }

echo ""
echo "Done: ${DMG_NAME}"
echo "  App bundle: ${APP_DIR}"
