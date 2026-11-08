{ runswmm.pas - command-line runner for the Free Pascal port of EPA SWMM 5.2.4: the same arguments, console
  messages and exit status (always 0) as EPA's run/main.c.   runswmm <input file> <report file> [output file]
  Written by Claude (Anthropic) for Robert Dickinson; see pascal/README.md. }
{$mode objfpc}{$H+}
program runswmm;

uses swmmcrt, swmm5eng;

var
  version, vMajor, vMinor, vRelease: Int32;
  start: Int64;
  runTime: Double;
  errMsg: array[0..127] of AnsiChar;
  blank: array[0..0] of AnsiChar;
  outFile: PAnsiChar;
  buf: array[0..511] of AnsiChar;
  a: AnsiString;
  msg: AnsiString;
begin
  version := swmm_getVersion();
  vMajor := version div 10000;
  vMinor := (version - 10000 * vMajor) div 1000;
  vRelease := version - 10000 * vMajor - 1000 * vMinor;
  start := c_time(nil);
  if ParamCount = 0 then
    c_conout(#10'Not Enough Arguments (See Help --help)'#10#10)
  else if ParamCount = 1 then
  begin
    a := ParamStr(1);
    if (a = '--help') or (a = '-h') then
      c_conout(#10#10'STORMWATER MANAGEMENT MODEL (SWMM) HELP'#10#10'COMMANDS:'#10#9'--help (-h)       SWMM Help'#10 +
        #9'--version (-v)    Build Version'#10#10'RUNNING A SIMULATION:'#10 +
        #9' runswmm <input file> <report file> <optional output file>'#10#10)
    else if (a = '--version') or (a = '-v') then
    begin
      c_snprintf(@buf[0], SizeOf(buf), #10'%d.%d.%0d'#10#10, [vMajor, vMinor, vRelease]);
      c_conout(AnsiString(PAnsiChar(@buf[0])));
    end
    else
      c_conout(#10'Unknown Argument (See Help --help)'#10#10);
  end
  else
  begin
    blank[0] := #0;
    if ParamCount > 2 then outFile := argv[3] else outFile := @blank[0];
    c_snprintf(@buf[0], SizeOf(buf), #10'... EPA SWMM %d.%d (Build %d.%d.%0d)'#10, [vMajor, vMinor, vMajor, vMinor, vRelease]);
    c_conout(AnsiString(PAnsiChar(@buf[0])));
    swmm_run(argv[1], argv[2], outFile);
    runTime := c_difftime(c_time(nil), start);
    c_snprintf(@buf[0], SizeOf(buf), #10#10'... EPA SWMM completed in %.2f seconds.', [runTime]);
    msg := AnsiString(PAnsiChar(@buf[0]));
    if swmm_getError(@errMsg[0], 127) > 0 then msg := msg + ' There are errors.'#10
    else if swmm_getWarnings() > 0 then msg := msg + ' There are warnings.'#10
    else msg := msg + #10;
    c_conout(msg);
  end;
  c_fflush(c_stdout);
  ExitCode := 0;
end.
