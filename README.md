# Parcel-Based Modeling

Parcel-based groundwater model inputs for Nebraska, built around the CropSim
soil water balance model.

This repository holds the CropSim v8.0 Fortran model, frozen as the
permanent reference, and **the CropSim compute kernel**: the same model
rewritten as a thread-safe library with no file I/O and a C interface, with
each known bug fixable by its own switch (`docs/kernel/`). The Python package
(`cropsim`) runs both, one year at a time.

## Layout

| Path | What it is |
| --- | --- |
| `fortran/original/CROPSIM_V8.0.F90` | The original CropSim v8.0 program, moved from [pyCropSim](https://github.com/Longitude103/pyCropSim) with its git history. **Frozen: never edited.** |
| `tools/make_engine.py` | Generates the library engine from the frozen original by a short, listed set of edits. |
| `fortran/src/cropsim_engine.f90` | Generated engine (do not edit by hand). |
| `fortran/src/cropsim_api.f90` | C-callable driver for the reference engine: `cs_set_block`, `cs_set_tillage`, `cs_run_year`. |
| `fortran/kernel/` | The compute kernel (`csk_run_year`) and its C header. See `docs/kernel/README.md`. |
| `docs/kernel/` | Kernel design, bug-fix switches and how much each fix changes results. |
| `src/cropsim/` | Python package: ctypes binding, input/result objects, readers for the old input files. |
| `tests/` | Parity test against the original program, kernel golden and bug-fix tests. |
| `tests/golden/original.csv` | Original model results for 666 test-parcel runs (`tools/make_golden.py`). |

## Using it

```python
from cropsim import Engine, legacy

engine = Engine(legacy.read_block("BLOCK.DAT"), legacy.read_tillage("TILLAGE.DAT"))
soil = legacy.read_soils("NESOILS.DAT")[622]
sim = legacy.read_sim("CRNIRR01.SIM")
state = legacy.read_initial("INITIAL.DAT")

for year in range(2010, 2015):
    weather = legacy.read_weather(f"AGAT{year}.WEA")
    result = engine.run_year(sim, soil, weather, state)
    state = result.state          # carry this soil's state to its next year
    print(year, result.annual["ets"], result.monthly["etmon"])
```

`Kernel` runs the same model through the compute kernel. It takes the same
inputs, can run on many threads at once, returns daily series
(`result.daily`) and a water balance check, and takes bug fixes as switches:

```python
from cropsim import ALL_FIXES, Fix, Kernel

kernel = Kernel(legacy.read_block("BLOCK.DAT"), legacy.read_tillage("TILLAGE.DAT"))
original = kernel.run_year(sim, soil, weather, state)                   # = original program
fixed = kernel.run_year(sim, soil, weather, state, fixes=ALL_FIXES)    # every fix on
```

The `legacy` readers are only a convenience for existing CropSim folders.
`Block`, `Sim`, `Soil`, `Weather` and `State` are plain dataclasses, so the
parcel layer can fill them from the database or anywhere else. No database
is needed to use the package.

### Carryover state

Each call takes the soil state in and hands the end-of-year state back. Keep
one `State` per soil per parcel. The original kept one `INITIAL.DAT` for
every soil and weather site, so each new soil or site started from whatever
ran last; that cannot happen here.

Every module variable is also restored to its post-setup value before each
run, so a run depends only on its own inputs.

### Known irrigation (second pass)

`sim.irrtyp = 2` with `sim.irrigation_events = [(day_of_year, gross_in,
fraction_infiltrated), ...]` applies given irrigations instead of scheduling
them. This is the applied-water pass of the two-pass irrigation design.

### Threads

The Fortran engine keeps its working values in module variables, so one
process runs one year at a time. Use processes (for example
`multiprocessing`), not threads, to run in parallel.

## Building

Needs gfortran and Python 3.9+.

```bash
pip install .            # builds the Fortran library with CMake and installs cropsim
pip install ".[test]" && pytest
```

CI builds and tests on Linux, macOS and Windows. The Wheels workflow builds
self-contained wheels (Fortran runtime bundled) for all three.

## Parity with the original

`tests/test_parity.py` builds the frozen original (changing only its
hard-coded `S:\Cropsim\Run004\` paths), runs it on the synthetic inputs in
`tests/fixtures/`, then repeats the same runs through the library. The yearly,
monthly and weekly output files and the final `INITIAL.DAT` must match
character for character. To match exactly, the test reproduces two quirks of
the original: state flowing from run to run through one file, and SIM values
left over from the previous SIM file (`read_sim(..., previous=...)`).

Fixtures are made by `tools/make_fixtures.py`. They are synthetic, not State
data.

## Differences from the original program

The water balance subroutines are unchanged. The library differs only where
the original read or wrote files or stopped:

- No files are read or written; results come back as arrays.
- The six `STOP` checks return an error code (raised as `CropSimError`)
  instead of ending the Python process.
- The known-irrigation file (`FDFILE`) was read into `FDIRRIG` with its
  indexes swapped relative to how the engine uses them, and overflowed past 4
  events. The library stores events the way the engine reads them (up to 50).
- `CROPCO` read three of its local variables (`PCT`, `IEFC`, `GDDCUT`)
  before setting them on some days (alfalfa before green-up and between
  cuttings, hay after its cutting), so those results depended on the
  compiler. The library keeps them from day to day within a run and starts
  each run at `PCT=0`, `IEFC=1`, `GDDCUT=0`. The parity test builds the
  original with the same definition, which is its only change besides paths.
- Values a SIM file does not set for its crop type (for example `GDDFLO` for
  alfalfa and pasture, which `ROOTZN` still uses) come from the `Sim` object
  (default 0) rather than from whatever SIM file ran before.
