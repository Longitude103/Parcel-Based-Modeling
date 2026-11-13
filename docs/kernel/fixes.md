# Bug fixes in the CropSim kernel

Each fix is a bit in `options.fixes` (`csk_options_t` in C, `cropsim.Fix`
in Python). With `fixes = 0` the kernel reproduces the original v8.0
program exactly; any fix can be switched on alone or with others, so every
change can be measured against the original.

Each fix has a test in `tests/test_fixes.py` that shows the original
behaviour with the fix off and the corrected behaviour with it on. How
much each fix moves deep percolation, ET, net irrigation and runoff on the
test parcels is in [fix-impact.md](fix-impact.md).

Line numbers refer to `fortran/original/CROPSIM_V8.0.F90`.

| Bit | Value | Name | Changes |
| --- | --- | --- | --- |
| 0 | 1 | `KC_GDD_LAG` | Crop coefficients (all crops), so ET |
| 1 | 2 | `SNOWMELT_BASE` | Snow melt timing, so winter runoff and infiltration |
| 2 | 4 | `IRRIGATION_COUNT` | Reported irrigation count (IRIGNO) and first irrigation day (JFIRST) only |
| 3 | 8 | `ROTATION_FREQUENCY` | Rotation (IRRSCH 3) delivery count, so NIR, ET, DP |
| 4 | 16 | `FORAGE_CUTTING_STAGE` | Alfalfa and hay: irrigation limits by cutting, deficits and yield by cutting |

## KC_GDD_LAG: crop coefficient one day behind

**Original** (READWEAT, 3693-3697). The daily crop coefficients are made
in a loop that calls `CROPCO` and only then sets `GDD = GDDS(JDAY)`. So
each day's KC is computed from the previous day's cumulative GDD, and the
first day uses whatever `GDD` held from the GDD loop (the daily increment
of the last day of the season).

**Fix.** Set the day's GDD before computing its KC.

**Test.** `test_kc_gdd_lag`: corn's KC on each day matches the corn curve
evaluated at the previous day's GDD with the fix off, and at the same day's
GDD with it on.

## SNOWMELT_BASE: snow melts below freezing

**Original** (SNOWMELT, 3994-3999). The melt base temperature `SMTMP` is
never read or set, so it is 0 F. Snow melts on any day with a high above
0 F, and the melt rate is scaled from 0 F instead of freezing.

**Fix.** Use `params.smtmp` (Python `Kernel(..., smtmp=32.0)`, default
32 F; SWAT's default is 0.5 C, 32.9 F). BLOCK.DAT has no field for it.

**Test.** `test_snowmelt_base`: on the range parcel, snow cover shrinks
on dry days with highs at or below 32 F with the fix off, and never with
it on.

## IRRIGATION_COUNT: irrigation count and first date wrong

**Original** (DEPLT 2123; IRRIGA 2869-2925). `IRIGNO` doubles as the index of
the next known irrigation date, so it is set to 1 before the first
irrigation in every irrigated run. Demand-scheduled runs then report one
irrigation too many, and since the count never passes through 1 after an
irrigation, the first irrigation date `JFIRST` is never recorded. The
forecast methods (IRRSCH 4 and 5) also count every day that passes the
date and GDD checks, irrigated or not.

**Fix.** Known irrigation dates use their own index; `IRIGNO` counts only
days with water applied, and `JFIRST` is the first of them. Water applied
is unchanged.

**Test.** `test_irrigation_count` for demand, forecast and known-date
runs: off, the count is the number of irrigated days plus one (much more
for the forecast method) and `JFIRST` is 0; on, both match the daily
irrigation record.

## ROTATION_FREQUENCY: rotation deliveries ignore the rotation interval

**Original** (DEPLT 2087-2111; JDFREQ read at 901/903 and never used).
For district rotation delivery (IRRSCH 3), irrigation after the first
delivery waits for `JNEXTI`, which is set to 1 at the start of the year
and never advanced. A full `DDEPTH` can therefore be delivered on any
day the soil is dry enough, not every `JDFREQ` days.

**Fix.** After each delivery the next one is allowed `JDFREQ` days later.

**Test.** `test_rotation_frequency` (soybean, alfalfa and border
setups): off, deliveries come closer together than `JDFREQ`; on, never.

**Related, not changed in the kernel.** The original reads `JSTOPI` and
`JGOI` (the summer shut-off) only for crops outside 10-13 but uses them
only for crops 10-12, so alfalfa and pasture use stale values. The kernel
takes them from the SIM input as given; the Python `legacy.read_sim`
reader still follows the original file layout.

## FORAGE_CUTTING_STAGE: alfalfa stage stuck at cutting 1

**Original** (DEPLT 1880, 1953, 2151-2153). For alfalfa and hay the growth
stage is the cutting cycle `ICUT`. `CROPCO` tracks it, but CropSim now
calls `CROPCO` once for the whole year before `DEPLT`, and `DEPLT`
resets `ICUT` to 1 and never updates it. So allowable depletion, rain
allowance, efficiency and the minimum, maximum and smallest application
always use the stage 1 values, and all transpiration deficits are booked
to cutting 1.

**Fix.** `DEPLT` works out the cutting cycle each day from the cutting
dates, with the same rules as `CROPCO`.

**Test.** `test_forage_cutting_stage`: alfalfa with smaller application
limits after the first cutting. Off, every later irrigation still uses the
first cycle's limits; on, the later cycles' limits apply.

The fixture SIM files use the same values for every stage, so this fix
changes nothing on the standard test parcels; it matters wherever SIM
files give different values by cutting.
