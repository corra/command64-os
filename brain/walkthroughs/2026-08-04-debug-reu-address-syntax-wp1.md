# DEBUG REU/Address Syntax WP1 Walkthrough

**Status:** Confirmed by user 2026-08-04

**Build:** DEBUG 0.4.0 build 1114

**Branch:** `feature/debug-reu-address-wp1-plan`

## Automated Evidence

- `cmake --build build --target debug image_d64 test_image_d64` passed.
- DEBUG remained stable at 6,595 code bytes and 723 relocation points.
- The configured 8KB `MAIN` envelope was not changed.
- No private zero-page, BSS, or OS parameter-cell ownership changed.
- `wiki/debug-test-plan.md` and `docs/debug-test-plan.md` are byte-identical.
- `git diff --check` passed.
- VICE 3.10 booted `build/image.d64`, displayed the Command64 0.4.1 banner,
  and launched DEBUG 0.4.0 build 1114 by name from the shell.

## Safe Test Setup

Do not use the legacy `$4000/$5000` test ranges. Current DEBUG occupies
approximately `$3800-$51C2`. Use these commands at the DEBUG prompt:

```text
E 6000 EE 00 62 60
E 6100 EA EA EA EA EA EA EA EA
E 6300 20 10 63 EE 01 62 EA
E 6310 EE 02 62 60
E 6200 00 00 00
```

This installs:

- `$6000`: `INC $6200` followed by `RTS`, for `G`.
- `$6100-$6107`: NOP sequence for deterministic `T`/`P` syntax checks.
- `$6300`: `JSR $6310`, then `INC $6201`, then `NOP`.
- `$6310`: `INC $6202`, then `RTS`.
- `$6200-$6202`: three zeroed sentinels.

## `G` Confirmation

Run:

```text
G 6000
G=6000
G =6000
G= 6000
G = 6000
D 5FF8 5FFF
G
D 6200 L 03
```

Expected: `$6200-$6202` is `06 00 00`. The five explicit forms and the
no-argument form all executed the same target.

Run:

```text
G =
G ==
G =G000
G =10000
G =6000 EXTRA
G =0001:0000
G 6000 EXTRA
D 6200 L 03
```

Expected: every invalid command prints `ERROR`; sentinels remain `06 00 00`.

## `T` Confirmation

Run:

```text
T 6100
T=6101
T =6102
T= 6103
T = 6104
T
```

Expected PCs: `$6101`, `$6102`, `$6103`, `$6104`, `$6105`, then `$6106`.

Run:

```text
T =
T ==
T =G000
T =10000
T =6100 EXTRA
T =0001:0000
R
```

Expected: every invalid command prints `ERROR`; `R` still reports `PC=6106`.

## `P` Confirmation

Run:

```text
P 6100
P=6101
P =6102
P= 6103
P = 6104
P =6300
P
D 6200 L 03
```

Expected:

- The spacing forms advance through the NOP sequence.
- `P =6300` steps over `JSR $6310` and reports `PC=6303`.
- No-argument `P` executes `INC $6201` and reports `PC=6306`.
- Sentinels are `06 01 01`.

Run:

```text
P =
P ==
P =G000
P =10000
P =6100 02
P =0001:0000
R
```

Expected: every invalid command prints `ERROR`; `R` still reports `PC=6306`.

## ROM And Exit Regression

Run:

```text
T =D000
P =D000
Q
```

Expected:

- `T =D000` prints the existing cannot-trace-ROM error.
- `P =D000` preserves the existing skip-and-display behavior.
- `Q` returns to a shell prompt matching `c64[<device>]:>`.

## Confirmation Gate

The user confirmed this walkthrough on 2026-08-04. Increment 4 and WP1 may be
marked complete in the wiki task, `brain/task.md`, and Taskwarrior UUID
`adfecaf3-212c-4e91-bcf5-f1c79f673eae`.
