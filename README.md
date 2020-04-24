# install-qaac.sh

This script installs [qaac](https://github.com/nu774/qaac) on linux.

## Dependencies

- `wine`: https://www.winehq.org/
- `7zip`: https://www.7-zip.org/
- `wget`: https://www.gnu.org/software/wget
- `curl`: https://curl.haxx.se/

Either `curl` or `wget` can be installed, both are not required.
If both  are installed `wget` is used.
To use `curl` instead set `QAAC_CURL="$(which curl)"`.

### Optional Dependencies:
- `Xvrb`: allows X11 programs to be run headless

Most distributions will have these applications in their package managers.

## Usage

`./install-qaac.sh <ARCH> <VERSION>`

ARCH controls whether script installs the 64-bit or 32-bit version of `qaac` and its dependencies. 
ARCH must be either `32` or `64`.
Note that arch does not influence WINEARCH, just the architecture of the installed binaries.

VERSION is the version of `qaac` to install.
A full list can be found on the [release page](https://github.com/nu774/qaac/releases).

### Environment variables

__Location Settings:__
- QAAC_WINEPREFIX: set the wine directory for `qaac`. [default: `WINEPREFIX` or `$HOME/.wine`]
- QAAC_WORK_DIR: set the working directory, this is where logs and downloaded files are kept. [default: `/tmp/qaac-sh-wd`] 
- QAAC_INSTALL_DIR: set the directory where `qaac` and all its dependencies will be installed. [default: `QAAC_WINEPREFIX/Program Files/qaac` or `QAAC_WINEPREFIX/Program Files (x86)/qaac`]

__Program Settings:__
- QAAC_WGET: path to wget executable [default: search `PATH` for `wget`]
- QAAC_CURL: path to curl executable. Unless set explicitly, only used when wget is not found [default: search `PATH` for `curl`]
- QAAC_7ZIP: path to 7z executable [default: search `PATH` for `7z`]
- QAAC_WINE: path to wine executable [default: search `PATH` for `wine`]
- QAAC_WINEBOOT: path to wineboot executable [default: search `PATH` for `wineboot`]
- QAAC_XVFB: path to Xvfb executable [default: unset]

__Optional Dependency Settings:__
These libraries add support for decoding various formats.
Set any of these variables to _disabled_ to skip installing them

- QAAC_LIBFLAC_VERSION: version of libFLAC to install [default: 1.3.3]
- QAAC_WAVPACK_VERSION: version of WavPack to install [default: 5.3.0]
- QAAC_TAK_VERSION: version of TAK to install [default: 2.3.0]
- QAAC_LIBSNDFILE_VERSION: version of libsndfile to install [default: 1.0.28]

__Misc. Settings:__
- QAAC_CLOSE_LIBSNDFILE_POPUP: libsndfile opens a popup asking for donations as part of the install script, to automatically close it set this variable to `1` [default: unset]
- QAAC_KEEP_WORK_DIR: set to '1' to keep the working directory after finishing [default: unset]

### Examples

#### Headless 32-bit Install

```sh
QAAC_XVFB=1 install-qaac.sh 32 2.68
```

#### Download files using Curl, don't install libsndfile

```sh
QAAC_CURL=/usr/bin/curl QAAC_LIBSNDFILE_VERSION=disabled install-qaac.sh 64 2.68
```

## Sources for Binaries

This script does not build any of the software it installs, it downloads pre-built binaries from various sources.
Here is a list of the websites it downloads from:

- qaac: downloaded from its github releases page (https://github.com/nu774/qaac/releases/download/...)
- iTunes: downloaded from Apple's website (https://www.apple.com/itunes/download/...)
- libFLAC: downloaded rarewares.org (http://www.rarewares.org/files/lossless/flac_dll...)
- WavPack: downloaded its github releases page (https://github.com/dbry/WavPack/releases/download/...)
- TAK: downloaded the author's website, thbeck.de (http://thbeck.de/Download/...)
- libsndfile: downloaded the author's website, mega-nerd.com (http://www.mega-nerd.com/libsndfile/files/...)