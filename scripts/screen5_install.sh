#!/bin/bash -l
# Manpreet 12/07/2026
# Build and install GNU screen 5.0.1 from source on Ubuntu 24.04 into /usr/local
# (alongside the apt 4.9.x), add truecolor/TUI defaults to ~/.screenrc and keep
# claude and codex aliases in ~/.bash_aliases that run both CLIs inside the new
# screen. Codex goes through the kit's host launcher and bubblewrap sandbox.
# Re-running is safe: an already-current build is skipped and the ~/.screenrc
# and ~/.bash_aliases managed blocks are re-applied - run it again after
# oe-deploy's host-setup.sh, which overwrites both files.
# Replaces the older screen_install.sh and cleans up its /etc artifacts.
# No Ubuntu release ships screen 5.x for noble (libc6 too old), hence the build.
# Usage: ./screen5_install.sh [-u | --uninstall]
# Run as your normal user, not root - sudo is called only where needed.

abort() {
    echo >&2 '
****************************
*** ABORTED DUE TO ERROR ***
****************************
'
    date
    echo "An error occurred. Exiting..." >&2
    exit 1
}

trap 'abort' 0
set -e

uninstall=0 # Flag to remove the screen 5 build and restore ~/.screenrc and ~/.bash_aliases

while [[ $# -gt 0 ]]; do
    p="$1"
    case $p in
    -u | --uninstall)
        uninstall=1
        ;;
    *)
        echo "Invalid Parameter ... exiting" && exit 1
        ;;
    esac
    shift # move to next parameter
done

##################################################
### CHECKS (See end of script for execution)    ##
##################################################

echo -e "\nStarting Pre-flight checks ..."
echo "-------------------------------"

echo "Checking we are not running as root..."
[ "${EUID}" == "0" ] && echo "Run as your normal user so ~/.screenrc and ~/.bash_aliases stay yours - sudo is called where needed ... exiting" && exit 1
echo "[OK]"

echo "Checks complete ..."
echo "-------------------------------"

##################################################
### VARIABLES (See end of script for execution) ##
##################################################

version="5.0.1"
kit_root="$(dirname "$(dirname "$(realpath "$0")")")"
tarball="screen-${version}.tar.gz"
url="https://ftp.gnu.org/gnu/screen/${tarball}"
expected_md5="fb5e5dfc9353225c2d6929777344b1a6"
prefix="/usr/local"
screenrc="${HOME}/.screenrc"
bash_aliases="${HOME}/.bash_aliases"
bashrc="${HOME}/.bashrc"
marker_start="# >>> screen5_install.sh managed block >>>"
marker_end="# <<< screen5_install.sh managed block <<<"
source_marker_start="# >>> screen5_install.sh aliases source >>>"
source_marker_end="# <<< screen5_install.sh aliases source <<<"
# the older screen_install.sh wrote these system-wide artifacts
legacy_marker_start="# >>> screen_install.sh managed block >>>"
legacy_marker_end="# <<< screen_install.sh managed block <<<"
legacy_alias_file="/etc/profile.d/claude_screen.sh"
bash_bashrc="/etc/bash.bashrc"
build_deps="build-essential autoconf automake texinfo libncurses-dev libpam0g-dev pkg-config wget"

##################################################
### FUNCTIONS (See end of script for execution) ##
##################################################

# The older screen_install.sh kept the alias in /etc - remove those pieces and
# rename its ~/.screenrc markers so this script now owns that block
cleanLegacyInstall() {
    sudo rm -f "${legacy_alias_file}"
    if [ -f "${bash_bashrc}" ]; then
        sudo sed -i "/^${legacy_marker_start}$/,/^${legacy_marker_end}$/d" "${bash_bashrc}"
    fi
    if [ -f "${screenrc}" ]; then
        sed -i "s/screen_install\.sh managed block/screen5_install.sh managed block/" "${screenrc}"
    fi
}

installBuildDeps() {
    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -qqy -o=Dpkg::Use-Pty=0 ${build_deps}
}

buildAndInstallScreen() {
    local build_dir
    build_dir="$(mktemp -d)"
    cd "${build_dir}"
    wget -q "${url}"

    local actual_md5
    actual_md5="$(md5sum "${tarball}" | awk '{print $1}')"
    [ "${actual_md5}" != "${expected_md5}" ] && echo "Checksum mismatch: expected ${expected_md5} got ${actual_md5} ... exiting" && exit 1

    tar xzf "${tarball}"
    cd "screen-${version}"
    ./configure --quiet --prefix="${prefix}"
    make -s -j"$(nproc)"
    sudo make -s install

    cd /
    rm -rf "${build_dir}"
}

# Add a setting inside the managed block unless the key is already set anywhere
# (so settings deployed by oe-deploy's ~/.screenrc are never overridden)
addSetting() {
    local key="${1}"
    local line="${2}"
    if grep -qE "^[[:space:]]*${key}([[:space:]]|$)" "${screenrc}"; then
        echo "Keeping existing ${key} setting"
    else
        sed -i "/^${marker_end}$/i ${line}" "${screenrc}"
        echo "Added: ${line}"
    fi
}

configureScreenrc() {
    touch "${screenrc}"
    # settings live between markers so --uninstall can remove exactly what we added
    [ -n "$(tail -c1 "${screenrc}")" ] && echo "" >> "${screenrc}"
    grep -qF "${marker_start}" "${screenrc}" || printf '%s\n%s\n' "${marker_start}" "${marker_end}" >> "${screenrc}"

    # truecolor needs screen 5.x - fixes highlights that 4.x mis-parses in TUIs
    addSetting "truecolor" "truecolor on"
    # alternate buffer for full-screen apps keeps redraws out of scrollback
    addSetting "altscreen" "altscreen on"
    # UTF-8 by default so box-drawing characters render
    addSetting "defutf8" "defutf8 on"
    # no defbce - bce makes screen advertise TERM=screen-256color-bce, which
    # breaks ~/.bashrc colour-prompt detection that matches *-256color
    addSetting "term" "term screen-256color"
    addSetting "defscrollback" "defscrollback 10000"
}

# oe-deploy's ~/.screenrc ships an active "termcapinfo xterm* ti@:te@" which
# defeats the alternate buffer and smears TUI redraws into the outer scrollback
disableTermcapinfo() {
    if [ -f "${screenrc}" ]; then
        sed -i -E 's|^([[:space:]]*termcapinfo[[:space:]]+xterm\*[[:space:]]+ti@:te@[[:space:]]*)$|#\1 # disabled by screen5_install.sh|' "${screenrc}"
    fi
}

restoreTermcapinfo() {
    if [ -f "${screenrc}" ]; then
        sed -i -E 's|^#([[:space:]]*termcapinfo[[:space:]]+xterm\*[[:space:]]+ti@:te@[[:space:]]*) # disabled by screen5_install\.sh$|\1|' "${screenrc}"
    fi
}

# "Appends and updates": delete any previous block, then append the current
# one. host-setup.sh overwrites ~/.bash_aliases wholesale - re-run this script
# afterwards to put the block back.
installAgentAliases() {
    touch "${bash_aliases}"
    sed -i "/^${marker_start}$/,/^${marker_end}$/d" "${bash_aliases}"
    [ -s "${bash_aliases}" ] && [ -n "$(tail -c1 "${bash_aliases}")" ] && echo "" >> "${bash_aliases}"
    cat >> "${bash_aliases}" <<HERE
${marker_start}
# run the agent CLIs inside screen 5 - skip when already inside a screen
if [ -z "\${STY}" ]; then
    alias claude='${prefix}/bin/screen claude'
    alias codex='${prefix}/bin/screen bash ${kit_root}/codex.sh'
fi
${marker_end}
HERE
}

ensureAliasesLoaded() {
    touch "${bashrc}"
    sed -i "/^${source_marker_start}$/,/^${source_marker_end}$/d" "${bashrc}"
    if grep -qE '^[[:space:]]*(source|\.)[[:space:]]+(["'\'']?\$HOME/|["'\'']?~/)?\.bash_aliases(["'\'']?)[[:space:]]*$' "${bashrc}"; then
        echo "Keeping existing ${bash_aliases} loader in ${bashrc}"
        return 0
    fi
    [ -s "${bashrc}" ] && [ -n "$(tail -c1 "${bashrc}")" ] && echo "" >> "${bashrc}"
    cat >> "${bashrc}" <<HERE
${source_marker_start}
[ -f "\${HOME}/.bash_aliases" ] && . "\${HOME}/.bash_aliases"
${source_marker_end}
HERE
}

removeAliasesLoader() {
    [ -f "${bashrc}" ] && sed -i "/^${source_marker_start}$/,/^${source_marker_end}$/d" "${bashrc}"
}

removeAgentAliases() {
    if [ ! -f "${bash_aliases}" ]; then
        echo "No ${bash_aliases} found - nothing to remove"
        return 0
    fi
    sed -i "/^${marker_start}$/,/^${marker_end}$/d" "${bash_aliases}"
    if [ ! -s "${bash_aliases}" ]; then
        # the file only ever held our block - remove it entirely
        rm -f "${bash_aliases}"
        echo "Removed now-empty ${bash_aliases}"
    fi
}

removeScreen() {
    # only unlink ${prefix}/bin/screen if it points at our build
    [ "$(readlink -f "${prefix}/bin/screen" 2>/dev/null)" == "${prefix}/bin/screen-${version}" ] && sudo rm -f "${prefix}/bin/screen"
    # re-running the install makes make rename the previous binary/link to .old
    [ "$(readlink -f "${prefix}/bin/screen.old" 2>/dev/null)" == "${prefix}/bin/screen-${version}" ] && sudo rm -f "${prefix}/bin/screen.old"
    sudo rm -f "${prefix}/bin/screen-${version}" "${prefix}/bin/screen-${version}.old"
    sudo rm -f "${prefix}/share/man/man1/screen.1"
    sudo install-info --delete --info-dir="${prefix}/share/info" "${prefix}/share/info/screen.info" 2>/dev/null || true
    sudo rm -f "${prefix}/share/info/screen.info"*
    sudo rm -rf "${prefix}/share/screen/utf8encodings"
    sudo rmdir "${prefix}/share/screen" 2>/dev/null || true
}

restoreScreenrc() {
    if [ ! -f "${screenrc}" ]; then
        echo "No ${screenrc} found - nothing to restore"
        return 0
    fi
    sed -i "/^${marker_start}$/,/^${marker_end}$/d" "${screenrc}"
    if [ ! -s "${screenrc}" ]; then
        # the file only ever held our block - remove it entirely
        rm -f "${screenrc}"
        echo "Removed now-empty ${screenrc}"
    fi
}

##################################################
################# EXECUTION ######################
##################################################

if [ "${uninstall}" == "1" ]; then
    echo "Removing artifacts left by the older screen_install.sh..."
    cleanLegacyInstall
    echo -e "[Done]\n"

    echo "Removing the agent alias block from ${bash_aliases}..."
    removeAgentAliases
    removeAliasesLoader
    echo -e "[Done]\n"

    echo "Removing screen ${version} from ${prefix}..."
    removeScreen
    echo -e "[Done]\n"

    echo "Restoring ${screenrc}..."
    restoreTermcapinfo
    restoreScreenrc
    echo -e "[Done]\n"

    echo "Build packages were left installed - if nothing else needs them: sudo apt-get remove build-essential autoconf automake texinfo libncurses-dev libpam0g-dev pkg-config"
else
    echo "Removing artifacts left by the older screen_install.sh..."
    cleanLegacyInstall
    echo -e "[Done]\n"

    installed_version="$("${prefix}/bin/screen" --version 2>/dev/null | awk '{print $3}')"
    if [ "${installed_version}" == "${version}" ]; then
        echo -e "screen ${version} is already installed - skipping the build\n"
    else
        echo "Installing build dependencies..."
        installBuildDeps
        echo -e "[Done]\n"

        echo "Building and installing screen ${version} to ${prefix}..."
        buildAndInstallScreen
        echo -e "[Done]\n"
    fi

    echo "Configuring ${screenrc}..."
    configureScreenrc
    disableTermcapinfo
    echo -e "[Done]\n"

    echo "Updating the agent alias block in ${bash_aliases}..."
    installAgentAliases
    ensureAliasesLoaded
    echo -e "[Done]\n"
fi

##################################################
################ POST-CHECKS #####################
##################################################

echo -e "\nStarting Post-checks ..."
echo "-------------------------------"

if [ "${uninstall}" == "1" ]; then
    echo "Checking screen ${version} is gone from ${prefix}..."
    [ -e "${prefix}/bin/screen-${version}" ] && echo "${prefix}/bin/screen-${version} is still present ... exiting" && exit 1
    echo "[OK]"

    echo "Checking ${screenrc} no longer has a managed block..."
    [ -f "${screenrc}" ] && grep -qF "managed block" "${screenrc}" && echo "Managed block still present ... exiting" && exit 1
    echo "[OK]"

    echo "Checking the agent alias block is gone..."
    [ -f "${bash_aliases}" ] && grep -qF "${marker_start}" "${bash_aliases}" && echo "Managed block still present in ${bash_aliases} ... exiting" && exit 1
    [ -f "${legacy_alias_file}" ] && echo "${legacy_alias_file} is still present ... exiting" && exit 1
    [ -f "${bash_bashrc}" ] && grep -qF "${legacy_marker_start}" "${bash_bashrc}" && echo "Legacy block still present in ${bash_bashrc} ... exiting" && exit 1
    echo "[OK]"

    echo "'screen' now resolves to: $(command -v screen || echo none)"
    echo "Shells opened before the uninstall keep the claude alias until they are reopened"
else
    echo "Checking installed screen version..."
    installed_version="$("${prefix}/bin/screen" --version | awk '{print $3}')"
    [ "${installed_version}" != "${version}" ] && echo "Expected ${version} but found '${installed_version}' ... exiting" && exit 1
    echo "[OK]"

    echo "Checking ${screenrc} has the managed block and no active termcapinfo..."
    [ -z "$(grep -F "${marker_start}" "${screenrc}")" ] && echo "Managed block missing ... exiting" && exit 1
    grep -qE '^[[:space:]]*termcapinfo[[:space:]]+xterm\*[[:space:]]+ti@:te@' "${screenrc}" && echo "An active 'termcapinfo xterm* ti@:te@' is still present ... exiting" && exit 1
    echo "[OK]"

    echo "Checking the agent alias block in ${bash_aliases}..."
    [ -z "$(grep -F "${marker_start}" "${bash_aliases}")" ] && echo "Managed block missing from ${bash_aliases} ... exiting" && exit 1
    grep -qF "alias claude='${prefix}/bin/screen claude'" "${bash_aliases}" || { echo "Claude alias missing from ${bash_aliases} ... exiting"; exit 1; }
    grep -qF "alias codex='${prefix}/bin/screen bash ${kit_root}/codex.sh'" "${bash_aliases}" || { echo "Codex alias missing from ${bash_aliases} ... exiting"; exit 1; }
    bash -ic 'type claude >/dev/null 2>&1 && type codex >/dev/null 2>&1' 2>/dev/null || { echo "Agent aliases are not loaded by a new interactive shell ... exiting"; exit 1; }
    echo "[OK]"

    echo "Checking the older screen_install.sh artifacts are gone..."
    [ -f "${legacy_alias_file}" ] && echo "${legacy_alias_file} is still present ... exiting" && exit 1
    [ -f "${bash_bashrc}" ] && grep -qF "${legacy_marker_start}" "${bash_bashrc}" && echo "Legacy block still present in ${bash_bashrc} ... exiting" && exit 1
    echo "[OK]"

    echo "The claude and codex aliases reach new shells automatically - current shells: source ${bash_aliases}"
    echo "oe-deploy's host-setup.sh overwrites ${bash_aliases} and ${screenrc} - re-run this script after it"
    path_screen="$(command -v screen || true)"
    echo "'screen' resolves to: ${path_screen}"
    echo 'Truecolor test (run inside a new screen session): printf "\x1b[38;2;255;100;0mTRUECOLOR\x1b[0m\n"'
fi

echo "Post-checks complete ..."
echo "-------------------------------"

trap : 0
echo >&2 ""
echo "**************************************************"
echo "**************************************************"
if [ "${uninstall}" == "1" ]; then
    echo "*****************SCREEN 5 REMOVED*****************"
else
    echo "****************SCREEN 5 INSTALLED****************"
fi
echo "**************************************************"
echo "**************************************************"
sleep 3s
