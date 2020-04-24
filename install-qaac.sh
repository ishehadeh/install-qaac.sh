#!/bin/env sh
set -e

# depending on the shell $0 may refer to the function name, or script name.
# so just save it while outside of a function
PROG_NAME="$0"

usage() {
    echo "USAGE: $PROG_NAME [ARCH] [VERSION]"
    echo "  Install qaac and all its dependencies in wine"
    echo ""
    echo "  PARAMATERS"
    echo "     ARCH ...... whether to install qaac as 32/64 bit x86. Must be either '32' or '64'"
    echo "     VERSION ... version of qaac to install"
    echo ""
    echo "  ENVIRONMENT"
    echo "     QAAC_WGET .......... path to wget executable (https://www.gnu.org/software/wget) [default: search \$PATH for 'wget']"
    echo "     QAAC_7ZIP .......... path to 7zip executable (https://www.7-zip.org/) [default: search \$PATH for '7z']"
    echo "     QAAC_WINE .......... path to wine executable (https://www.winehq.org/) [default: search \$PATH for 'wine']"
    echo "     QAAC_WINEBOOT ...... path to wineboot executable (https://www.winehq.org/) [default: search \$PATH for 'wineboot']"
    echo "     QAAC_WORK_DIR ...... directory to store logs and downloaded files [default: '\$QAAC_WINPREFIX/qaac-sh-wd']"
    echo "     QAAC_WINEPREFIX .... wineprefix for qaac installation [default: '\$WINEPREFIX' or '\$HOME/.wine']"
    echo "     QAAC_INSTALL_DIR ... directory to install qaac.exe and dynamic libraries [default: '\$QAAC_WINPREFIX/Program Files/qaac.exe' or '\$QAAC_WINPREFIX/Program Files (x86)/qaac.exe']"
    echo ""
    echo "    Extra libraries - these add support for decoding various formats. Set any of these variables to 'disabled' to skip installing them"
    echo "     QAAC_LIBFLAC_VERSION ....... version of libFLAC to install [default: 1.3.3]"
    echo "     QAAC_WAVPACK_VERSION ....... version of WavPack to install [default: 5.3.0]"
    echo "     QAAC_LIBSNDFILE_VERSION ... version of libsndfile to install [default: 1.0.28]"
    echo "     QAAC_TAK_VERSION ........... version of TAK to install [default: 2.3.0]"

}

# USAGE: log <LEVEL> <MESSAGE>
log() {
    printf '[%s] [%s] %s\n' "$PROG_NAME" "$1" "$2"
}

# USAGE: info <MESSAGE>
info() {
    log INFO "$1"
}

# USAGE: fail <MESSAGE>
#   log an error and exit
error() {
    log ERROR "$1"
}

# USAGE: fail <MESSAGE> [CODE]
#   log an error and exit with CODE
fail() {
    error "$1"
    exit "$(if [ -n "$2" ]; then echo "$2"; else echo "1"; fi)"
}

# USAGE: download <URL> <DOCUMENT>
#   download URL and save the content to DOCUMENT
#   if DOCUMENT already exists this function does notion
download() {
    info "downloading '$1' to '$2'"
    if [ -f "$2" ]; then
        info "'$2' already exists, skipping download"
    else
        if ! "$QAAC_WGET" --show-progress --output-document "$2" --append-output "$QAAC_WGET_LOGFILE" "$1"; then
            error "download failed"

            if [ -f "$1" ]; then
                info "removing '$1'"
                rm "$1"
            fi

            info "last 10 lines of '$QAAC_WGET_LOGFILE'"
            tail -n 10 "$QAAC_WGET_LOGFILE"
            exit 1
        fi
    fi
}

# USAGE: install_qaac <VERSION> <ARCH>
#   download a release of qaac from github
#   copies the downloaded binaries to $QAAC_INSTALL_DIR
install_qaac() {
    info "installing qaac binaries"

    qaac_archive_name="qaac_$1.zip"
    qaac_archive_path="$QAAC_WORK_DIR/$qaac_archive_name"
    download "https://github.com/nu774/qaac/releases/download/v${QAAC_VERSION}/$qaac_archive_name" "$qaac_archive_path"

    if [ "$2" = "32" ]; then
        qaac_bin_root="qaac_$1/x86"
    else
        qaac_bin_root="qaac_$1/x64"
    fi

    "$QAAC_7ZIP" e -y "$qaac_archive_path" \
        -i"!$qaac_bin_root/*.exe" \
        -i"!$qaac_bin_root/*.dll" \
        -o"$QAAC_INSTALL_DIR"

    info "finished install qaac binaries"
}

# USAGE install_coreaudio_libraries <ARCH>
#  download the latest release of itunes and extract the coreaudio libraries from it
#  the necessary libraries are copied to the install directory
install_coreaudio_libraries() {
    info "installing coreaudio libraries"

    if [ "$1" = "32" ]; then
        apple_prefix="AppleApplicationSupport_"
        itunes_installer_name="iTunesInstaller.exe"
        itunes_installer_url="https://www.apple.com/itunes/download/win32"
        apple_support_installer="AppleApplicationSupport.msi"
    else
        apple_prefix="x64_AppleApplicationSupport_"
        itunes_installer_name="iTunes64Installer.exe"
        itunes_installer_url="https://www.apple.com/itunes/download/win64"
        apple_support_installer="AppleApplicationSupport64.msi"
    fi

    itunes_installer_path="$QAAC_WORK_DIR/$itunes_installer_name"
    download "$itunes_installer_url" "$itunes_installer_path"

    info "extracting DLLs from itunes installer"
    "$QAAC_7ZIP" e -y "$itunes_installer_path" "$apple_support_installer" -o"$QAAC_WORK_DIR"

    "$QAAC_7ZIP" e -y "$QAAC_WORK_DIR/$apple_support_installer" \
        -i"!*${apple_prefix}ASL.dll" \
        -i"!*${apple_prefix}CoreAudioToolbox.dll" \
        -i"!*${apple_prefix}CoreFoundation.dll" \
        -i"!*${apple_prefix}icudt*.dll" \
        -i"!*${apple_prefix}libdispatch.dll" \
        -i"!*${apple_prefix}libicu*.dll" \
        -i"!*${apple_prefix}objc.dll" \
        -i"!F_CENTRAL_msvc?100*" \
        -o"$QAAC_WORK_DIR"

    # move apple-prefixed dlls to the install directory
    for f in "$QAAC_WORK_DIR/$apple_prefix"*.dll; do
        mv -v "$f" "$QAAC_INSTALL_DIR/${f#"$QAAC_WORK_DIR/$apple_prefix"}"
    done

    # normalize msvcr filename
    for j in "$QAAC_WORK_DIR/"F_CENTRAL_msvcr100*; do
        mv -v "$j" "$QAAC_INSTALL_DIR/msvcr100.dll"
    done

    # normalize msvcp filename
    for j in "$QAAC_WORK_DIR/"F_CENTRAL_msvcp100*; do
        mv -v "$j" "$QAAC_INSTALL_DIR/msvcp100.dll"
    done

    info "finished installing coreaudio libraries"
}

# USAGE: install_libflac <VERSION> <ARCH>
#  download libflac from rarewares.org (libflac doesn't distribute official DLLs)
#  copy libFLAC_dynamic.dll to the install directory
install_libflac() {
    info "installing libFLAC v$1 from rarewares.org"

    if [ "$2" = "32" ]; then
        flac_archive_name="flac_dll-$1-x86.zip"
    else
        flac_archive_name="flac_dll-$1-x64.zip"
    fi

    flac_archive_path="$QAAC_WORK_DIR/$flac_archive_name"
    download "http://www.rarewares.org/files/lossless/$flac_archive_name" "$flac_archive_path"
    "$QAAC_7ZIP" x -y "$flac_archive_path" "libFLAC_dynamic.dll" -o"$QAAC_INSTALL_DIR"

    info "finished install libFLAC"
}

# USAGE: install_wavpack <VERSION> <ARCH>
#  download the WavPack DLLs from from a github release
#  copy the wavpackdll.dll to the install directory
install_wavpack() {
    info "installing wavpack v$1"

    wavpack_archive_name="wavpack-$1-dll.zip"
    wavpack_archive_path="$QAAC_WORK_DIR/$wavpack_archive_name"

    download "https://github.com/dbry/WavPack/releases/download/$1/$wavpack_archive_name" "$wavpack_archive_path"
    "$QAAC_7ZIP" x -y "$wavpack_archive_path" -o"$QAAC_INSTALL_DIR"

    if [ "$2" = "32" ]; then
        "$QAAC_7ZIP" x -y "$wavpack_archive_path" "x32/wavpackdll.dll" -o"$QAAC_INSTALL_DIR"
    else
        "$QAAC_7ZIP" x -y "$wavpack_archive_path" "x64/wavpackdll.dll" -o"$QAAC_INSTALL_DIR"
    fi

    info "finished install wavpack"
}

# USAGE: install_tak <VERSION>
#   download tak from thbeck.de, copy the decoding dll to the install directory
#   NOTE: this always installs the 32-bit version, since there is no 64-bit version.
install_tak() {
    info "installing TAK v$1"

    tak_archive_name="TAK_$1.zip"
    tak_archive_path="$QAAC_WORK_DIR/$tak_archive_name"
    download "http://thbeck.de/Download/$tak_archive_name" "$tak_archive_path"
    "$QAAC_7ZIP" e -y "$tak_archive_path" "Deco_Lib/tak_deco_lib.dll" -o"$QAAC_INSTALL_DIR"

    info "finished installing TAK"
}

# USAGE install_libsndfile <VERSION> <ARCH>
#    download libsndfile installer from mega-nerd.com
#    runs the installer and copies libsndfile-1.dll to the install directory
#    NOTE: the installer includes a popup from the developer asking for donations
install_libsndfile() {
    info "installing libsndfile v$1"

    libsndfile_installer_name="libsndfile-$1-w$2-setup.exe"
    libsndfile_installer_path="$QAAC_WORK_DIR/$libsndfile_installer_name"

    download "http://www.mega-nerd.com/libsndfile/files/$libsndfile_installer_name" "$libsndfile_installer_path"

    info "running libsndfile installer"
    env WINEPREFIX="$QAAC_WINEPREFIX" "$QAAC_WINE" "$libsndfile_installer_path" "/verysilent"

    if [ "$2" = "32" ]; then
        libsndfile_root="$QAAC_WINEPREFIX/drive_c/Program Files (x86)/Mega-Nerd"
    else
        libsndfile_root="$QAAC_WINEPREFIX/drive_c/Program Files/Mega-Nerd"
    fi

    mv -v "$libsndfile_root/libsndfile/bin/libsndfile-1.dll" "$QAAC_INSTALL_DIR"

    info "removing main libsndfile directory '$libsndfile_root'"
    rm -r "$libsndfile_root"

    info "finished install libsndfile"
}

if [ -z "$1" ] && [ -z "$2" ]; then
    usage
    exit 0
fi

if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ "$1" = "help" ] || [ "$1" = "?" ]; then
    usage
    exit 0
fi

# if any dependency is not found, than this will be set
# allows the programs to list all missing deps before exiting
dep_error=0

if [ ! -x "$QAAC_WGET" ]; then
    QAAC_WGET="$(command -v wget || exit 0)"
fi

if [ ! -x "$QAAC_7ZIP" ]; then
    QAAC_7ZIP="$(command -v 7z || exit 0)"
fi

if [ ! -x "$QAAC_WINE" ]; then
    QAAC_WINE="$(command -v wine || exit 0)"
fi

if [ ! -x "$QAAC_WINEBOOT" ]; then
    QAAC_WINEBOOT="$(command -v wineboot || exit 0)"
fi

if [ ! -x "$QAAC_WGET" ]; then
    error "wget is required, please make sure it is in \$PATH, or set \$QAAC_WGET manually"
    if [ -n "$QAAC_WGET" ]; then
        info "\$QAAC_WGET is set, but is not an executable file. QAAC_WGET='$QAAC_WGET'"
    fi

    dep_error=1
fi

if [ ! -x "$QAAC_7ZIP" ]; then
    error "7z is required, please make sure it is in \$PATH, or set \$QAAC_7ZIP manually"
    if [ -n "$QAAC_7ZIP" ]; then
        info "\$QAAC_7ZIP is set, but is not an executable file. QAAC_7ZIP='$QAAC_7ZIP'"
    fi

    dep_error=1
fi

if [ ! -x "$QAAC_WINE" ]; then
    error "wine is required, please make sure it is in \$PATH, or set \$QAAC_WINE manually"
    if [ -n "$QAAC_WINE" ]; then
        info "\$QAAC_WINE is set, but is not an executable file. QAAC_WINE='$QAAC_WINE'"
    fi

    dep_error=1
fi

if [ ! -x "$QAAC_WINEBOOT" ]; then
    error "wineboot is required, please make sure it is in \$PATH, or set \$QAAC_WINEBOT manually"
    if [ -n "$QAAC_WINEBOOT" ]; then
        info "\$QAAC_WINEBOOT is set, but is not an executable file. QAAC_WINEBOOT='$QAAC_WINEBOOT'"
    fi

    dep_error=1
fi

[ "$dep_error" -eq 0 ] || fail "dependency error(s)"

QAAC_ARCH="$1"
QAAC_VERSION="$2"
if [ "$QAAC_ARCH" != "32" ] && [ "$QAAC_ARCH" != "64" ]; then
    usage
    fail "invalid ARCH expecting 32 or 64. \$QAAC_ARCH='$QAAC_ARCH'"
fi

if [ -z "$QAAC_VERSION" ]; then
    usage
    fail "invalid VERSION, must be set. \$QAAC_VERSION='$QAAC_VERSION'"
fi

if [ -z "$QAAC_WINEPREFIX" ]; then
    QAAC_WINEPREFIX="$WINEPREFIX"
    if [ -z "$QAAC_WINEPREFIX" ]; then
        QAAC_WINEPREFIX="$HOME/.wine"
    fi
fi

# wine required a full path
QAAC_WINEPREFIX="$(readlink -f "$QAAC_WINEPREFIX")"

QAAC_WORK_DIR=${QAAC_WORK_DIR:="$QAAC_WINEPREFIX/drive_c/qaac-sh-wd"}
if [ "$QAAC_ARCH" = "32" ]; then
    QAAC_INSTALL_DIR=${QAAC_INSTALL_DIR:="$QAAC_WINEPREFIX/drive_c/Program Files (x86)/qaac"}
else
    QAAC_INSTALL_DIR=${QAAC_INSTALL_DIR:="$QAAC_WINEPREFIX/drive_c/Program Files/qaac"}
fi

QAAC_WGET_LOGFILE="$QAAC_WORK_DIR/qaac.wget.log"

QAAC_LIBFLAC_VERSION=${QAAC_LIBFLAC_VERSION:="1.3.3"}
QAAC_WAVPACK_VERSION=${QAAC_WAVPACK_VERSION:="5.3.0"}
QAAC_LIBSNDFILE_VERSION=${QAAC_LIBSNDFILE_VERSION:="1.0.28"}
QAAC_TAK_VERSION=${QAAC_TAK_VERSION:="2.3.0"}

info "beginning installation"
echo "   QAAC_WGET='$QAAC_WGET'"
echo "   QAAC_7ZIP='$QAAC_7ZIP'"
echo "   QAAC_WINE='$QAAC_WINE'"
echo "   QAAC_WINEBOOT='$QAAC_WINEBOOT'"
echo "   QAAC_WINEPREFIX='$QAAC_WINEPREFIX'"
echo "   QAAC_ARCH='$QAAC_ARCH'"
echo "   QAAC_VERSION='$QAAC_VERSION'"
echo "   QAAC_WORK_DIR='$QAAC_WORK_DIR'"
echo "   QAAC_INSTALL_DIR='$QAAC_INSTALL_DIR'"
echo "   QAAC_WGET_LOGFILE='$QAAC_WGET_LOGFILE'"
echo "   QAAC_LIBFLAC_VERSION='$QAAC_LIBFLAC_VERSION'"
echo "   QAAC_WAVPACK_VERSION='$QAAC_WAVPACK_VERSION'"
echo "   QAAC_LIBSNDFILE_VERSION='$QAAC_LIBSNDFILE_VERSION'"
echo "   QAAC_TAK_VERSION='$QAAC_TAK_VERSION'"

info "setting up wine prefix '$QAAC_WINEPREFIX'."
WINEPREFIX="$QAAC_WINEPREFIX" "$QAAC_WINEBOOT" -u >/dev/null

info "creating working directory '$QAAC_WORK_DIR'."
mkdir -p "$QAAC_WORK_DIR"

info "creating install directory '$QAAC_INSTALL_DIR'."
mkdir -p "$QAAC_INSTALL_DIR"

install_qaac "$QAAC_VERSION" "$QAAC_ARCH"
install_coreaudio_libraries "$QAAC_ARCH"

[ "$QAAC_LIBFLAC_VERSION" != "disabled" ] && install_libflac "$QAAC_LIBFLAC_VERSION" "$QAAC_ARCH"
[ "$QAAC_WAVPACK_VERSION" != "disabled" ] && install_wavpack "$QAAC_WAVPACK_VERSION" "$QAAC_ARCH"
[ "$QAAC_LIBSNDFILE_VERSION" != "disabled" ] && install_libsndfile "$QAAC_LIBSNDFILE_VERSION" "$QAAC_ARCH"

if [ "$QAAC_TAK_VERSION" != "disabled" ]; then
    if [ "$QAAC_ARCH" = "32" ]; then
        install_tak "$QAAC_TAK_VERSION"
    else
        info "skipping TAK install, TAK is 32bit only"
    fi
fi

if [ "$QAAC_ARCH" = "32" ]; then
    QAAC_WIN_PATH='C:\Program Files (x86)\qaac\qaac.exe'
else
    QAAC_WIN_PATH='C:\Program Files\qaac\qaac64.exe'
fi

info "checking qaac"
if env WINEPREFIX="$QAAC_WINEPREFIX" "$QAAC_WINE" "$QAAC_WIN_PATH" --check; then
    info "removing working directory"
    rm -vr "$QAAC_WORK_DIR"

    info "qaac installed, run it with this command:"
    echo "    env WINEPREFIX='$QAAC_WINEPREFIX' '$QAAC_WINE' '$QAAC_WIN_PATH'"
else
    fail "qaac --check failed"
fi
