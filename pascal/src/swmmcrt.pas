{ swmmcrt.pas - the C runtime of the Free Pascal port of EPA SWMM 5.2.4 (used by the generated unit swmm5eng).

  It reproduces the glibc 2.39 / x86-64 behaviour SWMM's output depends on, in Pascal:
    * printf/snprintf with glibc's exact decimal rounding (an exact big-integer expansion of the binary value,
      rounded half to even, as glibc does in its default rounding mode);
    * strtod/atof/atoi/sscanf with glibc's syntax (decimal, hexadecimal, inf, nan(...)), correctly rounded by
      exact big-integer comparison (Free Pascal's own Val reads through 80-bit Extended and can round twice);
    * stdio over the RTL's system calls (FpOpen, FpPRead, FpPWrite, ...): C's position, end-of-file flag and
      buffering;
    * strings, memory (zero-filled blocks from the Free Pascal heap), time;
    * x86-64 conversions: (int)x of a double is cvttsd2si (NaN or out of range gives INT_MIN);
    * libm: exp, log, log10, pow, sin, cos, tan, asin, acos, atan, sqrt, fabs, floor and ceil are glibc's, through
      `external 'm'` (cdecl), the library EPA itself calls. Free Pascal's Math unit is not used.
  The floating-point environment is C's: every exception masked (MXCSR $1F80), so 0/0 is a NaN, not a crash.
  Written by Claude (Anthropic) for Robert Dickinson; see pascal/README.md. }
{$mode objfpc}{$H+}{$POINTERMATH ON}{$GOTO ON}{$B-}{$Q-}{$R-}{$PACKRECORDS C}{$INLINE ON}
unit swmmcrt;

interface

uses BaseUnix;

type
  PInt32 = ^Int32;
  PInt64 = ^Int64;
  PUInt32 = ^UInt32;
  PDoubleR = ^Double;
  PSingleR = ^Single;
  PCFile = ^TCFile;
  TCFile = record
    fd: Int32;
    isstd: Int32;
    eof: Int32;
    append: Int32;
    pos: Int64;
    wpos: Int64;
    wlen: Int64;
    rstart: Int64;
    rlen: Int64;
    wbuf: PByte;
    rbuf: PByte;
  end;

var
  c_stdout, c_stderr: PCFile;

{ libm (glibc), as EPA calls it }
function c_exp(x: Double): Double; cdecl; external 'm' name 'exp';
function c_log(x: Double): Double; cdecl; external 'm' name 'log';
function c_log10(x: Double): Double; cdecl; external 'm' name 'log10';
function c_pow(x, y: Double): Double; cdecl; external 'm' name 'pow';
function c_sin(x: Double): Double; cdecl; external 'm' name 'sin';
function c_cos(x: Double): Double; cdecl; external 'm' name 'cos';
function c_tan(x: Double): Double; cdecl; external 'm' name 'tan';
function c_asin(x: Double): Double; cdecl; external 'm' name 'asin';
function c_acos(x: Double): Double; cdecl; external 'm' name 'acos';
function c_atan(x: Double): Double; cdecl; external 'm' name 'atan';
function c_sqrt(x: Double): Double; cdecl; external 'm' name 'sqrt';
function c_fabs(x: Double): Double; cdecl; external 'm' name 'fabs';
function c_floor(x: Double): Double; cdecl; external 'm' name 'floor';
function c_ceil(x: Double): Double; cdecl; external 'm' name 'ceil';

{ conversions with x86-64 semantics }
function D2I(x: Double): Int32; inline;
function D2L(x: Double): Int64; inline;
function D2U(x: Double): UInt32; inline;
function D2UL(x: Double): UInt64; inline;
function D2F(x: Double): Single; inline;
function I2FD(x: Int64): Double; inline;
function I2FS(x: Int64): Single; inline;
function U2D(x: UInt64): Double;
function U2S(x: UInt64): Single;

{ ?: with both arms evaluated (the translator uses these only when evaluating both is harmless) }
function TernI32(c: Boolean; a, b: Int32): Int32; inline;
function TernU32(c: Boolean; a, b: UInt32): UInt32; inline;
function TernI64(c: Boolean; a, b: Int64): Int64; inline;
function TernU64(c: Boolean; a, b: UInt64): UInt64; inline;
function TernD(c: Boolean; a, b: Double): Double; inline;
function TernF(c: Boolean; a, b: Single): Single; inline;
function TernC(c: Boolean; a, b: AnsiChar): AnsiChar; inline;
function TernP(c: Boolean; a, b: Pointer): Pointer; inline;

{ assignment and ++/-- used as values }
generic function Asg<T>(var x: T; const v: T): T; inline;
generic function PostInc<T>(var x: T): T; inline;
generic function PostDec<T>(var x: T): T; inline;
generic function PreInc<T>(var x: T): T; inline;
generic function PreDec<T>(var x: T): T; inline;

{ strings }
function c_strlen(p: PAnsiChar): UInt64;
function c_strcpy(d, s: PAnsiChar): PAnsiChar;
function c_strcat(d, s: PAnsiChar): PAnsiChar;
function c_strcmp(a, b: PAnsiChar): Int32;
function c_strchr(p: PAnsiChar; c: Int32): PAnsiChar;
function c_strrchr(p: PAnsiChar; c: Int32): PAnsiChar;
function c_strstr(h, n: PAnsiChar): PAnsiChar;
function c_strcspn(p, rej: PAnsiChar): UInt64;
function c_strtok(p, delim: PAnsiChar): PAnsiChar;
function c_toupper(c: Int32): Int32;
function c_atoi(p: PAnsiChar): Int32;
function c_atof(p: PAnsiChar): Double;
function c_strtod(p: PAnsiChar; endp: PPAnsiChar): Double;
procedure c_strinit(d, s: PAnsiChar; n: Int32);

{ memory }
function c_malloc(n: UInt64): Pointer;
function c_calloc(n, size: UInt64): Pointer;
function c_realloc(p: Pointer; n: UInt64): Pointer;
procedure c_free(p: Pointer);
function c_memset(p: Pointer; c: Int32; n: UInt64): Pointer;

{ stdio }
function c_fopen(name, mode: PAnsiChar): PCFile;
function c_fclose(f: PCFile): Int32;
function c_fflush(f: PCFile): Int32;
function c_feof(f: PCFile): Int32;
procedure c_rewind(f: PCFile);
function c_fseek(f: PCFile; off: Int64; whence: Int32): Int32;
function c_fseeko(f: PCFile; off: Int64; whence: Int32): Int32;
function c_ftell(f: PCFile): Int64;
function c_fgets(b: PAnsiChar; n: Int32; f: PCFile): PAnsiChar;
function c_fread(p: Pointer; size, n: UInt64; f: PCFile): UInt64;
function c_fwrite(p: Pointer; size, n: UInt64; f: PCFile): UInt64;
function c_remove(name: PAnsiChar): Int32;
function c_mkstemp(t: PAnsiChar): Int32;
function c_realpath(p, r: PAnsiChar): PAnsiChar;
function c_fprintf(f: PCFile; fmt: PAnsiChar; const args: array of const): Int32;
function c_snprintf(d: PAnsiChar; n: UInt64; fmt: PAnsiChar; const args: array of const): Int32;
function c_sscanf(s, fmt: PAnsiChar; const args: array of const): Int32;

{ time }
function c_time(t: PInt64): Int64;
function c_ctime(t: PInt64): PAnsiChar;
function c_difftime(a, b: Int64): Double;

{ for the command-line runner }
procedure c_conout(const s: AnsiString);

implementation

{ ================================================================ conversions }
{ Every real constant here is a typed Double: an untyped one is 80-bit Extended and Free Pascal would compare or
  compute with it on the x87 (lessons/23). As doubles, -2147483649.0 and -9223372036854775809.0 are what C's
  compiler makes of them (the second rounds to -2^63), so the tests below are the C runtime's. }
const
  I32_LO: Double = -2147483649.0;
  I32_HI: Double = 2147483648.0;
  I64_LO: Double = -9223372036854775809.0;
  I64_HI: Double = 9223372036854775808.0;
  BIG300: Double = 1e300;
  TINY300: Double = 1e-300;
  P22: Double = 1e22;

function D2I(x: Double): Int32; inline;
begin
  if not ((x > I32_LO) and (x < I32_HI)) then Exit(Low(Int32));
  Result := Int32(Trunc(x));
end;

function D2L(x: Double): Int64; inline;
begin
  if not ((x > I64_LO) and (x < I64_HI)) then Exit(Low(Int64));
  Result := Trunc(x);
end;

function D2U(x: Double): UInt32; inline;
begin
  Result := UInt32(D2L(x));
end;

const
  TWO63: Double = 9223372036854775808.0;

function D2UL(x: Double): UInt64; inline;
begin
  if x < TWO63 then Exit(UInt64(D2L(x)));
  Result := UInt64(D2L(x - TWO63)) xor UInt64($8000000000000000);
end;

function D2F(x: Double): Single; inline;
begin
  Result := x;
end;

function I2FD(x: Int64): Double; inline;
begin
  Result := x;
end;

function I2FS(x: Int64): Single; inline;
begin
  Result := x;
end;

function U2D(x: UInt64): Double;
var
  h: Double;
begin
  { gcc's sequence for (double) of an unsigned long }
  if Int64(x) >= 0 then Exit(Int64(x));
  h := Int64((x shr 1) or (x and 1));
  Result := h + h;
end;

function U2S(x: UInt64): Single;
var
  h: Single;
begin
  if Int64(x) >= 0 then Exit(Int64(x));
  h := Int64((x shr 1) or (x and 1));
  Result := h + h;
end;

function TernI32(c: Boolean; a, b: Int32): Int32; inline; begin if c then Result := a else Result := b; end;
function TernU32(c: Boolean; a, b: UInt32): UInt32; inline; begin if c then Result := a else Result := b; end;
function TernI64(c: Boolean; a, b: Int64): Int64; inline; begin if c then Result := a else Result := b; end;
function TernU64(c: Boolean; a, b: UInt64): UInt64; inline; begin if c then Result := a else Result := b; end;
function TernD(c: Boolean; a, b: Double): Double; inline; begin if c then Result := a else Result := b; end;
function TernF(c: Boolean; a, b: Single): Single; inline; begin if c then Result := a else Result := b; end;
function TernC(c: Boolean; a, b: AnsiChar): AnsiChar; inline; begin if c then Result := a else Result := b; end;
function TernP(c: Boolean; a, b: Pointer): Pointer; inline; begin if c then Result := a else Result := b; end;

generic function Asg<T>(var x: T; const v: T): T; inline;
begin
  x := v;
  Result := v;
end;

generic function PostInc<T>(var x: T): T; inline;
begin
  Result := x;
  Inc(x);
end;

generic function PostDec<T>(var x: T): T; inline;
begin
  Result := x;
  Dec(x);
end;

generic function PreInc<T>(var x: T): T; inline;
begin
  Inc(x);
  Result := x;
end;

generic function PreDec<T>(var x: T): T; inline;
begin
  Dec(x);
  Result := x;
end;

{ ================================================================ memory }
{ Every block is zero-filled (EPA reads nothing it has not written, except the matrix of lessons/02 defect 5,
  which this makes zero); a request for 0 bytes still gets a block, as glibc's calloc gives one. }
function c_malloc(n: UInt64): Pointer;
begin
  if n = 0 then n := 1;
  Result := AllocMem(PtrUInt(n));
end;

function c_calloc(n, size: UInt64): Pointer;
begin
  Result := c_malloc(n * size);
end;

function c_realloc(p: Pointer; n: UInt64): Pointer;
var
  old: PtrUInt;
begin
  if p = nil then Exit(c_malloc(n));
  if n = 0 then n := 1;
  old := MemSize(p);
  Result := p;
  ReallocMem(Result, PtrUInt(n));
  if PtrUInt(n) > old then FillChar(PByte(Result)[old], PtrUInt(n) - old, 0);
end;

procedure c_free(p: Pointer);
begin
  if p <> nil then FreeMem(p);
end;

function c_memset(p: Pointer; c: Int32; n: UInt64): Pointer;
begin
  FillChar(p^, PtrUInt(n), Byte(c));
  Result := p;
end;

{ ================================================================ strings }
function slen(p: PAnsiChar): PtrUInt; inline;
begin
  Result := 0;
  while p[Result] <> #0 do Inc(Result);
end;

function c_strlen(p: PAnsiChar): UInt64;
begin
  Result := slen(p);
end;

function c_strcpy(d, s: PAnsiChar): PAnsiChar;
var
  i, n: PtrUInt;
begin
  n := slen(s) + 1;
  i := 0;
  while i < n do
  begin
    d[i] := s[i];
    Inc(i);
  end;
  Result := d;
end;

function c_strcat(d, s: PAnsiChar): PAnsiChar;
begin
  c_strcpy(d + slen(d), s);
  Result := d;
end;

function c_strcmp(a, b: PAnsiChar): Int32;
var
  i: PtrUInt;
  x, y: Int32;
begin
  i := 0;
  while True do
  begin
    x := Ord(a[i]);
    y := Ord(b[i]);
    if x <> y then Exit(x - y);
    if x = 0 then Exit(0);
    Inc(i);
  end;
end;

function c_strchr(p: PAnsiChar; c: Int32): PAnsiChar;
var
  ch: AnsiChar;
  i: PtrUInt;
begin
  ch := AnsiChar(c);
  i := 0;
  while True do
  begin
    if p[i] = ch then Exit(p + i);
    if p[i] = #0 then Exit(nil);
    Inc(i);
  end;
end;

function c_strrchr(p: PAnsiChar; c: Int32): PAnsiChar;
var
  ch: AnsiChar;
  i, n: PtrUInt;
begin
  ch := AnsiChar(c);
  n := slen(p);
  if ch = #0 then Exit(p + n);
  i := n;
  while i > 0 do
  begin
    Dec(i);
    if p[i] = ch then Exit(p + i);
  end;
  Result := nil;
end;

function c_strstr(h, n: PAnsiChar): PAnsiChar;
var
  hl, nl, i, k: PtrUInt;
  ok: Boolean;
begin
  hl := slen(h);
  nl := slen(n);
  i := 0;
  while i + nl <= hl do
  begin
    ok := True;
    k := 0;
    while k < nl do
    begin
      if h[i + k] <> n[k] then
      begin
        ok := False;
        Break;
      end;
      Inc(k);
    end;
    if ok then Exit(h + i);
    Inc(i);
  end;
  Result := nil;
end;

function c_strcspn(p, rej: PAnsiChar): UInt64;
var
  n, m, i, k: PtrUInt;
begin
  n := slen(p);
  m := slen(rej);
  i := 0;
  while i < n do
  begin
    k := 0;
    while k < m do
    begin
      if p[i] = rej[k] then Exit(i);
      Inc(k);
    end;
    Inc(i);
  end;
  Result := n;
end;

var
  tok_next: PAnsiChar = nil;

function inSet(c: AnsiChar; s: PAnsiChar): Boolean;
var
  k: PtrUInt;
begin
  k := 0;
  while s[k] <> #0 do
  begin
    if s[k] = c then Exit(True);
    Inc(k);
  end;
  Result := False;
end;

function c_strtok(p, delim: PAnsiChar): PAnsiChar;
var
  b: PAnsiChar;
  i, st: PtrUInt;
begin
  if p <> nil then tok_next := p;
  b := tok_next;
  if b = nil then Exit(nil);
  i := 0;
  while (b[i] <> #0) and inSet(b[i], delim) do Inc(i);
  if b[i] = #0 then
  begin
    tok_next := nil;
    Exit(nil);
  end;
  st := i;
  while (b[i] <> #0) and not inSet(b[i], delim) do Inc(i);
  if b[i] <> #0 then
  begin
    b[i] := #0;
    tok_next := b + i + 1;
  end
  else
    tok_next := nil;
  Result := b + st;
end;

function c_toupper(c: Int32): Int32;
begin
  if (c >= Ord('a')) and (c <= Ord('z')) then Exit(c - 32);
  Result := c;
end;

procedure c_strinit(d, s: PAnsiChar; n: Int32);
var
  i: Int32;
  done: Boolean;
begin
  done := False;
  for i := 0 to n - 1 do
  begin
    if done then d[i] := #0
    else
    begin
      d[i] := s[i];
      if s[i] = #0 then done := True;
    end;
  end;
end;

function isSpace(c: Int32): Boolean; inline;
begin
  Result := (c = 32) or ((c >= 9) and (c <= 13));
end;

function low_(c: Int32): Int32; inline;
begin
  if (c >= Ord('A')) and (c <= Ord('Z')) then Result := c or $20 else Result := c;
end;

function isHex(c: Int32): Boolean; inline;
begin
  Result := ((c >= 48) and (c <= 57)) or ((c >= 65) and (c <= 70)) or ((c >= 97) and (c <= 102));
end;

function hexVal(c: Int32): Int32; inline;
begin
  if c <= 57 then Result := c - 48 else Result := low_(c) - 87;
end;

function c_atoi(p: PAnsiChar): Int32;
var
  i: PtrUInt;
  neg, over: Boolean;
  v, d: Int64;
begin
  { (int)strtol(s, NULL, 10): the low 32 bits of a long that saturates on overflow }
  i := 0;
  while (p[i] <> #0) and isSpace(Ord(p[i])) do Inc(i);
  neg := False;
  if (p[i] = '+') or (p[i] = '-') then
  begin
    neg := p[i] = '-';
    Inc(i);
  end;
  v := 0;
  over := False;
  while (p[i] >= '0') and (p[i] <= '9') do
  begin
    d := Ord(p[i]) - 48;
    if v > (High(Int64) - d) div 10 then over := True else v := v * 10 + d;
    Inc(i);
  end;
  if over then
  begin
    if neg then v := Low(Int64) else v := High(Int64);
  end
  else if neg then v := -v;
  Result := Int32(v);
end;

{ ================================================================ big integers (for printf and strtod) }
const
  BIGW = 160;
type
  TBig = record
    w: array[0..BIGW - 1] of UInt32;
    n: Int32;
  end;

procedure bigSet(var b: TBig; v: UInt64);
begin
  b.w[0] := UInt32(v);
  b.w[1] := UInt32(v shr 32);
  b.n := 2;
  while (b.n > 0) and (b.w[b.n - 1] = 0) do Dec(b.n);
end;

procedure bigTrim(var b: TBig); inline;
begin
  while (b.n > 0) and (b.w[b.n - 1] = 0) do Dec(b.n);
end;

procedure bigMulSmall(var b: TBig; m: UInt32);
var
  k: Int32;
  t, carry: UInt64;
begin
  carry := 0;
  for k := 0 to b.n - 1 do
  begin
    t := UInt64(b.w[k]) * m + carry;
    b.w[k] := UInt32(t);
    carry := t shr 32;
  end;
  if carry <> 0 then
  begin
    b.w[b.n] := UInt32(carry);
    Inc(b.n);
  end;
end;

procedure bigAddSmall(var b: TBig; a: UInt32);
var
  k: Int32;
  t: UInt64;
begin
  k := 0;
  t := a;
  while t <> 0 do
  begin
    if k >= b.n then
    begin
      b.w[k] := 0;
      b.n := k + 1;
    end;
    t := t + b.w[k];
    b.w[k] := UInt32(t);
    t := t shr 32;
    Inc(k);
  end;
end;

procedure bigMulPow5(var b: TBig; k: Int32);
begin
  while k >= 13 do
  begin
    bigMulSmall(b, 1220703125);
    Dec(k, 13);
  end;
  while k > 0 do
  begin
    bigMulSmall(b, 5);
    Dec(k);
  end;
end;

procedure bigShl(var b: TBig; k: Int32);
var
  ws, bs, i, src: Int32;
  hi, lo: UInt64;
begin
  if b.n = 0 then Exit;
  ws := k div 32;
  bs := k mod 32;
  i := b.n + ws + 1;
  while i > 0 do
  begin
    Dec(i);
    if i >= ws then
    begin
      src := i - ws;
      if src < b.n then hi := b.w[src] else hi := 0;
      if (src >= 1) and (src - 1 < b.n) then lo := b.w[src - 1] else lo := 0;
      b.w[i] := UInt32((((hi shl 32) or lo) shl bs) shr 32);
    end
    else
      b.w[i] := 0;
  end;
  b.n := b.n + ws + 1;
  bigTrim(b);
end;

function bigCmp(const a, b: TBig): Int32;
var
  i: Int32;
begin
  if a.n <> b.n then
  begin
    if a.n < b.n then Exit(-1) else Exit(1);
  end;
  i := a.n;
  while i > 0 do
  begin
    Dec(i);
    if a.w[i] <> b.w[i] then
    begin
      if a.w[i] < b.w[i] then Exit(-1) else Exit(1);
    end;
  end;
  Result := 0;
end;

function bigDivBillion(var b: TBig): UInt32;
var
  r, t: UInt64;
  i: Int32;
begin
  r := 0;
  i := b.n;
  while i > 0 do
  begin
    Dec(i);
    t := (r shl 32) or b.w[i];
    b.w[i] := UInt32(t div 1000000000);
    r := t mod 1000000000;
  end;
  bigTrim(b);
  Result := UInt32(r);
end;

{ decimal digits of b (most significant first) into d; returns the count (0 for zero) }
function bigToDec(var b: TBig; d: PByte): Int32;
var
  tmp: array[0..1599] of Byte;
  t, k: Int32;
  r: UInt32;
begin
  t := 0;
  while b.n > 0 do
  begin
    r := bigDivBillion(b);
    for k := 0 to 8 do
    begin
      tmp[t] := 48 + r mod 10;
      r := r div 10;
      Inc(t);
    end;
  end;
  while (t > 0) and (tmp[t - 1] = 48) do Dec(t);
  for k := 0 to t - 1 do d[k] := tmp[t - 1 - k];
  Result := t;
end;

{ ================================================================ strtod }
function bitsD(b: UInt64): Double; inline;
begin
  Result := PDoubleR(@b)^;
end;

type
  TScan = record
    v: Double;
    fv: Single;
    end_: Int64;
  end;

{ the value D * 5^e5 * 2^e2 (D: decimal or hexadecimal digits) against the exact binary value m * 2^k }
function cmpExact(const D: TBig; e5, e2: Int32; m: UInt64; k: Int32): Int32;
var
  L, Rb: TBig;
  c: Int32;
begin
  L := D;
  bigSet(Rb, m);
  if e5 >= 0 then bigMulPow5(L, e5) else bigMulPow5(Rb, -e5);
  c := e2 - k;
  if c >= 0 then bigShl(L, c) else bigShl(Rb, -c);
  Result := bigCmp(L, Rb);
end;

{ the correctly rounded binary value (mbits significant bits: 53 or 24) of D * 5^e5 * 2^e2, positive;
  returned as the bit pattern of a double (mbits = 53) or a float (24) }
function roundExact(const D: TBig; e5, e2, mbits: Int32; est: UInt64): UInt64;
var
  lo, hi, mid, top: UInt64;
  expbits, emin, c: Int32;

  procedure split(bits: UInt64; out m: UInt64; out k: Int32);
  var
    ex: Int32;
  begin
    if mbits = 53 then
    begin
      ex := Int32((bits shr 52) and $7FF);
      m := bits and ((UInt64(1) shl 52) - 1);
      if ex = 0 then k := -1074
      else
      begin
        m := m or (UInt64(1) shl 52);
        k := ex - 1075;
      end;
    end
    else
    begin
      ex := Int32((bits shr 23) and $FF);
      m := bits and ((UInt64(1) shl 23) - 1);
      if ex = 0 then k := -149
      else
      begin
        m := m or (UInt64(1) shl 23);
        k := ex - 150;
      end;
    end;
  end;

  { the value against the exact binary value of pattern b (b may be the infinity pattern: 2^maxexp) }
  function cmpBits(b: UInt64): Int32;
  var
    m: UInt64;
    k: Int32;
  begin
    if b >= top then
    begin
      if mbits = 53 then Exit(cmpExact(D, e5, e2, 1, 1024)) else Exit(cmpExact(D, e5, e2, 1, 128));
    end;
    split(b, m, k);
    Result := cmpExact(D, e5, e2, m, k);
  end;

  { the value against the midpoint between pattern b and b + 1 }
  function cmpMid(b: UInt64): Int32;
  var
    m: UInt64;
    k: Int32;
  begin
    split(b, m, k);
    if b + 1 >= top then
    begin
      { between the largest finite value and 2^maxexp }
      Exit(cmpExact(D, e5, e2, 2 * m + 1, k - 1));
    end;
    Result := cmpExact(D, e5, e2, 2 * m + 1, k - 1);
  end;

begin
  if mbits = 53 then top := UInt64($7FF0000000000000) else top := $7F800000;
  expbits := 0;
  emin := 0;
  { find lo = the largest pattern whose value is <= the number (0 <= lo < top), starting near the estimate }
  lo := 0;
  hi := top;
  if (est > 64) and (est + 64 < top) then
  begin
    if (cmpBits(est - 64) >= 0) and (cmpBits(est + 64) < 0) then
    begin
      lo := est - 64;
      hi := est + 64;
    end;
  end;
  if cmpBits(hi) >= 0 then lo := hi
  else
    while hi - lo > 1 do
    begin
      mid := lo + (hi - lo) div 2;
      if cmpBits(mid) >= 0 then lo := mid else hi := mid;
    end;
  if lo >= top then Exit(top);
  { round: the number lies in [value(lo), value(lo + 1)) }
  c := cmpMid(lo);
  if (c > 0) or ((c = 0) and (lo and 1 = 1)) then Inc(lo);
  Result := lo;
  if expbits = emin then ;
end;

const
  P10: array[0..22] of Double = (1e0, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12, 1e13, 1e14,
    1e15, 1e16, 1e17, 1e18, 1e19, 1e20, 1e21, 1e22);
  P10F: array[0..10] of Single = (1e0, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10);

{ a decimal number: digits dg[0..nd) (no point), value = digits * 10^e10; both precisions }
procedure decToFloat(dg: PByte; nd: Int32; e10: Int32; var sc: TScan);
var
  i, first, last: Int32;
  v: UInt64;
  D: TBig;
  dv: Double;
  fv: Single;
  est: UInt64;
  bits: UInt64;
  b32: UInt32;
begin
  first := 0;
  while (first < nd) and (dg[first] = 48) do Inc(first);
  last := nd;
  while (last > first) and (dg[last - 1] = 48) do
  begin
    Dec(last);
    Inc(e10);
  end;
  if last <= first then
  begin
    sc.v := 0;
    sc.fv := 0;
    Exit;
  end;
  nd := last - first;
  if nd + e10 > 330 then
  begin
    sc.v := bitsD($7FF0000000000000);
    PUInt32(@sc.fv)^ := $7F800000;
    Exit;
  end;
  if nd + e10 < -360 then
  begin
    sc.v := 0;
    sc.fv := 0;
    Exit;
  end;
  { exact fast paths (one correctly rounded operation on exactly representable operands) }
  if (nd <= 15) and (e10 >= -22) and (e10 <= 22) then
  begin
    v := 0;
    for i := first to last - 1 do v := v * 10 + (dg[i] - 48);
    dv := Int64(v);
    if e10 >= 0 then sc.v := dv * P10[e10] else sc.v := dv / P10[-e10];
    if (nd <= 7) and (e10 >= -10) and (e10 <= 10) then
    begin
      fv := Int64(v);
      if e10 >= 0 then sc.fv := fv * P10F[e10] else sc.fv := fv / P10F[-e10];
      Exit;
    end;
    sc.fv := 0;
    { float: exact path below }
    D.n := 0;
    for i := first to last - 1 do
    begin
      bigMulSmall(D, 10);
      bigAddSmall(D, dg[i] - 48);
    end;
    b32 := UInt32(roundExact(D, e10, e10, 24, 0));
    PUInt32(@sc.fv)^ := b32;
    Exit;
  end;
  D.n := 0;
  for i := first to last - 1 do
  begin
    bigMulSmall(D, 10);
    bigAddSmall(D, dg[i] - 48);
  end;
  { an estimate from the first 17 digits narrows the search }
  v := 0;
  for i := first to first + 16 do
    if i < last then v := v * 10 + (dg[i] - 48);
  est := 0;
  dv := Int64(v);
  i := e10 + (nd - 17);
  if nd < 17 then i := e10;
  while (i > 0) and (dv < BIG300) do
  begin
    if i >= 22 then
    begin
      dv := dv * P22;
      Dec(i, 22);
    end
    else
    begin
      dv := dv * P10[i];
      i := 0;
    end;
  end;
  while (i < 0) and (dv > TINY300) do
  begin
    if i <= -22 then
    begin
      dv := dv / P22;
      Inc(i, 22);
    end
    else
    begin
      dv := dv / P10[-i];
      i := 0;
    end;
  end;
  if (i = 0) and (dv > 0) then est := PQWord(@dv)^;
  bits := roundExact(D, e10, e10, 53, est);
  sc.v := PDoubleR(@bits)^;
  b32 := UInt32(roundExact(D, e10, e10, 24, 0));
  PUInt32(@sc.fv)^ := b32;
end;

{ a hexadecimal number: hex digits hd[0..n), value = digits * 2^e2 }
procedure hexToFloat(hd: PByte; n: Int32; e2: Int32; var sc: TScan);
var
  D: TBig;
  i, first, nz: Int32;
  bits: UInt64;
begin
  D.n := 0;
  nz := 0;
  first := 0;
  while (first < n) and (hd[first] = 0) do Inc(first);
  for i := first to n - 1 do
  begin
    bigMulSmall(D, 16);
    bigAddSmall(D, hd[i]);
    if hd[i] <> 0 then nz := 1;
  end;
  if nz = 0 then
  begin
    sc.v := 0;
    sc.fv := 0;
    Exit;
  end;
  if e2 > 2000 then
  begin
    sc.v := bitsD($7FF0000000000000);
    PUInt32(@sc.fv)^ := $7F800000;
    Exit;
  end;
  if e2 < -2000 - 4 * n then
  begin
    sc.v := 0;
    sc.fv := 0;
    Exit;
  end;
  bits := roundExact(D, 0, e2, 53, 0);
  sc.v := PDoubleR(@bits)^;
  PUInt32(@sc.fv)^ := UInt32(roundExact(D, 0, e2, 24, 0));
end;

function parsePayload(p: PAnsiChar; n: Int32; out res: UInt64): Boolean;
var
  i: Int32;
  base, v, d: UInt64;
  c: Int32;
begin
  { strtoull(seq, &end, 0) must consume the whole sequence }
  i := 0;
  base := 10;
  if (n >= 2) and (p[0] = '0') and (low_(Ord(p[1])) = Ord('x')) then
  begin
    base := 16;
    i := 2;
  end
  else if (n >= 1) and (p[0] = '0') then base := 8;
  v := 0;
  if i >= n then
  begin
    res := 0;
    Exit(base <> 16);
  end;
  while i < n do
  begin
    c := low_(Ord(p[i]));
    if (c >= 48) and (c <= 57) then d := c - 48
    else if (c >= 97) and (c <= 122) then d := c - 87
    else d := 99;
    if d >= base then Exit(False);
    v := v * base + d;
    Inc(i);
  end;
  res := v;
  Result := True;
end;

procedure negate(var sc: TScan; neg: Boolean);
begin
  if neg then
  begin
    PQWord(@sc.v)^ := PQWord(@sc.v)^ xor UInt64($8000000000000000);
    PUInt32(@sc.fv)^ := PUInt32(@sc.fv)^ xor $80000000;
  end;
end;

{ glibc's strtod syntax at b (at most maxw characters when maxw >= 0): sc.v (double), sc.fv (float, rounded
  once from the text, as strtof), sc.end_ (-1: no number) }
procedure scanDouble(b: PAnsiChar; maxw: Int64; skipSpace: Boolean; var sc: TScan);
var
  i, lim, k, j, e, ms, nd, q: Int64;
  neg, ok, any: Boolean;
  pl: UInt64;
  dg: array of Byte;
  ndg, e10, ex, esign, dot, nh, e2: Int64;
  bits: UInt64;

  function g(x: Int64): Int32;
  begin
    if x >= lim then Exit(0);
    Result := Ord(b[x]);
  end;

begin
  i := 0;
  if skipSpace then
    while (b[i] <> #0) and isSpace(Ord(b[i])) do Inc(i);
  if maxw >= 0 then lim := i + maxw else lim := High(Int64);
  sc.v := 0;
  sc.fv := 0;
  neg := False;
  if (g(i) = 43) or (g(i) = 45) then
  begin
    neg := g(i) = 45;
    Inc(i);
  end;
  if (low_(g(i)) = Ord('i')) and (low_(g(i + 1)) = Ord('n')) and (low_(g(i + 2)) = Ord('f')) then
  begin
    Inc(i, 3);
    if (low_(g(i)) = Ord('i')) and (low_(g(i + 1)) = Ord('n')) and (low_(g(i + 2)) = Ord('i')) and
      (low_(g(i + 3)) = Ord('t')) and (low_(g(i + 4)) = Ord('y')) then Inc(i, 5);
    PQWord(@sc.v)^ := $7FF0000000000000;
    PUInt32(@sc.fv)^ := $7F800000;
    negate(sc, neg);
    sc.end_ := i;
    Exit;
  end;
  if (low_(g(i)) = Ord('n')) and (low_(g(i + 1)) = Ord('a')) and (low_(g(i + 2)) = Ord('n')) then
  begin
    Inc(i, 3);
    if g(i) = 40 then
    begin
      k := i + 1;
      while True do
      begin
        q := g(k);
        if ((q >= 48) and (q <= 57)) or ((q >= 65) and (q <= 90)) or ((q >= 97) and (q <= 122)) or (q = 95) then
        begin
          Inc(k);
          Continue;
        end;
        Break;
      end;
      if g(k) = 41 then
      begin
        { glibc reads the n-char-sequence with strtoull(seq, 0) and keeps it as the payload }
        pl := 0;
        if k = i + 1 then ok := True else ok := parsePayload(b + i + 1, k - i - 1, pl);
        if ok then
        begin
          bits := UInt64($7FF8000000000000) or (pl and ((UInt64(1) shl 51) - 1));
          PQWord(@sc.v)^ := bits;
          PUInt32(@sc.fv)^ := $7FC00000 or UInt32(pl and ((1 shl 22) - 1));
          negate(sc, neg);
          sc.end_ := k + 1;
          Exit;
        end;
        i := k + 1;
      end;
    end;
    if neg then
    begin
      PQWord(@sc.v)^ := UInt64($FFF8000000000000);
      PUInt32(@sc.fv)^ := $FFC00000;
    end
    else
    begin
      PQWord(@sc.v)^ := $7FF8000000000000;
      PUInt32(@sc.fv)^ := $7FC00000;
    end;
    sc.end_ := i;
    Exit;
  end;
  if (g(i) = 48) and (low_(g(i + 1)) = Ord('x')) then
  begin
    { hexadecimal float (C99), as glibc reads it }
    j := i + 2;
    nh := 0;
    SetLength(dg, 0);
    dot := -1;
    while isHex(g(j)) do
    begin
      SetLength(dg, Length(dg) + 1);
      dg[High(dg)] := hexVal(g(j));
      Inc(j);
      Inc(nh);
    end;
    if g(j) = 46 then
    begin
      Inc(j);
      dot := Length(dg);
      while isHex(g(j)) do
      begin
        SetLength(dg, Length(dg) + 1);
        dg[High(dg)] := hexVal(g(j));
        Inc(j);
        Inc(nh);
      end;
    end;
    if nh > 0 then
    begin
      e2 := 0;
      if low_(g(j)) = Ord('p') then
      begin
        e := j + 1;
        esign := 1;
        if (g(e) = 43) or (g(e) = 45) then
        begin
          if g(e) = 45 then esign := -1;
          Inc(e);
        end;
        if (g(e) >= 48) and (g(e) <= 57) then
        begin
          ex := 0;
          while (g(e) >= 48) and (g(e) <= 57) do
          begin
            if ex < 100000 then ex := ex * 10 + g(e) - 48;
            Inc(e);
          end;
          e2 := esign * ex;
          j := e;
        end;
      end;
      if dot >= 0 then e2 := e2 - 4 * (Length(dg) - dot);
      hexToFloat(@dg[0], Length(dg), e2, sc);
      negate(sc, neg);
      sc.end_ := j;
      Exit;
    end;
  end;
  ms := i;
  nd := 0;
  SetLength(dg, 0);
  ndg := 0;
  e10 := 0;
  any := False;
  while (g(i) >= 48) and (g(i) <= 57) do
  begin
    if ndg >= Length(dg) then SetLength(dg, ndg * 2 + 32);
    dg[ndg] := g(i);
    Inc(ndg);
    Inc(i);
    Inc(nd);
  end;
  if g(i) = 46 then
  begin
    Inc(i);
    while (g(i) >= 48) and (g(i) <= 57) do
    begin
      if ndg >= Length(dg) then SetLength(dg, ndg * 2 + 32);
      dg[ndg] := g(i);
      Inc(ndg);
      Dec(e10);
      Inc(i);
      Inc(nd);
    end;
  end;
  if nd = 0 then
  begin
    sc.end_ := -1;
    Exit;
  end;
  if low_(g(i)) = Ord('e') then
  begin
    k := i + 1;
    esign := 1;
    if (g(k) = 43) or (g(k) = 45) then
    begin
      if g(k) = 45 then esign := -1;
      Inc(k);
    end;
    if (g(k) >= 48) and (g(k) <= 57) then
    begin
      ex := 0;
      while (g(k) >= 48) and (g(k) <= 57) do
      begin
        if ex < 100000 then ex := ex * 10 + g(k) - 48;
        Inc(k);
      end;
      e10 := e10 + esign * ex;
      i := k;
    end;
  end;
  if ndg = 0 then SetLength(dg, 1);
  if e10 > 100000 then e10 := 100000;
  if e10 < -100000 then e10 := -100000;
  decToFloat(@dg[0], ndg, e10, sc);
  negate(sc, neg);
  sc.end_ := i;
  if any or (ms < 0) then ;
end;

function c_strtod(p: PAnsiChar; endp: PPAnsiChar): Double;
var
  sc: TScan;
begin
  scanDouble(p, -1, True, sc);
  if endp <> nil then
  begin
    if sc.end_ < 0 then endp^ := p else endp^ := p + sc.end_;
  end;
  if sc.end_ < 0 then Exit(0);
  Result := sc.v;
end;

function c_atof(p: PAnsiChar): Double;
begin
  Result := c_strtod(p, nil);
end;

{ ================================================================ sscanf }
{ The targets' types come from the format, as in C: %d int*, %ld long*, %hd short*, %u unsigned*, %f float*,
  %lf double*, %s and %c char*. }
function c_sscanf(s, fmt: PAnsiChar; const args: array of const): Int32;
var
  i, j, k, ds, lim, nf, w, m, t, cnt: Int64;
  ai: Int32;
  count: Int32;
  anyInput, suppress, neg, over: Boolean;
  width: Int64;
  lmod, hmod: Int32;
  conv, fc: Int32;
  v, d: Int64;
  sc: TScan;
  dst: PAnsiChar;

  function arg(n: Int32): Pointer;
  begin
    case args[n].VType of
      vtPointer: Result := args[n].VPointer;
      vtPChar: Result := args[n].VPChar;
    else
      Result := nil;
    end;
  end;

begin
  i := 0;
  k := 0;
  ai := 0;
  count := 0;
  anyInput := False;
  nf := slen(fmt);
  while k < nf do
  begin
    fc := Ord(fmt[k]);
    if isSpace(fc) then
    begin
      while (k < nf) and isSpace(Ord(fmt[k])) do Inc(k);
      while (s[i] <> #0) and isSpace(Ord(s[i])) do Inc(i);
      Continue;
    end;
    if fc <> 37 then
    begin
      if s[i] = #0 then
      begin
        if anyInput or (count > 0) then Exit(count) else Exit(-1);
      end;
      if Ord(s[i]) <> fc then Exit(count);
      Inc(i);
      Inc(k);
      Continue;
    end;
    Inc(k);
    if fmt[k] = '%' then
    begin
      while (s[i] <> #0) and isSpace(Ord(s[i])) do Inc(i);
      if s[i] <> '%' then Exit(count);
      Inc(i);
      Inc(k);
      Continue;
    end;
    suppress := False;
    if fmt[k] = '*' then
    begin
      suppress := True;
      Inc(k);
    end;
    width := 0;
    while (k < nf) and (fmt[k] >= '0') and (fmt[k] <= '9') do
    begin
      width := width * 10 + Ord(fmt[k]) - 48;
      Inc(k);
    end;
    lmod := 0;
    hmod := 0;
    while (k < nf) and ((fmt[k] = 'l') or (fmt[k] = 'h') or (fmt[k] = 'L')) do
    begin
      if fmt[k] = 'h' then Inc(hmod) else Inc(lmod);
      Inc(k);
    end;
    conv := Ord(fmt[k]);
    Inc(k);
    if (conv <> Ord('c')) and (conv <> Ord('[')) and (conv <> Ord('n')) then
      while (s[i] <> #0) and isSpace(Ord(s[i])) do Inc(i);
    if (s[i] = #0) and (conv <> Ord('n')) then
    begin
      if (count = 0) and not anyInput then Exit(-1) else Exit(count);
    end;
    case conv of
      Ord('d'), Ord('i'), Ord('u'):
        begin
          j := i;
          if width <> 0 then lim := i + width else lim := High(Int64);
          neg := False;
          if (j < lim) and ((s[j] = '+') or (s[j] = '-')) then
          begin
            neg := s[j] = '-';
            Inc(j);
          end;
          ds := j;
          v := 0;
          over := False;
          while (j < lim) and (s[j] >= '0') and (s[j] <= '9') do
          begin
            d := Ord(s[j]) - 48;
            if v > (High(Int64) - d) div 10 then over := True else v := v * 10 + d;
            Inc(j);
          end;
          if j = ds then Exit(count);
          i := j;
          anyInput := True;
          if over then
          begin
            if neg then v := Low(Int64) else v := High(Int64);
          end
          else if neg then v := -v;
          if not suppress then
          begin
            if lmod > 0 then PInt64(arg(ai))^ := v
            else if hmod > 0 then PSmallInt(arg(ai))^ := SmallInt(v)
            else PInt32(arg(ai))^ := Int32(v);
            Inc(ai);
            Inc(count);
          end;
        end;
      Ord('f'), Ord('e'), Ord('g'):
        begin
          if width <> 0 then w := width else w := -1;
          scanDouble(s + i, w, False, sc);
          if sc.end_ < 0 then Exit(count);
          i := i + sc.end_;
          anyInput := True;
          if not suppress then
          begin
            if lmod > 0 then PDoubleR(arg(ai))^ := sc.v else PSingleR(arg(ai))^ := sc.fv;
            Inc(ai);
            Inc(count);
          end;
        end;
      Ord('s'):
        begin
          j := i;
          if width <> 0 then w := width else w := High(Int64);
          m := 0;
          while (s[j] <> #0) and not isSpace(Ord(s[j])) and (m < w) do
          begin
            Inc(j);
            Inc(m);
          end;
          if not suppress then
          begin
            dst := PAnsiChar(arg(ai));
            Inc(ai);
            for t := 0 to m - 1 do dst[t] := s[i + t];
            dst[m] := #0;
            Inc(count);
          end;
          i := j;
          anyInput := True;
        end;
      Ord('c'):
        begin
          if width <> 0 then cnt := width else cnt := 1;
          if s[i] = #0 then
          begin
            if (count = 0) and not anyInput then Exit(-1) else Exit(count);
          end;
          dst := nil;
          if not suppress then
          begin
            dst := PAnsiChar(arg(ai));
            Inc(ai);
          end;
          t := 0;
          while (t < cnt) and (s[i] <> #0) do
          begin
            if not suppress then dst[t] := s[i];
            Inc(i);
            Inc(t);
          end;
          anyInput := True;
          if not suppress then Inc(count);
        end;
    else
      begin
        c_conout('sscanf: unsupported conversion'#10);
        Halt(3);
      end;
    end;
  end;
  Result := count;
end;

{ ================================================================ printf }
type
  TOut = record
    b: array of Byte;
    n: Int64;
  end;

procedure oput(var o: TOut; c: Byte); inline;
begin
  if o.n >= Length(o.b) then SetLength(o.b, Length(o.b) * 2 + 256);
  o.b[o.n] := c;
  Inc(o.n);
end;

procedure oputs(var o: TOut; p: PByte; n: Int64);
var
  k: Int64;
begin
  for k := 0 to n - 1 do oput(o, p[k]);
end;

procedure oputstr(var o: TOut; const s: AnsiString);
var
  k: Int64;
begin
  for k := 1 to Length(s) do oput(o, Ord(s[k]));
end;

procedure opad(var o: TOut; c: Byte; k: Int64);
begin
  while k > 0 do
  begin
    oput(o, c);
    Dec(k);
  end;
end;

{ the exact decimal expansion of a positive finite double: d[0..n) with the point after d[0..p) (p >= 1) }
type
  TDigits = record
    d: array[0..1599] of Byte;
    n, p: Int32;
  end;

procedure exactDigits(v: Double; var dg: TDigits);
var
  bits, m, ip, fp: UInt64;
  ex, e, k, ilen, fl, lead, t, q: Int32;
  b: TBig;
  fd: array[0..1299] of Byte;
begin
  bits := PQWord(@v)^;
  ex := Int32((bits shr 52) and $7FF);
  m := bits and ((UInt64(1) shl 52) - 1);
  if ex = 0 then e := -1074
  else
  begin
    e := ex - 1075;
    m := m or (UInt64(1) shl 52);
  end;
  if e >= 0 then
  begin
    bigSet(b, m);
    bigShl(b, e);
    k := bigToDec(b, @dg.d[0]);
    dg.n := k;
    dg.p := k;
    if k = 0 then
    begin
      dg.d[0] := 48;
      dg.n := 1;
      dg.p := 1;
    end;
    Exit;
  end;
  k := -e;
  if k < 64 then
  begin
    ip := m shr k;
    fp := m and ((UInt64(1) shl k) - 1);
  end
  else
  begin
    ip := 0;
    fp := m;
  end;
  bigSet(b, ip);
  ilen := bigToDec(b, @dg.d[0]);
  if ilen = 0 then
  begin
    dg.d[0] := 48;
    ilen := 1;
  end;
  dg.p := ilen;
  { fraction: fp / 2^k = fp * 5^k / 10^k, k digits }
  bigSet(b, fp);
  bigMulPow5(b, k);
  fl := bigToDec(b, @fd[0]);
  lead := k - fl;
  t := ilen;
  for q := 1 to lead do
  begin
    dg.d[t] := 48;
    Inc(t);
  end;
  for q := 0 to fl - 1 do
  begin
    dg.d[t] := fd[q];
    Inc(t);
  end;
  while (t > ilen) and (dg.d[t - 1] = 48) do Dec(t);
  dg.n := t;
end;

{ round d[0..n) to its first keep digits, half to even on the exact value; true if the carry ran off the front }
function roundDigits(d: PByte; n, keep: Int32): Boolean;
var
  k: Int32;
  up, rest: Boolean;
  nx: Byte;
begin
  Result := False;
  if keep >= n then
  begin
    for k := n to keep - 1 do d[k] := 48;
    Exit;
  end;
  nx := d[keep];
  up := False;
  if nx > 53 then up := True
  else if nx = 53 then
  begin
    rest := False;
    for k := keep + 1 to n - 1 do
      if d[k] <> 48 then
      begin
        rest := True;
        Break;
      end;
    if rest then up := True
    else up := (keep > 0) and (((d[keep - 1] - 48) mod 2) = 1);
  end;
  if not up then Exit;
  k := keep;
  while k > 0 do
  begin
    Dec(k);
    if d[k] = 57 then d[k] := 48
    else
    begin
      Inc(d[k]);
      Exit;
    end;
  end;
  Result := True;
end;

procedure fixedDigits(var o: TOut; a: Double; prec: Int32; alt: Boolean);
var
  dg: TDigits;
  w: array[0..1699] of Byte;
  keep, p, k: Int32;
begin
  exactDigits(a, dg);
  keep := dg.p + prec;
  if keep > 1690 then keep := 1690;
  for k := 0 to dg.n - 1 do w[k + 1] := dg.d[k];
  p := dg.p;
  if roundDigits(@w[1], dg.n, keep) then
  begin
    w[0] := 49;
    oputs(o, @w[0], p + 1);
  end
  else
    oputs(o, @w[1], p);
  if (prec > 0) or alt then oput(o, 46);
  oputs(o, @w[1 + p], keep - p);
end;

{ the digits of a positive finite value rounded to sig significant digits; returns the decimal exponent }
function expRaw(a: Double; sig: Int32; res: PByte): Int32;
var
  dg: TDigits;
  f, x, n, k: Int32;
  w: array[0..1699] of Byte;
begin
  exactDigits(a, dg);
  f := 0;
  while (f < dg.n) and (dg.d[f] = 48) do Inc(f);
  x := dg.p - 1 - f;
  n := dg.n - f;
  for k := 0 to n - 1 do w[k] := dg.d[f + k];
  if roundDigits(@w[0], n, sig) then
  begin
    res[0] := 49;
    for k := 1 to sig - 1 do res[k] := 48;
    Inc(x);
  end
  else
    for k := 0 to sig - 1 do res[k] := w[k];
  Result := x;
end;

procedure expDigits(var o: TOut; a: Double; prec: Int32; alt, upper: Boolean);
var
  d: array[0..1699] of Byte;
  x, k: Int32;
  xs: AnsiString;
begin
  x := 0;
  if a = 0 then
  begin
    for k := 0 to prec do d[k] := 48;
  end
  else
    x := expRaw(a, prec + 1, @d[0]);
  oput(o, d[0]);
  if prec > 0 then
  begin
    oput(o, 46);
    oputs(o, @d[1], prec);
  end
  else if alt then oput(o, 46);
  if upper then oput(o, Ord('E')) else oput(o, Ord('e'));
  if x < 0 then
  begin
    oput(o, Ord('-'));
    x := -x;
  end
  else
    oput(o, Ord('+'));
  Str(x, xs);
  if x < 10 then oput(o, 48);
  oputstr(o, xs);
end;

procedure formatFloat(var o: TOut; a: Double; conv: AnsiChar; prec: Int32; alt: Boolean);
var
  P, X, k, ep, e: Int32;
  d: array[0..1699] of Byte;
  sub: TOut;
  hasPoint: Boolean;
begin
  if (conv = 'f') or (conv = 'F') then
  begin
    fixedDigits(o, a, prec, alt);
    Exit;
  end;
  if (conv = 'e') or (conv = 'E') then
  begin
    expDigits(o, a, prec, alt, conv = 'E');
    Exit;
  end;
  if prec = 0 then P := 1 else P := prec;
  X := 0;
  if a <> 0 then X := expRaw(a, P, @d[0]);
  sub.n := 0;
  SetLength(sub.b, 64);
  if (P > X) and (X >= -4) then fixedDigits(sub, a, P - 1 - X, alt)
  else expDigits(sub, a, P - 1, alt, conv = 'G');
  if not alt then
  begin
    ep := sub.n;
    for k := 0 to sub.n - 1 do
      if (sub.b[k] = Ord('e')) or (sub.b[k] = Ord('E')) then
      begin
        ep := k;
        Break;
      end;
    hasPoint := False;
    for k := 0 to ep - 1 do
      if sub.b[k] = 46 then hasPoint := True;
    e := ep;
    if hasPoint then
    begin
      while (e > 0) and (sub.b[e - 1] = 48) do Dec(e);
      if (e > 0) and (sub.b[e - 1] = 46) then Dec(e);
    end;
    oputs(o, @sub.b[0], e);
    if ep < sub.n then oputs(o, @sub.b[ep], sub.n - ep);
    Exit;
  end;
  oputs(o, @sub.b[0], sub.n);
end;

function argLong(const a: TVarRec; out int32: Boolean): Int64;
begin
  int32 := False;
  case a.VType of
    vtInteger:
      begin
        int32 := True;
        Result := a.VInteger;
      end;
    vtInt64: Result := a.VInt64^;
    vtQWord: Result := Int64(a.VQWord^);
    vtChar: Result := Ord(a.VChar);
    vtBoolean: Result := Ord(a.VBoolean);
    vtExtended: Result := D2L(Double(a.VExtended^));
    vtPointer: Result := Int64(PtrUInt(a.VPointer));
    vtPChar: Result := Int64(PtrUInt(a.VPChar));
  else
    Result := 0;
  end;
end;

function argDouble(const a: TVarRec): Double;
var
  b: Boolean;
begin
  case a.VType of
    vtExtended: Result := Double(a.VExtended^);
  else
    Result := argLong(a, b);
  end;
end;

procedure intBody(var o: TOut; u: UInt64; base: UInt64; upper: Boolean; prec: Int32);
var
  tmp: array[0..69] of Byte;
  t, k: Int32;
  digs: AnsiString;
begin
  if upper then digs := '0123456789ABCDEF' else digs := '0123456789abcdef';
  t := 0;
  while u <> 0 do
  begin
    tmp[t] := Ord(digs[1 + Int32(u mod base)]);
    u := u div base;
    Inc(t);
  end;
  if prec < 0 then
  begin
    if t = 0 then
    begin
      tmp[0] := 48;
      t := 1;
    end;
  end
  else
    while t < prec do
    begin
      tmp[t] := 48;
      Inc(t);
    end;
  k := t;
  while k > 0 do
  begin
    Dec(k);
    oput(o, tmp[k]);
  end;
end;

procedure format(var o: TOut; fmt: PAnsiChar; const args: array of const);
var
  k, ai: Int64;
  left, plus, space, alt, zero, numeric, is32: Boolean;
  width, prec: Int64;
  conv: AnsiChar;
  sign: AnsiString;
  body: TOut;
  v: Int64;
  u: UInt64;
  base: UInt64;
  p: PAnsiChar;
  sl, n: Int64;
  dv: Double;
  bitsv: UInt64;
  pr: Int32;
begin
  k := 0;
  ai := 0;
  while fmt[k] <> #0 do
  begin
    if fmt[k] <> '%' then
    begin
      oput(o, Ord(fmt[k]));
      Inc(k);
      Continue;
    end;
    Inc(k);
    if fmt[k] = '%' then
    begin
      oput(o, 37);
      Inc(k);
      Continue;
    end;
    left := False;
    plus := False;
    space := False;
    alt := False;
    zero := False;
    while True do
    begin
      case fmt[k] of
        '-': left := True;
        '+': plus := True;
        ' ': space := True;
        '#': alt := True;
        '0': zero := True;
      else
        Break;
      end;
      Inc(k);
    end;
    width := 0;
    prec := -1;
    if fmt[k] = '*' then
    begin
      v := argLong(args[ai], is32);
      Inc(ai);
      if v < 0 then
      begin
        left := True;
        width := -v;
      end
      else
        width := v;
      Inc(k);
    end
    else
      while (fmt[k] >= '0') and (fmt[k] <= '9') do
      begin
        width := width * 10 + Ord(fmt[k]) - 48;
        Inc(k);
      end;
    if fmt[k] = '.' then
    begin
      Inc(k);
      prec := 0;
      if fmt[k] = '*' then
      begin
        v := argLong(args[ai], is32);
        Inc(ai);
        if v < 0 then prec := -1 else prec := v;
        Inc(k);
      end
      else
        while (fmt[k] >= '0') and (fmt[k] <= '9') do
        begin
          prec := prec * 10 + Ord(fmt[k]) - 48;
          Inc(k);
        end;
    end;
    while fmt[k] in ['l', 'h', 'L', 'z', 'j', 't', 'q'] do Inc(k);
    conv := fmt[k];
    Inc(k);
    sign := '';
    body.n := 0;
    SetLength(body.b, 64);
    numeric := True;
    case conv of
      'd', 'i':
        begin
          v := argLong(args[ai], is32);
          Inc(ai);
          if v < 0 then sign := '-' else if plus then sign := '+' else if space then sign := ' ';
          if v < 0 then u := UInt64(-v) else u := UInt64(v);
          intBody(body, u, 10, False, Int32(prec));
          if prec >= 0 then zero := False;
        end;
      'u', 'x', 'X', 'o':
        begin
          v := argLong(args[ai], is32);
          Inc(ai);
          u := UInt64(v);
          if is32 then u := u and $FFFFFFFF;
          case conv of
            'u': base := 10;
            'o': base := 8;
          else
            base := 16;
          end;
          intBody(body, u, base, conv = 'X', Int32(prec));
          if prec >= 0 then zero := False;
        end;
      'c':
        begin
          numeric := False;
          v := argLong(args[ai], is32);
          Inc(ai);
          oput(body, Byte(v));
        end;
      's':
        begin
          numeric := False;
          p := nil;
          case args[ai].VType of
            vtPChar: p := args[ai].VPChar;
            vtPointer: p := PAnsiChar(args[ai].VPointer);
          end;
          Inc(ai);
          if p = nil then oputstr(body, '(null)')
          else
          begin
            sl := slen(p);
            if (prec >= 0) and (sl > prec) then sl := prec;
            oputs(body, PByte(p), sl);
          end;
          if (p = nil) and (prec >= 0) and (body.n > prec) then body.n := prec;
        end;
      'f', 'F', 'e', 'E', 'g', 'G':
        begin
          dv := argDouble(args[ai]);
          Inc(ai);
          if prec < 0 then pr := 6 else pr := Int32(prec);
          bitsv := PQWord(@dv)^;
          if (bitsv shr 63) <> 0 then sign := '-' else if plus then sign := '+' else if space then sign := ' ';
          if (bitsv and $7FF0000000000000) = $7FF0000000000000 then
          begin
            if (bitsv and $000FFFFFFFFFFFFF) <> 0 then
            begin
              if conv in ['F', 'E', 'G'] then oputstr(body, 'NAN') else oputstr(body, 'nan');
            end
            else if conv in ['F', 'E', 'G'] then oputstr(body, 'INF') else oputstr(body, 'inf');
            zero := False;
          end
          else
          begin
            bitsv := bitsv and $7FFFFFFFFFFFFFFF;
            dv := PDoubleR(@bitsv)^;
            formatFloat(body, dv, conv, pr, alt);
          end;
        end;
    else
      begin
        c_conout('printf: unsupported conversion'#10);
        Halt(3);
      end;
    end;
    n := Length(sign) + body.n;
    if n >= width then
    begin
      oputstr(o, sign);
      oputs(o, @body.b[0], body.n);
    end
    else if left then
    begin
      oputstr(o, sign);
      oputs(o, @body.b[0], body.n);
      opad(o, 32, width - n);
    end
    else if zero and numeric then
    begin
      oputstr(o, sign);
      opad(o, 48, width - n);
      oputs(o, @body.b[0], body.n);
    end
    else
    begin
      opad(o, 32, width - n);
      oputstr(o, sign);
      oputs(o, @body.b[0], body.n);
    end;
  end;
end;

{ ================================================================ stdio }
const
  BUFSZ = 1 shl 16;

var
  stdoutRec: TCFile;

procedure die(const msg: AnsiString);
begin
  FpWrite(2, PAnsiChar(msg), Length(msg));
  Halt(3);
end;

procedure writeAll(f: PCFile; b: PByte; n: Int64; at: Int64);
var
  done, r: Int64;
begin
  done := 0;
  while done < n do
  begin
    { the PChar overloads: an untyped-var overload would take the address of the pointer itself }
    if f^.isstd <> 0 then r := FpWrite(f^.fd, PAnsiChar(b + done), n - done)
    else r := FpPWrite(f^.fd, PAnsiChar(b + done), n - done, at + done);
    if r <= 0 then die('write error'#10);
    done := done + r;
  end;
end;

procedure flushW(f: PCFile);
begin
  if f^.wlen = 0 then Exit;
  writeAll(f, f^.wbuf, f^.wlen, f^.wpos);
  f^.wlen := 0;
end;

function fsize(f: PCFile): Int64;
begin
  flushW(f);
  Result := FpLseek(f^.fd, 0, Seek_End);
end;

procedure fwriteBytes(f: PCFile; src: PByte; n: Int64);
begin
  f^.rlen := 0;
  if f^.wbuf = nil then f^.wbuf := GetMem(BUFSZ);
  if (f^.append <> 0) and (f^.isstd = 0) then
  begin
    flushW(f);
    f^.pos := fsize(f);
  end;
  if (f^.wlen > 0) and (f^.pos <> f^.wpos + f^.wlen) then flushW(f);
  if f^.wlen = 0 then f^.wpos := f^.pos;
  if f^.wlen + n > BUFSZ then
  begin
    flushW(f);
    if n > BUFSZ then
    begin
      writeAll(f, src, n, f^.pos);
      f^.pos := f^.pos + n;
      Exit;
    end;
    f^.wpos := f^.pos;
  end;
  Move(src^, f^.wbuf[f^.wlen], n);
  f^.wlen := f^.wlen + n;
  f^.pos := f^.pos + n;
end;

function readBytes(f: PCFile; dst: PByte; n: Int64): Int64;
var
  got, a, m, r: Int64;
begin
  flushW(f);
  got := 0;
  while got < n do
  begin
    if (f^.rlen > 0) and (f^.pos >= f^.rstart) and (f^.pos < f^.rstart + f^.rlen) then
    begin
      a := f^.pos - f^.rstart;
      m := n - got;
      if m > f^.rlen - a then m := f^.rlen - a;
      Move(f^.rbuf[a], dst[got], m);
      got := got + m;
      f^.pos := f^.pos + m;
      Continue;
    end;
    if f^.rbuf = nil then f^.rbuf := GetMem(BUFSZ);
    f^.rstart := f^.pos;
    r := FpPRead(f^.fd, PAnsiChar(f^.rbuf), BUFSZ, f^.pos);
    if r > 0 then f^.rlen := r else f^.rlen := 0;
    if r <= 0 then Break;
  end;
  Result := got;
end;

function getc(f: PCFile): Int32; inline;
var
  t: Byte;
begin
  if (f^.wlen = 0) and (f^.rlen > 0) and (f^.pos >= f^.rstart) and (f^.pos < f^.rstart + f^.rlen) then
  begin
    Result := f^.rbuf[f^.pos - f^.rstart];
    Inc(f^.pos);
    Exit;
  end;
  if readBytes(f, @t, 1) = 1 then Exit(t);
  Result := -1;
end;

function c_fopen(name, mode: PAnsiChar): PCFile;
var
  m: array[0..7] of AnsiChar;
  ml, k: Int32;
  plus: Boolean;
  flags: cint;
  fd: cint;
  f: PCFile;
begin
  ml := 0;
  k := 0;
  while (mode[k] <> #0) and (ml < 8) do
  begin
    if (mode[k] <> 'b') and (mode[k] <> 't') then
    begin
      m[ml] := mode[k];
      Inc(ml);
    end;
    Inc(k);
  end;
  if ml = 0 then Exit(nil);
  plus := (ml > 1) and (m[1] = '+');
  case m[0] of
    'r': if plus then flags := O_RDWR else flags := O_RDONLY;
    'w': if plus then flags := O_RDWR or O_CREAT or O_TRUNC else flags := O_WRONLY or O_CREAT or O_TRUNC;
    'a': if plus then flags := O_RDWR or O_CREAT or O_APPEND else flags := O_WRONLY or O_CREAT or O_APPEND;
  else
    Exit(nil);
  end;
  fd := FpOpen(name, flags, &666);
  if fd < 0 then Exit(nil);
  f := AllocMem(SizeOf(TCFile));
  f^.fd := fd;
  if m[0] = 'a' then
  begin
    f^.append := 1;
    f^.pos := FpLseek(fd, 0, Seek_End);
  end;
  Result := f;
end;

function c_fclose(f: PCFile): Int32;
var
  r: cint;
begin
  if f = nil then Exit(-1);
  flushW(f);
  if f^.isstd <> 0 then Exit(0);
  r := FpClose(f^.fd);
  if f^.wbuf <> nil then FreeMem(f^.wbuf);
  if f^.rbuf <> nil then FreeMem(f^.rbuf);
  FreeMem(f);
  if r = 0 then Result := 0 else Result := -1;
end;

function c_fflush(f: PCFile): Int32;
begin
  if f <> nil then flushW(f);
  Result := 0;
end;

function c_feof(f: PCFile): Int32;
begin
  if f^.eof <> 0 then Result := 1 else Result := 0;
end;

procedure c_rewind(f: PCFile);
begin
  flushW(f);
  f^.pos := 0;
  f^.eof := 0;
end;

function c_fseek(f: PCFile; off: Int64; whence: Int32): Int32;
var
  p: Int64;
begin
  flushW(f);
  p := off;
  if whence = 1 then p := f^.pos + off
  else if whence = 2 then p := fsize(f) + off;
  if p < 0 then Exit(-1);
  f^.pos := p;
  f^.eof := 0;
  Result := 0;
end;

function c_fseeko(f: PCFile; off: Int64; whence: Int32): Int32;
begin
  Result := c_fseek(f, off, whence);
end;

function c_ftell(f: PCFile): Int64;
begin
  Result := f^.pos;
end;

function c_fgets(b: PAnsiChar; n: Int32; f: PCFile): PAnsiChar;
var
  m: Int64;
  c: Int32;
begin
  m := 0;
  while m < Int64(n) - 1 do
  begin
    c := getc(f);
    if c < 0 then
    begin
      f^.eof := 1;
      Break;
    end;
    b[m] := AnsiChar(c);
    Inc(m);
    if c = 10 then Break;
  end;
  if m = 0 then Exit(nil);
  b[m] := #0;
  Result := b;
end;

{ fread: the bytes go straight into the caller's memory, as C's do (a short read fills part of an item) }
function c_fread(p: Pointer; size, n: UInt64; f: PCFile): UInt64;
var
  total, got: Int64;
begin
  total := Int64(size * n);
  if total = 0 then Exit(0);
  got := readBytes(f, PByte(p), total);
  if got < total then f^.eof := 1;
  Result := UInt64(got) div size;
end;

function c_fwrite(p: Pointer; size, n: UInt64; f: PCFile): UInt64;
var
  total: Int64;
begin
  total := Int64(size * n);
  if total = 0 then Exit(0);
  fwriteBytes(f, PByte(p), total);
  Result := n;
end;

function c_remove(name: PAnsiChar): Int32;
begin
  if FpUnlink(name) = 0 then Result := 0 else Result := -1;
end;

var
  rndState: UInt64 = 0;

{ mkstemp: six random characters, created exclusively (the descriptor stays open, as EPA leaves it) }
function c_mkstemp(t: PAnsiChar): Int32;
const
  chars: AnsiString = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
var
  n, i, tries: Int64;
  fd: cint;
begin
  if rndState = 0 then rndState := (UInt64(FpTime) shl 20) xor UInt64(FpGetpid) or 1;
  n := slen(t);
  if n < 6 then Exit(-1);
  for tries := 1 to 1000 do
  begin
    for i := n - 6 to n - 1 do
    begin
      rndState := rndState xor (rndState shl 13);
      rndState := rndState xor (rndState shr 7);
      rndState := rndState xor (rndState shl 17);
      t[i] := chars[1 + Int32(rndState mod UInt64(Length(chars)))];
    end;
    fd := FpOpen(t, O_RDWR or O_CREAT or O_EXCL, &600);
    if fd >= 0 then Exit(fd);
  end;
  Result := -1;
end;

{ realpath: the current directory joined to a relative path, with "." and ".." removed }
function c_realpath(p, r: PAnsiChar): PAnsiChar;
var
  src, outs, comp: AnsiString;
  cwd: array[0..8191] of AnsiChar;
  i, st: Int64;
begin
  src := '';
  if (p[0] <> '/') then
  begin
    if FpGetcwd(@cwd[0], SizeOf(cwd)) = nil then Exit(nil);
    src := AnsiString(PAnsiChar(@cwd[0])) + '/';
  end;
  src := src + AnsiString(p);
  outs := '';
  i := 1;
  while i <= Length(src) do
  begin
    while (i <= Length(src)) and (src[i] = '/') do Inc(i);
    st := i;
    while (i <= Length(src)) and (src[i] <> '/') do Inc(i);
    comp := Copy(src, st, i - st);
    if (comp = '') or (comp = '.') then Continue;
    if comp = '..' then
    begin
      while (Length(outs) > 0) and (outs[Length(outs)] <> '/') do SetLength(outs, Length(outs) - 1);
      if Length(outs) > 0 then SetLength(outs, Length(outs) - 1);
      Continue;
    end;
    outs := outs + '/' + comp;
  end;
  if outs = '' then outs := '/';
  for i := 1 to Length(outs) do r[i - 1] := outs[i];
  r[Length(outs)] := #0;
  Result := r;
end;

function c_fprintf(f: PCFile; fmt: PAnsiChar; const args: array of const): Int32;
var
  o: TOut;
begin
  o.n := 0;
  SetLength(o.b, 256);
  format(o, fmt, args);
  if f = nil then Exit(-1);
  if o.n > 0 then fwriteBytes(f, @o.b[0], o.n);
  Result := Int32(o.n);
end;

function c_snprintf(d: PAnsiChar; n: UInt64; fmt: PAnsiChar; const args: array of const): Int32;
var
  o: TOut;
  m, k: Int64;
begin
  o.n := 0;
  SetLength(o.b, 256);
  format(o, fmt, args);
  if n > 0 then
  begin
    m := o.n;
    if m > Int64(n) - 1 then m := Int64(n) - 1;
    for k := 0 to m - 1 do d[k] := AnsiChar(o.b[k]);
    d[m] := #0;
  end;
  Result := Int32(o.n);
end;

{ ================================================================ time }
function c_time(t: PInt64): Int64;
begin
  Result := FpTime;
  if t <> nil then t^ := Result;
end;

function c_difftime(a, b: Int64): Double;
begin
  Result := I2FD(a) - I2FD(b);
end;

var
  ctimeBuf: array[0..31] of AnsiChar;

{ ctime: "Www Mmm dd hh:mm:ss yyyy\n" (UTC; only the report's clock lines use it) }
function c_ctime(t: PInt64): PAnsiChar;
const
  wn: array[0..6] of AnsiString = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
  mn: array[0..11] of AnsiString = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
var
  secs, days, rem_, y, doy, m, dim, k: Int64;
  s, ys: AnsiString;
  leap: Boolean;

  function two(v: Int64): AnsiString;
  begin
    Str(v, Result);
    if v < 10 then Result := '0' + Result;
  end;

begin
  secs := t^;
  if secs < 0 then secs := 0;
  days := secs div 86400;
  rem_ := secs mod 86400;
  y := 1970;
  doy := days;
  while True do
  begin
    leap := ((y mod 4 = 0) and (y mod 100 <> 0)) or (y mod 400 = 0);
    if leap then k := 366 else k := 365;
    if doy < k then Break;
    doy := doy - k;
    Inc(y);
  end;
  m := 0;
  while True do
  begin
    case m of
      1: if leap then dim := 29 else dim := 28;
      3, 5, 8, 10: dim := 30;
    else
      dim := 31;
    end;
    if doy < dim then Break;
    doy := doy - dim;
    Inc(m);
  end;
  Str(doy + 1, s);
  if doy + 1 < 10 then s := ' ' + s;
  s := wn[(days + 4) mod 7] + ' ' + mn[m] + ' ' + s + ' ' + two(rem_ div 3600) + ':' + two((rem_ mod 3600) div 60) +
    ':' + two(rem_ mod 60) + ' ';
  Str(y, ys);
  s := s + ys + #10;
  for k := 1 to Length(s) do ctimeBuf[k - 1] := s[k];
  ctimeBuf[Length(s)] := #0;
  Result := @ctimeBuf[0];
end;

procedure c_conout(const s: AnsiString);
begin
  if Length(s) > 0 then fwriteBytes(c_stdout, @s[1], Length(s));
  flushW(c_stdout);
end;

{ strtod's fast path needs 1e0 .. 1e22 to be the exact doubles (each is exactly representable): check the
  tables the compiler built against exact products }
procedure checkPowers;
var
  k: Int32;
  v: Double;
  f: Single;
  ten, tenf: Double;
begin
  ten := 10;
  v := 1;
  for k := 0 to 22 do
  begin
    if PQWord(@v)^ <> PQWord(@P10[k])^ then die('swmmcrt: power-of-ten table is not exact'#10);
    v := v * ten;
  end;
  tenf := 10;
  f := 1;
  for k := 0 to 10 do
  begin
    if PUInt32(@f)^ <> PUInt32(@P10F[k])^ then die('swmmcrt: power-of-ten table is not exact'#10);
    f := D2F(f * tenf);
  end;
end;

initialization
  { C's floating-point environment: every exception masked, round to nearest }
  SetMXCSR($1F80);
  Set8087CW($037F);
  checkPowers;
  stdoutRec.fd := 1;
  stdoutRec.isstd := 1;
  c_stdout := @stdoutRec;
  c_stderr := @stdoutRec;
end.
