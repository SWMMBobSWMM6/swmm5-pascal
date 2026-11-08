#!/bin/sh
# run_crtcheck.sh - check the Pascal runtime's printf, strtod and sscanf against the system glibc:
# tools/crt/test/mkfmt.c writes about 1.4 million reference cases from glibc, test/crtcheck.pas replays them
# through src/swmmcrt.pas and counts the differences. The vectors go to a temporary folder and are deleted.
set -e
cd "$(dirname "$0")/.."
T=$(mktemp -d "${TMPDIR:-/tmp}/pascrt.XXXXXX")
gcc -O2 -o "$T/mkfmt" ../tools/crt/test/mkfmt.c -lm
"$T/mkfmt" > "$T/fmt.txt"
fpc -O2 -Cfsse64 -FUsrc -Fu"$T" -FU"$T" -Fusrc -FE"$T" -o"$T/crtcheck" test/crtcheck.pas > "$T/build.log" 2>&1 || { tail -30 "$T/build.log"; exit 1; }
"$T/crtcheck" "$T/fmt.txt"
rm -rf "$T"
