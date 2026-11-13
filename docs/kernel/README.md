# CropSim compute kernel

`fortran/kernel/` is CropSim v8.0 rewritten as a pure compute library. It is
the engine the Rust core (CLI, Tauri UI, PyO3 bindings) will call, and it is
what the Python `cropsim.Kernel` class runs today.

The original program stays in the repository, untouched, as the permanent
reference (`fortran/original/CROPSIM_V8.0.F90`).

## What changed from the original

| Original | Kernel |
| --- | --- |
| One 4,024-line file, no `IMPLICIT NONE`, 93 implicitly typed names | Five modules, `implicit none` everywhere |
| ~400 global variables in `MODULE PARM`; values leak from run to run | No globals. Each run builds its own `csk_work_t` and drops it at the end |
| Reads `BLOCK.DAT`, `*.SIM`, `*.WEA`, `INITIAL.DAT`; writes text reports | No file I/O. Inputs and outputs are C structs |
| `INITIAL.DAT` shared by every soil and site | Caller passes the state in and gets it back |
| `STOP` on a bad day ends the process | Status code returned |
| Not re-entrant | Thread-safe: any number of runs at once |
| 13 copies of the same crop coefficient curve code | One table-driven routine |
| Daily values only in a debug printout | 21 daily series returned for every run |
| No mass balance check | Daily and annual water balance error returned |

The print-only work of the original (daily debug listings, off-season
totals, report headers) is gone. Everything the original returned is
still returned, in the same units.

## Layout

| File | Contents | Original |
| --- | --- | --- |
| `csk_types.f90` | Interface structs, the per-run work type, fix switches | `MODULE PARM` |
| `csk_physics.f90` | Weather prep and GDD, crop coefficients, snow, runoff, evaporation, infiltration, roots, soil temperature, yield | `READWEAT`, `CROPCO`, `SNOWMELT`, `EFPRECIP`, `EVAP`, `NTHET`, `ROOTZN`, `SOILTEMP`, `YIELDS` |
| `csk_balance.f90` | Daily water balance and irrigation scheduling | `DEPLT`, `IRRIGA` |
| `csk_kernel.f90` | One year: setup, weather, balance, yield, state | per-year part of `PROGRAM CROPSIMv7` |
| `csk_capi.f90` | C entry points | |
| `cropsim_kernel.h` | C header for Rust / C callers | |

## C interface

```c
int32_t csk_run_year(const csk_params_t *params, const csk_sim_t *sim,
                     const csk_soil_t *soil, const csk_weather_t *weather,
                     const csk_state_t *state_in, const csk_options_t *options,
                     csk_state_t *state_out, csk_result_t *result);
```

* `params`: BLOCK.DAT and TILLAGE.DAT values, built once and shared.
* `sim`, `soil`, `weather`: one crop setup, one soil, one year.
* `state_in` / `state_out`: carryover for this soil on this parcel.
* `options.fixes`: bug-fix bits (`docs/kernel/fixes.md`); 0 reproduces
  the original.
* `result`: annual, monthly, weekly and daily values, the water balance
  error and a status code.

`csk_struct_size(n)` gives each struct's size so a caller can check its
layout (the tests do this for the header).

## How it is checked

1. `tests/test_parity.py` builds the frozen original program, runs it on the
   fixture inputs, and checks that the kernel (no fixes) reproduces its
   yearly, monthly and weekly output files and final `INITIAL.DAT`
   character for character.
2. `tests/test_kernel.py` runs 37 crop and irrigation setups (all 22 crop
   codes, every irrigation type and scheduling method, terraces, known
   irrigation dates) on 3 soils for 6 years each, 666 runs, through the
   kernel and through the reference engine (the frozen original with only
   the library edits) and requires every annual, monthly, weekly and state
   value to be bit-for-bit equal.
3. The same runs are pinned in `tests/golden/original.csv`
   (`tools/make_golden.py`), so a change to the reference or the build that
   moves results is also caught.
4. The same 666 runs are made on 8 threads at once and must match.

The kernel is built with `-O2 -ffp-contract=off` (no fast-math, no fused
multiply-add), the same as the reference, so the two round identically.

## Quirks it keeps (with no fixes)

The kernel reproduces the original exactly, including behaviour that looks
wrong. Each of these has a fix switch (see `fixes.md`). A few are found
only by rewriting the code and were not in the earlier review:

* Summer fallow (crop 15, dryland) leaves the water balance relabelled as
  winter wheat, because the original's COHYST relabelling of fallow wheat
  years to 15 is undone with a test that also catches real fallow. Its
  yield is then computed as wheat (NaN) and next year starts with a "live"
  wheat crop.
* The forecast scheduling methods (IRRSCH 4 and 5) count a day as an
  irrigation even when no water is applied, so IRIGNO is 3-4 times the real
  number of irrigations.
* `INFMON` (monthly infiltration) is always 0: it is summed after
  infiltration has reset the value to 0.

Where the original read memory outside an array (forecast rain past day
366, `GDDS(0)` for a Jan 1 planting, the yield trend for crops 12-22),
the kernel uses zero, zero and no trend, and documents it here; the
original's values there were whatever happened to be in memory.

## Fixes

`fixes.md` lists the fix switches: what the original does, what the fix
does, and the test that shows it. `fix-impact.md` (generated by
`tools/fix_impact.py`) shows how much each one moves deep percolation, ET,
irrigation and runoff on the test parcels. The original is always one
`fixes=0` away.

## Decided

* `GDDFLO` unset for crops 10 and up: established perennial covers
  (alfalfa, hay, pastures, turf, woodlands, wetlands: crops 10-14 and
  16-19) use `RZMAX` all year (`PERENNIAL_ROOTS`). Fallow (15), open water
  (20-21) and farmsteads (22) keep the original equation.
* `RZMIN` not scaled by soil: capped at the scaled `RZMAX` (`RZMIN_CAP`).
* Leap years: a leap-aware calendar for SIM dates and monthly totals
  (`LEAP_CALENDAR`).
* Tailwater: applies only to furrow irrigation, IRRTYP 4
  (`TAILWATER_FURROW`).

## Not fixed yet (need a decision)

These look wrong but the right answer is a modelling choice, so they are
left as the original for now:

* Irrigation scheduling method 6 (IRRSCH 6).
* `JSTOPI` / `JGOI` are read in a different order by the Python legacy
  reader than the Fortran reader.

## Newer methods

Most of CropSim's methods date from the 1980s and 1990s (curve-number
runoff, a tipping-bucket soil profile, crop coefficient curves). A
follow-up is to add newer methods as options next to the original ones,
for example a Richards-equation soil column in the style of HYDRUS-1D for
the soil water balance, FAO-56 dual crop coefficients, or Green-Ampt
infiltration. The kernel's layout (one routine per process, all state in
`csk_work_t`) is meant to make that a matter of adding a routine and a
switch.
