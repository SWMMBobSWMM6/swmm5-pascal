# swmm5-pascal

EPA SWMM 5.2.4 in Free Pascal, written by a translator that reads EPA's C, and judged against EPA itself: the
binary `.out` file byte for byte, and the `.rpt` report line for line except the three lines that print the wall
clock.

**Result: 480 of 480 models identical** (`gate/results/pas_3.json`, log `gate/pas_3_run.txt`). The 480 took 204 seconds of wall time
run one at a time (the sum of the per-model times the gate records; EPA's reference run, made earlier on a
differently loaded machine, records 256 s; no interleaved benchmark was run, so no speed ratio is claimed).

It is not a new engine. Every number it writes is EPA 5.2.4's, including the results of EPA's own defects
wherever EPA's behaviour is defined (`lessons/02-epa-defects-found.md`).

## The parity contract

The same as the earlier ports (see `go/` or the swmm5-go repository): EPA SWMM 5.2.4 built from the USEPA v5.2.4
tag with gcc 13.3 `-O2` on x86-64 Linux with glibc 2.39 (`ref/Makefile`); each model run in its own folder;
pass = `.out` byte-identical (when EPA writes one) and `.rpt` identical after removing `Analysis begun on`,
`Analysis ended on` and `Total elapsed time`, the exit code the same (EPA's command line always exits 0). When
an input error stops EPA before it writes results, the engine must not write a results file either. Corpus: the
480 gate models of `gate/models_all.tsv` from SWMMBobSWMM6/1729-SWMM5-Models-2030.

## Build and run

Requires Free Pascal 3.2.2 (`fpc`; tested with the Ubuntu package 3.2.2+dfsg-32) and glibc's libm.

```sh
pascal/build.sh
pascal/bin/runswmm model.inp model.rpt model.out
```

The 52,000-line engine compiles in about a second. `build.sh` explains its flags; the C semantics come from the
switches at the top of each unit: `{$Q-}{$R-}` (integers wrap, no range checks), `{$B-}` (short-circuit
`and`/`or`), `{$PACKRECORDS C}` (C's record layout), `{$POINTERMATH ON}` (C's pointer arithmetic),
`{$mode objfpc}` with 32-bit `Int32` written out everywhere (no mode-dependent `Integer`).

## How it was made

`tools/c2x/front.py` parses EPA's 54 C files with libclang; `tools/c2x/emit_pascal.py` (1,477 lines, built on
the Zig back end's analysis in `emit_zig.py`) writes the whole engine as one unit, `pascal/src/swmm5eng.pas`
(52,072 lines, generated); the hand-written unit `pascal/src/swmmcrt.pas` (2,419 lines) supplies the C library
pieces SWMM uses, and `pascal/src/runswmm.pas` (59 lines) is EPA's `run/main.c`. When the port disagreed with
EPA, the fix went into the translator or the runtime, never into the generated file.

Free Pascal has typed pointers with arithmetic, records with C's layout, `goto` and nested functions, so like the
Zig port this one keeps C's data layout and pointers:

- `int`, `unsigned`, `long`, `char`, `double`, `float` become `Int32`, `UInt32`, `Int64`, `AnsiChar`, `Double`,
  `Single`; a `char` becomes an integer through `ShortInt` (C's char is signed); structs are records and the one
  union a variant record (a `{$if sizeof(...)}` check in the generated unit compares every record's size with
  the C compiler's); `T*` is a named pointer type (`PTNode = ^TNode`), function pointers are procedural types.
  `odesolve.c` and `mempool.c` are translated like the rest; nothing in EPA is overridden.
- Free Pascal may evaluate 32-bit integer operations in 64 bits, so every integer operation is cast back to its C
  type (`Int32(a + b)`); `/` and `%` are `div` and `mod` (both truncate as C does); a signed `>>` is
  `SarLongint` (Pascal's `shr` is logical); `(int)x` of a double goes through `D2I`, x86's `cvttsd2si` rule.
- **Every float literal is a typed constant.** An untyped real constant in Free Pascal is 80-bit Extended:
  `x * 0.1` compiles to x87 instructions that multiply by the 80-bit 0.1 and round twice
  (`lessons/23-pascal-real-constants-are-extended.md`). Each value is declared once (`F0p1: Double = 0.1`), written
  in decimal only where the translator shows, with exact fractions, that Free Pascal's reader (decimal, then 80
  bits, then 53) cannot land on the wrong double; otherwise as its bit pattern, with the `Double` declared
  `absolute` over an `Int64`. So all floating-point arithmetic is SSE2, one rounding per operation, as in EPA.
  A count of x87 instructions per function in the binary finds none that compute or compare in the engine or
  the runtime; the only ones left (`fldl`/`fstpt`) widen a Double exactly to Extended where `array of const`
  packs fprintf's arguments, and two narrow it back.
- Pascal is case-insensitive and lets a local hide a global, so every name is made unique case-insensitively
  (`Node` the global and a C local `node` cannot meet); keywords and System names get a suffix.
- C's assignment and `++` used as values become generic `var`-parameter helpers (`specialize Asg<Int32>(x, v)`);
  `?:` becomes if/else when it is a whole assignment or return, an eager `TernD(c, a, b)` when both arms are
  safe to evaluate, and otherwise a nested function, evaluated lazily in place as C does; `for` loops with
  `continue` jump to their increment with `goto`; C's `break` out of a `switch` jumps past the `case` statement,
  and a section that falls through runs a copy of the next section's code.
- Locals are hoisted to the top of each function and zeroed on entry.

## The runtime and the math library

- **printf/snprintf** (`swmmcrt.pas`): the exact decimal expansion of the binary value from a big-integer
  routine, rounded half to even, as glibc does (the same algorithm as the Zig runtime).
- **strtod/atof/sscanf**: glibc's syntax (decimal, hexadecimal, `inf`, `nan(...)` with its payload). Short
  numbers take an exact fast path (at most 15 digits, exponent within ±22: one correctly rounded operation on
  exact operands); the rest are rounded by exact big-integer comparison with the neighbouring doubles. Free
  Pascal's own `Val` reads through 80-bit Extended and can round twice, so it is not used. `%f` into a float is
  rounded once from the text, as `strtof`. sscanf takes its targets' types from the format, as C does.
- Checked against glibc 2.39 by `pascal/test/run_crtcheck.sh` (the same 1,394,252 cases from
  `tools/crt/test/mkfmt.c` as the Go and Zig checks): **1 differs**, `%#g` of 999999.75 (glibc `1.e+06`, the
  port `1.00000e+06`), the case the Go and Zig runtimes also report; SWMM never uses `%#g`. Output:
  `pascal/test/crtcheck_result.txt`. The first version's slow path got 115,302 of the 200,052 strtod cases
  wrong while the gate passed all 480 models (`lessons/25-the-gate-cannot-vouch-for-the-runtime.md`).
- **stdio** over the RTL's system calls (`FpOpen`, `FpPRead`, `FpPWrite`, `FpWrite`, `FpLseek`): C's position,
  end-of-file flag and buffering; `fread`/`fwrite` move raw bytes, as C's do.
- **Memory** from the Free Pascal heap (`AllocMem`, zero-filled); `calloc(0)` still gives a block.
- **Math**: `exp`, `log`, `log10`, `pow`, `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, and also `sqrt`, `fabs`,
  `floor` and `ceil`, are glibc's, declared `cdecl; external 'm'`; the Math unit is not used. The binary imports
  the same versioned symbols EPA imports (compare `nm -D pascal/bin/runswmm` with `nm -D ref/runswmm`), so the
  port follows EPA on whatever CPU both run on, including glibc's choice of FMA routines.
- **Floating-point environment**: Free Pascal unmasks the invalid, divide-by-zero and overflow exceptions by
  default; the runtime masks them all at start-up (`SetMXCSR($1F80)`), C's environment, so `0/0` is a NaN, not
  a crash.

## How it was checked

| Run | Engine | Result |
|---|---|---|
| pas_1 | first build (strtod slow path wrong, see above) | 480 of 480 |
| pas_2 | strtod corrected | 480 of 480 |
| **pas_3** | **final build** (`pascal/build.sh`): the runtime's `D2I`/`D2L` range tests use typed constants (they were the last x87 comparisons, `lessons/23`), and the runtime checks its power-of-ten tables at start-up | **480 of 480** |
| pas_chk_2 | the final sources built with `-dRANGECHECK` (every fixed-array index in the engine range-checked) | 480 of 480, no range error |

All runs: `python3 gate/gate.py NAME "$PWD/pascal/runswmm_saves.sh" -j 1 --timeout 3600 --prune`, inside
`flock` on the shared corpus lock. `runswmm_saves.sh` backs up every file a deck SAVEs (listed by the swmm6-rust
repository's `gate/savefiles.py`, called read-only) and restores it after the run (`Hydrology/cho.txt` was
1,114,474 bytes, md5 5b0ca1fe78588202fa779dbfa417b089, before and after). The checked run used
`SWMM_BIN=pascal/bin/runswmm_chk` (`FPCFLAGS="-dRANGECHECK -gl" BIN_SUFFIX=_chk pascal/build.sh`). The generated
unit was regenerated from the final translator and compared with the one gated: identical.

## What this does not show

- That SWMM is right: identical to EPA means EPA's answers, good or bad.
- Other platforms: the port calls the system libm, so on another machine it should follow EPA built there; only
  x86-64 Linux with glibc 2.39 was run.
- Paths no gate model exercises: streets and inlets (one deck, which stops on input errors), climate files,
  USE HOTSTART, USE INFLOWS, USE RUNOFF; the stepping API is translated and compiled but only the command line
  was gated.
- The checked run covers fixed-array indexes only. Overflow checks (`{$Q+}`) would trap on C's intended
  wrap-around, and pointer indexing (`p[i]` on a typed pointer) is never checked by Free Pascal; the Zig port's
  checked run (bounds, overflow and cast checks, on a translation of the same C by the same front end and
  analysis, with the same pointer layout) speaks for them, not a run of this binary.
- Speed: not benchmarked against EPA in one interleaved run (lessons/07).
- `realpath` here joins the working directory and the path and removes `.` and `..`; it does not resolve
  symbolic links as glibc's does. The corpus path has none.
- No person has reviewed the generated code line by line; the evidence is the gate and the runtime check.

## Licence and credit

EPA SWMM is a work of the U.S. Environmental Protection Agency and is in the public domain; its engine is Lewis
Rossman's design, and this port keeps every algorithm as he wrote it. The port contains no glibc code: it calls
the system's libm (glibc, LGPL-2.1-or-later, `ref/LGPL-2.1.txt`) as a shared library at run time, as EPA's own
build does. The Free Pascal RTL is linked under its own licence (LGPL with a static-linking exception). No
licence has been chosen yet for the translator and the runtime.

## AI use

The translator back end (`tools/c2x/emit_pascal.py`), the runtime (`pascal/src/swmmcrt.pas`,
`pascal/src/runswmm.pas`), the generated engine, the build and gate scripts, the runtime check and this README
were written by Claude (Anthropic's AI model, Claude Opus 5.5) in a Claude Code session on 6 November 2026, for
Robert (Bob) Dickinson, who chose Zig and Free Pascal as the next languages for his Code Rosetta Stone app and set
the byte-for-byte standard. Claude ran every build, gate and check reported here. The checks are mechanical; no
person has yet reviewed the code.
