{ crtcheck.pas - compare the Pascal port's printf, strtod and sscanf (src/swmmcrt.pas) with the system glibc's
  results written by tools/crt/test/mkfmt.c (lines KIND <tab> FORMAT <tab> ARG <tab> RESULT, hex-encoded).
    pascal/test/run_crtcheck.sh  (builds mkfmt and this program, runs both, prints the summary)
  Written by Claude (Anthropic) for Robert Dickinson; see pascal/README.md. }
{$mode objfpc}{$H+}{$POINTERMATH ON}
program crtcheck;

uses swmmcrt;

const
  HX: AnsiString = '0123456789abcdef';

function unhex(const s: AnsiString): AnsiString;
var
  i: Int32;
  v: Int32;
  function hv(c: AnsiChar): Int32;
  begin
    if c <= '9' then Result := Ord(c) - 48 else Result := Ord(c) - 87;
  end;
begin
  Result := '';
  i := 1;
  while i < Length(s) do
  begin
    v := hv(s[i]) * 16 + hv(s[i + 1]);
    Result := Result + AnsiChar(v);
    Inc(i, 2);
  end;
end;

function tohex(p: PAnsiChar): AnsiString;
var
  k: Int32;
begin
  Result := '';
  k := 0;
  while p[k] <> #0 do
  begin
    Result := Result + HX[1 + Ord(p[k]) shr 4] + HX[1 + Ord(p[k]) and 15];
    Inc(k);
  end;
end;

function hex64(v: QWord): AnsiString;
var
  k: Int32;
begin
  Result := '';
  for k := 15 downto 0 do Result := Result + HX[1 + Int32((v shr (4 * k)) and 15)];
end;

function parseHex(const s: AnsiString): QWord;
var
  k: Int32;
  c: AnsiChar;
begin
  Result := 0;
  for k := 1 to Length(s) do
  begin
    c := s[k];
    if c <= '9' then Result := Result * 16 + QWord(Ord(c) - 48) else Result := Result * 16 + QWord(Ord(c) - 87);
  end;
end;

procedure split(const line: AnsiString; out a, b, c, d: AnsiString);
var
  p: array[0..3] of AnsiString;
  k, i, st: Int32;
begin
  k := 0;
  st := 1;
  for i := 1 to Length(line) + 1 do
    if (i > Length(line)) or (line[i] = #9) then
    begin
      if k <= 3 then p[k] := Copy(line, st, i - st);
      Inc(k);
      st := i + 1;
    end;
  a := p[0]; b := p[1]; c := p[2]; d := p[3];
end;

var
  f: TextFile;
  line, kind, fm, arg, want, got, sv, istr: AnsiString;
  total, bad: array[0..5] of Int64;
  shown, k: Int32;
  outb: array[0..1023] of AnsiChar;
  x: Double;
  xb: QWord;
  vi: Int32;
  vl: Int64;
  endp: PAnsiChar;
  i1: Int32;
  d1: Double;
  bb: array[0..31] of AnsiChar;
  n: Int32;
  names: array[0..5] of AnsiString = ('printf %f', 'printf %d', 'printf %ld', 'printf %s', 'strtod', 'sscanf');
  nb, nt: Int64;
  buf: array[0..1 shl 20 - 1] of Byte;
begin
  for k := 0 to 5 do
  begin
    total[k] := 0;
    bad[k] := 0;
  end;
  shown := 0;
  AssignFile(f, ParamStr(1));
  SetTextBuf(f, buf, SizeOf(buf));
  Reset(f);
  while not Eof(f) do
  begin
    ReadLn(f, line);
    if line = '' then Continue;
    split(line, kind, fm, arg, want);
    case kind[1] of
      'f':
        begin
          k := 0;
          xb := parseHex(arg);
          x := PDouble(@xb)^;
          if fm = '%*.*f' then c_snprintf(@outb[0], 1024, PAnsiChar(fm), [Int32(9), Int32(3), x])
          else c_snprintf(@outb[0], 1024, PAnsiChar(fm), [x]);
          got := tohex(@outb[0]);
        end;
      'i':
        begin
          k := 1;
          vi := Int32(UInt32(parseHex(arg)));
          c_snprintf(@outb[0], 1024, PAnsiChar(fm), [vi]);
          got := tohex(@outb[0]);
        end;
      'l':
        begin
          k := 2;
          vl := Int64(parseHex(arg));
          c_snprintf(@outb[0], 1024, PAnsiChar(fm), [vl]);
          got := tohex(@outb[0]);
        end;
      's':
        begin
          k := 3;
          sv := unhex(arg);
          c_snprintf(@outb[0], 1024, PAnsiChar(fm), [PAnsiChar(sv)]);
          got := tohex(@outb[0]);
        end;
      'd':
        begin
          k := 4;
          sv := unhex(arg);
          x := c_strtod(PAnsiChar(sv), @endp);
          Str(PtrUInt(endp) - PtrUInt(PAnsiChar(sv)), istr);
          got := hex64(PQWord(@x)^) + ':' + istr;
        end;
      'n':
        begin
          k := 5;
          sv := unhex(arg);
          i1 := -77;
          d1 := -77.0;
          FillChar(bb, SizeOf(bb), 0);
          bb[0] := '?';
          n := c_sscanf(PAnsiChar(sv), '%d %lf %s', [@i1, @d1, PAnsiChar(@bb[0])]);
          Str(n, istr);
          got := istr + ':';
          Str(i1, istr);
          got := got + istr + ':' + hex64(PQWord(@d1)^) + ':' + tohex(@bb[0]);
        end;
    else
      Continue;
    end;
    Inc(total[k]);
    if got <> want then
    begin
      Inc(bad[k]);
      if shown < 25 then
      begin
        Inc(shown);
        WriteLn('  ', kind, ' ', fm, ' arg=', arg, '  glibc=', want, '  pascal=', got);
      end;
    end;
  end;
  CloseFile(f);
  nb := 0;
  nt := 0;
  for k := 0 to 5 do
  begin
    WriteLn(names[k], ': ', total[k], ' cases, ', bad[k], ' differ');
    nb := nb + bad[k];
    nt := nt + total[k];
  end;
  WriteLn(nb, ' of ', nt, ' cases differ');
end.
