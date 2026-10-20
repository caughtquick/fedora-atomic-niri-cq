#!/usr/bin/env bash
set -euo pipefail

# AGS v3 is the current release line and uses Gnim instead of the old Astal GJS
# runtime. Astal itself has no versioned releases, so pin the latest main commit
# to keep the image reproducible while still using the current API.
# Note: upstream's cli/version file still says 3.1.0 for the v3.1.2 tag, so
# `ags --version` reports 3.1.0 even though the v3.1.2 sources are installed.
readonly AGS_VERSION="v3.1.2"
readonly ASTAL_COMMIT="cbcd9f49dd6b9638dc5623b56cc6e1e0a60b593e"
readonly APPMENU_VERSION="25.04"
readonly CAVA_VERSION="1.0.0"

readonly BUILD_DIR="/tmp/ags-build"
readonly ASTAL_DIR="${BUILD_DIR}/astal"
readonly AGS_DIR="${BUILD_DIR}/ags"

if [[ -d "${BUILD_DIR}" ]]; then
    chmod -R u+w "${BUILD_DIR}"
    rm -rf "${BUILD_DIR}"
fi
mkdir -p "${BUILD_DIR}"

build_meson() {
    local source_dir="$1"
    local build_dir="$2"
    shift 2

    meson setup --prefix=/usr --buildtype=release "$@" "${build_dir}" "${source_dir}"
    meson install -C "${build_dir}"
}

# AstalTray links against appmenu-glib-translator, which Fedora does not package.
git clone --depth=1 --branch "${APPMENU_VERSION}" \
    https://github.com/rilian-la-te/vala-panel-appmenu.git \
    "${BUILD_DIR}/vala-panel-appmenu"
build_meson \
    "${BUILD_DIR}/vala-panel-appmenu/subprojects/appmenu-glib-translator" \
    "${BUILD_DIR}/build-appmenu"

# AstalCava needs the shared-library fork of cava; Fedora only packages the CLI.
git clone --depth=1 --branch "${CAVA_VERSION}" \
    https://github.com/LukashonakV/cava.git \
    "${BUILD_DIR}/cava"
build_meson "${BUILD_DIR}/cava" "${BUILD_DIR}/build-cava" \
    -Dbuild_target=lib \
    -Dcava_font=false \
    -Dinput_pulse=enabled \
    -Dinput_pipewire=enabled \
    -Dinput_alsa=disabled \
    -Dinput_jack=disabled \
    -Dinput_oss=disabled \
    -Dinput_portaudio=disabled \
    -Dinput_sndio=disabled \
    -Doutput_ncurses=disabled \
    -Doutput_sdl=disabled \
    -Doutput_sdl_glsl=disabled

# Astal itself. Fetch the exact commit instead of a full clone.
git init -q "${ASTAL_DIR}"
git -C "${ASTAL_DIR}" remote add origin https://github.com/Aylur/astal.git
git -C "${ASTAL_DIR}" fetch -q --depth=1 origin "${ASTAL_COMMIT}"
git -C "${ASTAL_DIR}" checkout -q --detach FETCH_HEAD

# Core libraries first, then everything that builds on top of them.
for component in lib/astal/io lib/astal/gtk3 lib/astal/gtk4; do
    name="$(basename "${component}")"
    build_meson "${ASTAL_DIR}/${component}" "${BUILD_DIR}/build-astal-${name}"
done

# Wayland helpers used by AstalIdleNotify, AstalRiver and AstalWorkspace.
build_meson "${ASTAL_DIR}/lib/wl/wl" "${BUILD_DIR}/build-astal-wl"
build_meson "${ASTAL_DIR}/lib/wl/wl4" "${BUILD_DIR}/build-astal-wl4"

# Command-line frontends for the Astal libraries.
build_meson "${ASTAL_DIR}/lib/quarrel" "${BUILD_DIR}/build-astal-quarrel"

for component in \
    apps auth battery bluetooth brightness cava greet hyprland idle-notify \
    mpris network notifd powerprofiles river tray wireplumber workspace; do
    build_meson "${ASTAL_DIR}/lib/${component}" "${BUILD_DIR}/build-astal-${component}"
done

# TypeScript/JavaScript bindings for plain GJS consumers of Astal.
build_meson "${ASTAL_DIR}/lang/gjs" "${BUILD_DIR}/build-astal-gjs"

# AGS v3. npm supplies its bundled Gnim dependency, and Meson installs the CLI
# plus the TypeScript library into /usr/share/ags/js.
git clone --depth=1 --branch "${AGS_VERSION}" \
    https://github.com/Aylur/ags.git "${AGS_DIR}"

export CGO_ENABLED=0
export GOFLAGS="-modcacherw"
export GOPATH="${BUILD_DIR}/go"
export GOCACHE="${BUILD_DIR}/go-cache"
export GOMODCACHE="${BUILD_DIR}/go-mod-cache"

(
    cd "${AGS_DIR}"
    npm ci --omit=dev --no-audit --no-fund --cache "${BUILD_DIR}/npm-cache"
    meson setup --prefix=/usr --buildtype=release "${BUILD_DIR}/build-ags" .
    meson install -C "${BUILD_DIR}/build-ags"
)

# The toolchain, module caches and source trees are build-time only.
rm -rf "${BUILD_DIR}"

test -d /usr/share/ags/js/node_modules/gnim
ags --version
