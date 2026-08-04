# Task Spec: DEBUG REU/Address Syntax WP6

## Objective

Implement `XM`'s real chunked `DOS_VMM_READ`/`DOS_VMM_WRITE` transfer,
replacing WP5's temporary `XM PREFLIGHT OK` indicator, per
`brain/plans/2026-08-06-debug-reu-address-syntax-wp6.md`.

Taskwarrior UUID: `2386a65f-c972-4f69-8c83-0b4032a8fd97`

## Scope

- Expand DEBUG's `MAIN` linker envelope from `$2000` to `$2400`
  (`CMakeLists.txt:185`) as a prerequisite — verified headroom before this
  change is only 159 bytes, not enough for WP6's new logic.
- `stageReuTransfer`/`advanceReuTransfer`: chunk selection (max 256
  bytes), fresh OS parameter staging every chunk, cursor/remaining/
  transferred-count bookkeeping.
- Real `DOS_VMM_READ`/`DOS_VMM_WRITE` dispatch per `R`/`W` direction.
- Stop immediately on runtime OS failure; report exact transferred
  progress via `REU_ERR_PARTIAL_TRANSFER`.
- Preserve WP1-WP5 behavior; no DMA reachable from any WP5-rejected
  command.

## Increments

- [ ] Increment 0: envelope expansion, build, and doc update.
- [ ] Increment 1: `stageReuTransfer`/`advanceReuTransfer`, build.
- [ ] Increment 2: transfer loop wiring, real DMA, build, and VICE
      round-trip verification.
- [ ] Increment 3: partial-failure path — static review (no safe live
      fault-injection trigger identified; documented as a verification
      gap per user agreement).
- [ ] Increment 4: full regression, artifact audit, documentation, DOX,
      and user-confirmed walkthrough.

## Acceptance

- [ ] Envelope expansion is inert on its own before any WP6 logic lands.
- [ ] Round-trip transfers are byte-exact for `R`/`W`, flat and
      page-relative operands, across chunk/page/allocation boundaries.
- [ ] Every OS_API parameter is restaged fresh before every chunk.
- [ ] No DMA reachable from any command that fails WP5's preflight
      validation.
- [ ] BSS growth is exactly 4 bytes; no new private zero-page state.
- [ ] DEBUG remains relocatable and inside its expanded linker envelope.
- [ ] The user confirms the walkthrough before WP6 is marked complete.
