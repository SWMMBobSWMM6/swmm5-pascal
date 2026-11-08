#!/bin/sh
# build.sh - build the Free Pascal port of EPA SWMM 5.2.4:  bin/runswmm <input> <report> [output]
# Needs Free Pascal 3.2.2 (fpc). Flags:
#   -O2              optimise (FPC on x86-64 computes Double and Single arithmetic with SSE2, one rounding per
#                    operation, as gcc does; the generated code never hands it an untyped real constant)
#   -Cfsse64         the x86-64 default, written out: no x87 for Double arithmetic
#   -CX -XX -Xs      smart-linking and stripping keep the binary small
# The units' {$...} switches set the C semantics: {$Q-}{$R-} wrap-around integers, {$B-} short-circuit
# and/or, {$PACKRECORDS C} C's record layout, {$POINTERMATH ON} C's pointer arithmetic.
# Every libm call goes to glibc's libm.so.6 (external 'm' in src/swmmcrt.pas).
# FPCFLAGS="-dRANGECHECK -gl" BIN_SUFFIX=_chk ./build.sh builds bin/runswmm_chk with range checks on every
# fixed-array index in the engine (explicit casts, which carry C's intended wrap-around, are not checked).
set -e
cd "$(dirname "$0")"
O=obj${BIN_SUFFIX:-}
mkdir -p bin $O
fpc -O2 -Cfsse64 -CX -XX -Xs -FU$O -FEbin -obin/runswmm${BIN_SUFFIX:-} ${FPCFLAGS:-} src/runswmm.pas >$O/build.log 2>&1 || { tail -40 $O/build.log; exit 1; }
grep -iE "warning|error" $O/build.log | grep -v "^Warning: Object file" | head -20 || true
