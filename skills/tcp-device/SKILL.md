---
name: tcp-device
description: "Sample skill: a reusable TCP link to a device that speaks text lines (barcode scanner, label printer, vision sensor, robot controller, test PC, MES gateway) - the IEC library TcpDev with the block TcpDeviceClient (connect and reconnect, request and answer, lines the device sends by itself, timeouts), how to bring it into a project, use it from a station, and test it on ARsim against a line server on the PC. Use when the PLC must talk to a device over the device's own TCP text protocol."
metadata:
  group: modules
  version: "0.2.0"
  min-asmcp: "1.44.0"
  requires-tools: "add_library, add_object, write_file, add_file, add_program, build, write_variable, watch_variables"
---
# TCP device link (sample)

Many devices take commands and give answers as text lines over TCP: a scanner answers `TRIGGER` with the code it
read, a printer takes a label job, a vision sensor or a robot controller answers a request. This skill brings a
ready block for that: one `TcpDeviceClient` instance per device keeps the connection, sends a request, collects the
answer line and reports errors, so the program only says *what* to send.

**Status of this sample (0.2.0):** built with ASMCP's tools exactly as in sections 1 and 3 (0 errors, 0 warnings) and
run on ARsim (AR 6.8.1, ScannerCom in a 100 ms task class, 2026-11-11): all six rows of section 4 passed. Not yet
used with a real device: tell the user it is a sample before using it on a machine.

Not for: Modbus TCP (as_guide 'fieldbus'), OPC UA (as_guide 'opcua'), HTTP (library AsHttp), B&R PLC to B&R PLC
variables. A binary protocol (length headers, no end character): adapt the line cutting (section 5).

## Files of this skill

| File | What |
|---|---|
| `TcpDev/TcpDev.fun` | the block's interface |
| `TcpDev/Types.typ` | `TcpDevStateEnum`, the block's steps |
| `TcpDev/Constants.var` | `TCPDEV_ERR_...` codes and the defaults |
| `TcpDev/TcpDeviceClient.st` | the implementation (block comments only: builds without IecExtendedComments) |
| `test/line_server.py` | a line server for the ARsim test (Python 3, standard library) |

The paths are relative to this skill's folder; as_guide shows the full paths under this text.

## 1. Bring the library into the project

1. `list_libraries`: the project needs `AsTCP`, `AsBrStr` and `standard` (`runtime` comes with AsTCP). `add_library`
   each missing one.
2. A library `TcpDev` already in the project: compare it with this skill's files first and ask the user before
   replacing a changed copy.
3. `add_object` template `IecLibrary`, name `TcpDev`, parent `Logical/Libraries`, description
   `TCP link to devices that speak text lines (sample skill tcp-device)`. It creates `TcpDev.fun`, `Types.typ` and
   `Constants.var`.
4. `write_file` those three with the content of this skill's files of the same names.
5. `add_file` parent `Logical/Libraries/TcpDev`, `source_paths` = the full path of `TcpDev/TcpDeviceClient.st`.
6. `build`: 0 errors and 0 warnings before anything uses the block.

## 2. The block

| Input | |
|---|---|
| `Enable` | TRUE: connect and keep the connection, reconnect after `RetryDelay`; FALSE: close |
| `ServerAddress`, `ServerPort` | the device (IP address or host name) |
| `Send`, `Request` | a rising edge of `Send` sends `Request` (with the end characters the device expects, e.g. `'TRIGGER$R$L'`) |
| `EndChar` | the last byte of the device's lines; 0 = LF. A CR right before it is removed |
| `AnswerTimeout`, `RetryDelay` | T#0s = 5 s and 3 s |

| Output | |
|---|---|
| `Connected` | the connection is up |
| `Busy` / `Done` / `Error` | a request waits / its answer is in `Answer` / it failed. `Done` and `Error` stay while `Send` is TRUE |
| `StatusID` | why it failed last: an AsTCP status (table in as_guide 'lib:AsTCP') or `TCPDEV_ERR_TIMEOUT` 50000, `_OVERFLOW` 50001, `_CLOSED` 50002, `_NOT_CONNECTED` 50003 |
| `Answer`, `NewLine`, `LineCount` | the last complete line (up to 255 characters); TRUE for one call when lines arrived; lines since the start |
| `SocketIdent`, `State` | the open socket (for `_EXIT`); the step (`TcpDevStateEnum`) |

How it behaves:
- **The answer is the next complete line after the request.** A device that also sends lines by itself (a scanner
  in continuous mode, a robot's events) can put one of those first: then check the answer's text.
- **Lines the device sends by itself** set `NewLine` for one call and land in `Answer`; with several lines in one
  cycle, `Answer` holds the last and `LineCount` counts all.
- **A timeout keeps the connection** (`Error`, `StatusID` 50000); a lost connection fails the waiting request and
  reconnects after `RetryDelay`. A `Send` while not connected fails at once (50003).
- A line longer than the 1024-byte buffer without its end character is dropped (50001).
- `tcpERR_WOULDBLOCK` (32607, "would block, call again") is not a failure: the block calls again (not yet seen in a
  test).

## 3. One program per device link

Put the link in the package of the machine function it serves (the infeed's scanner in `Logical/Infeed`), in a task
class fast enough for the device: a request and its answer take about 3 cycles of the calling task (as_guide
'runtime'). `add_program` `ScannerCom` with `parent` that package, then:

Variables.var:
```
VAR
	Scanner : TcpDeviceClient; (*Link to the infeed's barcode scanner*)
	CloseScannerSocket : TcpClose; (*Frees the scanner's socket in _EXIT*)
END_VAR
VAR CONSTANT
	SCANNER_ADDRESS : STRING[80] := '192.168.0.20'; (*IP address of the scanner*)
	SCANNER_PORT : UINT := 2001; (*TCP port of the scanner*)
	SCANNER_TRIGGER : STRING[20] := 'TRIGGER$R$L'; (*Command that reads one code*)
	SCANNER_TIMEOUT : TIME := T#2s; (*Max. time for one reading*)
END_VAR
```

The station's interface in Logical/Global.typ (commands from the station, status from ScannerCom) and
`gScanner : ScannerType; (*Infeed scanner: commands and status*)` in Logical/Global.var:
```
TYPE
	ScannerCmdType : STRUCT (*Commands to the scanner link*)
		Read : BOOL; (*TRUE: read one code; the result stays until Read is FALSE*)
	END_STRUCT;
	ScannerStatusType : STRUCT (*State of the scanner link*)
		Connected : BOOL; (*The scanner is connected*)
		Done : BOOL; (*Code holds the code read for Read*)
		Error : BOOL; (*The reading failed: no answer or the connection was lost*)
		StatusID : UINT; (*Cause of the last failure (TcpDev or AsTCP status)*)
		Code : STRING[255]; (*The code read*)
	END_STRUCT;
	ScannerType : STRUCT (*Infeed scanner: commands and status*)
		Cmd : ScannerCmdType; (*From the station*)
		Status : ScannerStatusType; (*From ScannerCom*)
	END_STRUCT;
END_TYPE
```

Cyclic.st:
```
PROGRAM _CYCLIC
	Scanner(Enable := TRUE, ServerAddress := SCANNER_ADDRESS, ServerPort := SCANNER_PORT, Send := gScanner.Cmd.Read, Request := SCANNER_TRIGGER, EndChar := 0, AnswerTimeout := SCANNER_TIMEOUT, RetryDelay := T#0s);
	gScanner.Status.Connected := Scanner.Connected;
	gScanner.Status.Done := Scanner.Done;
	gScanner.Status.Error := Scanner.Error;
	gScanner.Status.StatusID := Scanner.StatusID;
	IF Scanner.Done THEN
		gScanner.Status.Code := Scanner.Answer;
	END_IF;
END_PROGRAM
```

Exit.st (a download or stop runs it; without it the socket stays allocated until the next restart):
```
PROGRAM _EXIT
	IF Scanner.SocketIdent <> 0 THEN
		CloseScannerSocket(enable := TRUE, ident := Scanner.SocketIdent, how := 0);
	END_IF;
END_PROGRAM
```

On a machine the address is a setting the operator can change (as_guide 'features'), not a constant.

**From an OMC station** (as_guide 'omc', add_station): a command rung `St3 -> gScanner.Cmd.Read`, the next
transition on `gScanner.Status.Done`, the code checked in an ST action the step calls, and a condition alarm on
`gScanner.Status.Error` (`alarms: [{"when": "gScanner.Status.Error", "alarm": "AlmScanner", "text": "Scanner: no
code read"}]`). The step that waits for the code needs no step-time supervision: `"timed": false`.

## 4. Test on ARsim

The user decides whether ARsim runs (and whose: check the running ARsim first). About 15 minutes.
1. On the PC: `python <skill>\test\line_server.py` - it listens on `127.0.0.2:12000`, a loopback address of its own
   that an ARsim on `127.0.0.1` reaches (as_guide 'runtime', ARsim section). It answers each line with `ACK <line>`
   and greets each connection with `HELLO`.
2. For the test, `SCANNER_ADDRESS` `'127.0.0.2'` and `SCANNER_PORT` `12000`; `build simulation=true transfer=true`.
3. Check, with `watch_variables` / `write_variable`:

| # | Do | Expect |
|---|---|---|
| 1 | start | `ScannerCom:Scanner.Connected` TRUE, `LineCount` 1 (`HELLO`) |
| 2 | `gScanner.Cmd.Read` TRUE | `gScanner.Status.Done` TRUE, `Code` `ACK TRIGGER` (measured: 0.45 s at 100 ms); Read FALSE -> Done FALSE |
| 3 | stop the server | `Connected` FALSE, `StatusID` 50002 for an orderly close, 32609 `tcpERR_NOT_CONNECTED` when the server process is killed (measured); then every 3 s an attempt, each refused one ending after about 2 s with 32608 `tcpERR_INVALID` |
| 4 | start the server again | `Connected` TRUE within about 3 s (measured 3.3 s) |
| 5 | server with `--silent`, then Read | `Error` after 2 s, `StatusID` 50000, still connected |
| 6 | server with `--tick 2` | `LineCount` rises, `Answer` `TICK n`, no Read needed |

`StatusID` keeps the last failure's cause while all is well again (here 32609 from row 3 until row 5): judge the link
by `Connected`, a request by `Done` / `Error`.

4. Put the addresses back and report what you saw, row by row.

On the machine: the device's network must reach the PLC's interface; with the PLC's firewall on, the connection
needs a rule (as_guide 'runtime', firewall).

## 5. Adapting it

- **Another protocol:** copy the library under a new name and change only the cutting loop in `tdCONNECTED`
  (a length header, a fixed-size telegram); the connection steps stay.
- **The device connects to the PLC** (the PLC is the server): the server variant in as_guide 'lib:AsTCP'.
- **TLS:** `TcpOpenSsl` / `TcpOpenMcs` instead of `TcpOpen` (as_guide 'lib:AsTCP', 'openssl').
- **Several devices:** one instance and one program each; a target has at most 128 TCP sockets in all.

## Pitfalls

- Call the instance every cycle, also with `Enable` FALSE, like every function block (as_guide 'guidelines' C305).
- Without the `_EXIT` of section 3 every download leaves one socket allocated until the next restart.
- `$` in a string starts an escape: `'$R$L'` is CR LF, `'$$'` a dollar sign (as_guide 'st').
