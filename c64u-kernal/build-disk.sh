#!/bin/sh
# Build kernal.d64 from .bas sources + swiftdrvr49152.prg.
#
# Tokenizes each .bas with petcat, then writes everything to a fresh D64
# with c1541. Driver is written under its 8-char name "swiftdrvr" so the
# BASIC programs can LOAD it.
#
# Requires: petcat and c1541 (both ship with VICE).

set -eu

cd "$(dirname "$0")"

DISK="kernal.d64"
DRIVER_SRC="swiftdrvr.prg"
PROGRAMS="http-get word-search wotd simple"

command -v petcat >/dev/null 2>&1 || { echo "petcat not found (install VICE)"; exit 1; }
command -v c1541  >/dev/null 2>&1 || { echo "c1541 not found (install VICE)";  exit 1; }
[ -f "$DRIVER_SRC" ] || { echo "missing $DRIVER_SRC"; exit 1; }

echo "Tokenizing .bas -> .prg ..."
rm -f http-get.prg wotd.prg word-search.prg simple.prg
for f in $PROGRAMS; do
    [ -f "$f.bas" ] || { echo "missing $f.bas"; exit 1; }
    tr 'A-Z' 'a-z' < "$f.bas" | petcat -w2 -o "$f.prg" --
    echo "  $f.bas -> $f.prg"
done

echo "Building $DISK ..."
rm -f "$DISK"
c1541 -format "kernal,01" d64 "$DISK" \
      -write http-get.prg       http-get \
      -write "$DRIVER_SRC"      swiftdrvr \
      -write word-search.prg    word-search \
      -write wotd.prg           wotd \
      -write simple.prg         simple

echo
c1541 -attach "$DISK" -dir

# use ftp to transfer the disk to the c64
ftp -p -n -v 192.168.0.64 <<EOF
user c64u commodore
binary
cd /USB1/c64u-kernal
put "$DISK"
quit
EOF