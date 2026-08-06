# c64-testing MCP Usage Guide

Testing with `c64-testing` MCP should largely follow certain guidelines laid out here.

## OS and Applications

Applications for *Command 64 OS* **MUST BE RUN FROM COMMAND 64's SHELL** they **CANNOT** be *LOADed from BASIC* or else they will fail.

## Patience and Performance

The C64`s 6502 processor is a 1Mhz processor and the emulator reproduces this. As a result commands can take quite a while to load and execute. Give them time.

### Warp Mode

A "warp mode" is availble and may be used in extreme cases to speed execution but beware this has the possibilty of scewing performance and timing issues. If *warp mode* is used it should be **DISABLED AFTER A TEST OR TASK HAS BEEN COMPLETED**; it should alse be disabled as a **diagnostic step** if testing seems **UNSTABLE**

#### Warm Mode Example

Some applications or opperations can be long running or loading as indicated in `PATIENCE and PERFORMANCE` and example is building `dash`. *Loading `casm`* is a long process and *building `dash`*, which is a non-trivial application, takes even longer; this can take several minutes. This is one example case where using *warp mode* might be appropriate.

## Character Set/Map and Mode

*Command 64 OS* uses the mixed mode which *displays* **Upper and Lowercase** but they still map to their respective **PETSCII** character set. Case matters in many situations.

## Commands

Commands are case sensitive in *Command 64* both in the shell itself and *external applications*

### Example

+ The `flush` command reads and clears a device's *status and error*
  + `flush` will *succeed*
  + `FLUSH` will *fail* causing the device to be in an error state.
  
## Potential Build Artifacts

Building a single application *with the build system* is acceptable but it must be added to a *.d64* image which *must be attached* or else it will not be availble for testing. This may be performed manually or by rebuilding the image if the test application has been adde to the build harness.

## State and Testing

**State matters**. If the emultor has been paused either explicitly or as a side-effect of a MCP command it must be restarted or tests will continue to fail.

### Consuming Responses

+ *Reading the screen text* to evaluate a response or potential state is *prefered over screenshots*
+ *Screen shots* should *only* be used when reading the screen text does not or cannot provide enough context. Be mindful, they may pause the emulator.

### Breakpoint

Breakponts are a valuable mechanic for testing but must be resumed after reading machine state.

### Reseting

Reseting the emulator is a inevitability. It is preferable to **initiate a machine reset** instead of killing the process. **Killing the process and restarting** is acceptable as a last resort to reset the machine.

### Detaching

When finished testing you **must detach and return control to the user**

# Usage Discoveries and Lessons

Update this `Discoveries and Lessons` with usage **discoveries and "lessons"** to prevent future mistakes.

## Discoviers and Lessons

### Verify which VICE process owns the monitor port before trusting anything

`vice_start` in `launch` mode returns a monitor address **even when it did not
get that port**. If another `x64sc` is already listening on `127.0.0.1:6502`
(for example one the user started by hand hours earlier), the newly launched
process cannot bind it, and every subsequent MCP call silently drives the
*other* instance — with whatever disks *it* has attached.

Symptom: a freshly rebuilt harness keeps producing the old, pre-fix result no
matter how many times you rebuild, restart, or reset.

Confirm ownership before drawing conclusions:

```bash
ss -ltnp | grep 6502          # which PID actually holds the monitor port
ps -eo pid,lstart,cmd | grep [x]64sc
```

A long-running `x64sc` with no `-binarymonitor` flags in its command line is
almost certainly the user's own session, not an MCP-owned one. `vice_stop`
only kills instances the MCP itself launched, so a stale owner survives it —
clearing the port needs an explicit kill, and that is the user's call.

### A rebuilt `.d64` does not reach an already-attached drive

Rebuilding the image on the host does **not** update what a running VICE
serves; the drive keeps serving the image as attached. Rebuilding *and*
re-running in the same session proves nothing.

`vice_reset` takes a `mode` (`system`, `power_cycle`, `drive8`..`drive11`).
None of them refreshes a rebuilt image. Measured directly, by rebuilding a
`.d64` with a new file on it and then asking the running emulator for that
file:

| `vice_reset` mode | Effect | Sees rebuilt image? |
| --- | --- | --- |
| `system` (default) | Soft reset; images stay attached | **No** |
| `drive9` (per-drive) | Resets the drive; no host re-read | **No** |
| `power_cycle` | Hard reset; **detaches** the images | **No** — and worse |

After `power_cycle` the machine comes up to bare BASIC with nothing
attached, and `vice_load_program` then fails with `general failure`, so the
instance cannot be recovered for disk work through the MCP at all.

**The only reliable refresh is a new VICE process** with the image passed in
`vice_start.extra_args`. That needs the monitor port free, so a stale owner
must be closed first — the user's call.

Cheap way to tell stale bytes from a real failure: search the host image and
the emulator's RAM for a known distinctive byte sequence and compare. If RAM
holds bytes that exist in no file on disk, the emulator is serving something
stale.

Cheap way to tell stale bytes from a real failure: search the host image and
the emulator's RAM for a known distinctive byte sequence and compare. If RAM
holds bytes that exist in no file on disk, the emulator is serving something
stale.

### `general failure` from `vice_load_program` usually means "no such file"

The MCP reports a bare `general failure` with no detail when the path does
not exist or is not readable by the VICE process. It reads exactly like an
emulator or monitor fault and is not one. Before touching emulator state,
check the artifact:

```bash
ls -la build/*.d64
```

A missing image also means any `vice_start.extra_args` attach for it silently
did nothing, so that drive is simply empty — rebuild the image, then relaunch
so the attach actually happens. Seen when `build/test.d64` alone had gone
missing while every other image was present; `cmake --build build --target
test_image_d64` recreated it and autostart worked immediately.

### Keyboard encoding: shell commands vs filenames

`vice_feed_keyboard` with `encoding: "ascii"` maps **lowercase** source text to
unshifted PETSCII (`$41`-`$5A`) and **uppercase** source text to shifted
PETSCII (`+$80`). **Built-in shell commands accept only the unshifted form**,
so:

+ Type shell commands in **lowercase**: `drive 9`, `dir`.
+ `{"encoding":"ascii","text":"DRIVE 9\n"}` **fails** with
  `Bad command or file name` — the uppercase maps to shifted bytes.

Filenames are more forgiving than commands — the OS normalizes them, and
uppercase `TEST_CASM_CLIDER` loaded successfully where uppercase `DRIVE 9`
did not (the controlled canary's shifted `petscii_hex` filename works for the
same reason). Do not rely on that asymmetry: **type everything lowercase** and
one rule covers both.

Do not hand-roll `petscii_hex` for anything containing `_`. ASCII `$5F` is
**left-arrow** in PETSCII, not underscore; the underscore in these filenames is
`$A4`. Hand-rolled hex silently produces `test←casm←clider`, which then fails
to load and looks exactly like a broken device or a missing file. Let the
`ascii` encoding do the conversion.

### `vice_read_screen_text` cannot show you case

The decoder renders unshifted PETSCII as ASCII **uppercase** and shifted
PETSCII as `?`. So `DRIVE 9` in a screen-text read means the *unshifted*
(correct, on-screen-lowercase) bytes, and a row of `?????` means shifted bytes.
Never conclude "case is correct" from a screen-text read. When case or exact
glyphs matter, take a screenshot — this is the documented exception to
preferring screen text.

Also read short result rows carefully: `FFFF...` is four failures followed by
three passes, not a truncated line.

### Reading a result is more reliable than screen-scraping it

A harness that ends in `DOS_EXIT` can scroll or clear its own output. When the
result must be unambiguous, read the harness's own counter out of memory
instead: build with `ca65 -g` / `ld65 --dbgfile`, look the symbol up, and read
it.

```bash
grep '"FailCount"' out.dbg     # -> val=0x3CEE
```

Then break at the reporting branch and read that address; `00` is a pass. This
was the evidence that separated a genuine logic bug from a stale image.

### Standalone runs are a diagnostic tool, not verification

Running a harness PRG directly at its link base (load it, set `PC`, run) is a
legitimate way to isolate pure-logic behaviour from the loader, relocator, and
shell. It is **not** product verification — per this document, applications
must be run from Command 64's shell. Use a standalone run to localize a bug,
then re-verify through the shell before calling anything done.

### ca65 charmap: fixture literals must be lowercase

With ca65's C64 target charmap, a source literal `"8:FOO.S"` assembles to
*shifted* PETSCII (`$C6 $CF $CF`), while `"8:foo.s"` assembles to *unshifted*
(`$46 $4F $4F`). CASM's routines emit unshifted constants
(`CASM_PETSCII_P/R/G/L/S/T`), so expected-value fixtures compared against them
must be written **lowercase** in the `.s` source. Uppercase literals produce a
harness that fails against correct production code. See
`reference-casm-petscii-identifier-case`.

### Pacing

Screen reads and other monitor queries pause the emulator; resume with
`vice_run` before assuming a command has progressed. A read immediately after
`vice_feed_keyboard` typically shows the *previous* state — resume, wait, then
read. Loading a small harness from a `.d64` under true drive emulation takes
tens of seconds; do not classify a run as failed before its deadline.
