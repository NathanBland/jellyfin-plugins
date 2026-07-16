#!/usr/bin/env bash
set -euo pipefail

COMSKIP_COMMIT="a140b6ac8bc8f596729e9052819affc779c3b377"
FFMPEG_FORMULA="ffmpeg@7"
PREFIX="${HOME}/.local"
if [[ "${1:-}" == "--prefix" ]]; then
    [[ -n "${2:-}" ]] || { echo "--prefix requires a path" >&2; exit 2; }
    PREFIX="$2"
elif [[ $# -gt 0 ]]; then
    echo "Usage: $0 [--prefix PATH]" >&2
    exit 2
fi

command -v brew >/dev/null || { echo "Homebrew is required: https://brew.sh" >&2; exit 1; }
missing=()
for package in autoconf automake libtool pkgconf argtable "$FFMPEG_FORMULA"; do
    brew list --versions "$package" >/dev/null 2>&1 || missing+=("$package")
done
if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Install missing dependencies with: brew install ${missing[*]}" >&2
    exit 1
fi

ffmpeg_prefix="$(brew --prefix "$FFMPEG_FORMULA")"
export PATH="$ffmpeg_prefix/bin:$PATH"
export PKG_CONFIG_PATH="$ffmpeg_prefix/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export CPPFLAGS="-I$ffmpeg_prefix/include${CPPFLAGS:+ $CPPFLAGS}"
export LDFLAGS="-L$ffmpeg_prefix/lib${LDFLAGS:+ $LDFLAGS}"
ffmpeg_version="$(PKG_CONFIG_PATH="$ffmpeg_prefix/lib/pkgconfig" pkgconf --modversion libavcodec)"
echo "Building Comskip with $FFMPEG_FORMULA (libavcodec $ffmpeg_version)"

work="$(mktemp -d "${TMPDIR:-/tmp}/commercial-skipper-comskip.XXXXXX")"
trap 'rm -rf "$work"' EXIT
git clone --quiet https://github.com/erikkaashoek/Comskip.git "$work/Comskip"
git -C "$work/Comskip" checkout --quiet "$COMSKIP_COMMIT"
(
    cd "$work/Comskip"
    ./autogen.sh
    ./configure --disable-gui --prefix="$PREFIX"
    make -j "$(sysctl -n hw.ncpu)"
)
mkdir -p "$PREFIX/bin"
install -m 0755 "$work/Comskip/comskip" "$PREFIX/bin/comskip"
help_output="$("$PREFIX/bin/comskip" --help 2>&1 || true)"
if [[ "$help_output" != *"Usage:"* ]]; then
    echo "Installed Comskip failed its launch verification:" >&2
    echo "$help_output" >&2
    exit 1
fi
echo "Installed pinned Comskip $COMSKIP_COMMIT to $PREFIX/bin/comskip"
