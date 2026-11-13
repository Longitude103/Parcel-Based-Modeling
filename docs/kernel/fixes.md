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
| 5 | 32 | `ALFALFA_REGROWTH` | Alfalfa with 2 cuttings: KC after the second cutting, so ET |
| 6 | 64 | `TRANSPIRATION_LIMIT` | Transpiration and ET on water-short days; closes the water balance |
| 7 | 128 | `WETLAND_BALANCE` | Wetland, riparian woodland and open water: DP and a new supply term (WETSUPS) |
| 8 | 256 | `DRAINAGE_SPREAD` | DP and soil water where layers sit at field capacity (mostly wetlands); closes the water balance |
| 9 | 512 | `KNOWN_DATE_RAIN` | Known-date irrigation runs (IRRTYP 2): effective rain, so DP and ET |

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

## ALFALFA_REGROWTH: two-cutting alfalfa regrows from the wrong cutting

**Original** (CROPCO 3137). After the last cutting the crop coefficient
follows the regrowth curve from that cutting to the end of the season
(day 305). For the second cycle the code measures it from cutting 1
instead of cutting 2, so alfalfa with exactly two cuttings gets a
mid-season KC right after its last cutting.

**Fix.** Measure the final regrowth from the last cutting.

**Test.** `test_alfalfa_regrowth`: two-cutting alfalfa; in the days after
the second cutting KC is lower with the fix on (back at the start of the
curve), and the season up to that cutting is unchanged.

## TRANSPIRATION_LIMIT: transpiration larger than the water removed

**Original** (DEPLT 2267-2310). When the transpiration demand `T` is more
than the water available in the root zone, the root zone is taken to the
wilting point, but `T` keeps the full demand, so more transpiration is
reported than water leaves the soil. The same step also lifts any root-zone
layer that evaporation had dried below the wilting point back up to it,
creating water. When the demand can be met, the uptake loop stops once it
is within 0.001 in of the demand (or after 20 tries) and still reports the
full demand.

**Fix.** Report the water actually taken (`TUSE`) as transpiration, and
leave layers already below the wilting point alone.

**Test.** `test_transpiration_limit`: on dryland corn and range on the
sandy soil, there are days with transpiration whose water balance is off
by more than 0.0001 in (always too much ET) with the fix off, and none with
it on.

This was suspected in the technical reference and is now confirmed.

## WETLAND_BALANCE: wetlands and open water reset to field capacity

**Original** (DEPLT 2347-2357). For riparian woodland (16), wetlands (18,
19) and open water (20, 21), ET is `KC x ETR` and every layer is then set
back to field capacity. Rain that soaked in above field capacity is
erased before it can drain, so these covers never produce deep
percolation, and their ET is not taken from any store. Neither the lost
rain nor the ET supply shows in any output.

**Fix.** ET is met first from water above field capacity (the day's
infiltration), top layer down. The shortfall, plus anything needed to
bring a layer back to field capacity, is supplied from ground or surface
water and reported as the new `WETSUPS` (annual), `WSMON` (monthly) and
`wetsup` (daily) values. Water left above field capacity drains as for
any other cover. The profile still ends each day at or above field
capacity, and ET is unchanged.

For these covers the groundwater flux is then `DRAINS - WETSUPS`: on
the test parcels that is about -4 in/yr for cattails (rain 23.6 in,
ET 27.4 in).

**This is a science change, not only a bug fix.** It assumes that rain
satisfies wetland ET before groundwater does. NeDNR may prefer another
rule (for example, ET from groundwater only, with all rain recharging);
the switch keeps the original available either way.

**Test.** `test_wetland_balance` for all five covers: off, drainage is 0
every year although rain soaks in, and nothing is reported as supply; on,
both are reported, the water balance error shrinks, and ET is unchanged.

This was suspected in the technical reference and is now confirmed.

## DRAINAGE_SPREAD: held-back drainage water spread over uncounted layers

**Original** (DEPLT 2386-2432). After moving water above field capacity
down the profile, the part that does not drain that day (`1 - DFRACT`)
is spread evenly as `DIST = (1 - DFRACT) * EXTRA / DISTD` over every layer
at or above field capacity. `DISTD` (the depth of those layers) leaves out
any layer that was exactly at field capacity before the first wet layer
was found, but those layers still get `DIST`, so water is created. It is
rare for crops but happens daily for wetlands with `WETLAND_BALANCE` on,
since their layers are held at field capacity.

**Fix.** Count `DISTD` over exactly the layers that receive `DIST`.

**Test.** `test_drainage_spread`: cattails with `WETLAND_BALANCE`; the
yearly water balance error is over 0.5 in with this fix off and under
0.001 in with it on.

The earlier review noted this as possible but unmeasured.

## KNOWN_DATE_RAIN: all rain counted as effective in known-date runs

**Original** (DEPLT 2032). For runs with known irrigation dates
(`IRRTYP 2`), effective precipitation is overwritten with the day's
total precipitation after runoff and snow have been worked out. Runoff is
still reported and snow is still stored, so that water is counted twice:
once as runoff or snow, and again as infiltration.

**Fix.** Keep the effective precipitation from the runoff calculation, as
for every other irrigation type.

**Test.** `test_known_date_rain`: off, effective rain equals total rain
while runoff is also reported and the yearly water balance is off by more
than 0.1 in; on, effective rain is less than total and the balance closes.

This matters for the two-pass irrigation design, whose applied-water pass
uses `IRRTYP 2`. It was suspected in the technical reference and is now
confirmed.
