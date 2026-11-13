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
| 10 | 1024 | `RESIDUE_CN` | Row crops after maturity: runoff, so infiltration and DP |
| 11 | 2048 | `IRRIGATION_DEPTH` | Demand-scheduled irrigation depth, so NIR, DP and ET |
| 12 | 4096 | `DRAINAGE_CLOCK` | Timing of deep percolation (faster); small change in annual DP and ET |
| 13 | 8192 | `INFILTRATION_OUTPUT` | Monthly infiltration output (INFMON) only |
| 14 | 16384 | `ET_ACCUMULATION` | Seasonal ET for the yield model (ETMAX, ETYLD) on very low-ET days only |
| 15 | 32768 | `FALLOW_CROP` | Summer fallow: end-of-year crop, live-crop flag and yield (then next year's wheat logic) |
| 16 | 65536 | `PERENNIAL_ROOTS` | Perennial covers (crops 10-14, 16-19): root depth, so T, ET, DP; removes a NaN in the original |
| 17 | 131072 | `RZMIN_CAP` | Shallow soils where RZMIN exceeds the scaled RZMAX: root depth, so T, NIR, DP |
| 18 | 262144 | `LEAP_CALENDAR` | Leap years: SIM dates after February (a day later), the last day simulated (Dec 31), and monthly totals |
| 19 | 524288 | `TAILWATER_FURROW` | Rotation-scheduled IRRTYP 5: infiltrated irrigation, so DP and ET |

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

## RESIDUE_CN: residue reduction applied twice to the curve number

**Original** (EFPRECIP 1641). For row and grain crops the curve number is
reduced for surface residue by `(1 - CNFACT)`. After maturity it is set to
`CNFALO * (1 - CNFACT)`, but `CNFALO` already includes that factor, so
post-harvest runoff is too low where there is residue.

**Fix.** After maturity use `CNFALO`.

**Test.** `test_residue_cn`: dryland corn; runoff before maturity is
unchanged and runoff after maturity is higher with the fix on.

Suspected in the technical reference; confirmed.

## IRRIGATION_DEPTH: irrigation sized from the whole profile

**Original** (IRRIGA 2804, 2892, 2953). Demand scheduling decides to
irrigate when today's depletion of the management zone (`AWDPLN`, the
top `RZMGMT` of the root zone) passes the allowable depletion, but sizes
the net irrigation from `DPLN`: the depletion of the whole 10-layer
profile at the end of the previous day. That is usually larger (deeper
soil, and before today's rain), so each irrigation refills more than the
management zone needs; `APMAX` hides most of it in practice.

**Fix.** Size the net irrigation from `AWDPLN`, the same depletion that
triggers it.

**Test.** `test_irrigation_depth`: corn with no rain allowance and no
practical application limits; on dry days with no root growth the net
irrigation equals yesterday's whole-profile depletion with the fix off,
and the management-zone depletion with it on, and the average irrigation
is smaller with the fix on.

**Check with NeDNR.** This may be intended (refill the whole profile). The
earlier review flagged it as "check intent"; the switch lets both be run.

## DRAINAGE_CLOCK: drainage clock restarted with no water added

**Original** (DEPLT 2018-2034, 2146). Drainage of water above field
capacity speeds up with the days since the profile was last wetted
(`DFRACT = ((JDAY - JDYWET + 1)/DRNDAY)^DRNCOE`). `JDYWET` is reset on
every day with snow on the ground or rain (even if it all ran off or
went into the snowpack) and on every day irrigation is considered, even
when none is applied. For irrigated crops in season that is every day, so
drainage stays at its slow first-day rate.

**Fix.** Restart the clock only on days when water actually soaks in.

**Test.** `test_drainage_clock`: irrigated corn; with the fix on, no
drainage happens more than `DRNDAY` days after the last wetting (the
excess is gone by then, as the formula intends); with it off, it does.

The earlier review measured this at most 0.01 in/month on its inputs.

## INFILTRATION_OUTPUT: monthly infiltration always zero

**Original** (DEPLT 2563). `INFMON` adds `DINF` after the infiltration
routine has already set it to 0, so monthly infiltration is always
reported as 0.

**Fix.** Add the day's infiltrated rain and irrigation.

**Test.** `test_infiltration_output`: off, `INFMON` is all zeros; on, it
sums to the effective rain plus infiltrated irrigation, and nothing else
changes.

## ET_ACCUMULATION: stale evaporation in seasonal ET

**Original** (DEPLT 2201, 2327). On days when potential evaporation is at
or below 0.001 in, the evaporation routine is skipped (no evaporation),
but the seasonal ET totals used for yield (`ETMAX`, `ETYLD`) still add
`E1 + E2`, which hold the last day evaporation was computed.

**Fix.** Add the day's evaporation.

**Test.** `test_et_accumulation`: corn with some very dull mid-season days
(ETR 0.001 in): `ETMAX` is larger with the fix off. With ordinary weather
the results are identical, since such days do not occur.

## FALLOW_CROP: summer fallow becomes winter wheat

Found while rewriting `DEPLT`; not in the earlier review.

**Original** (DEPLT 2719-2732). To label dryland wheat-fallow years as
fallow (15) in the monthly file, `DEPLT` sets `CROP = 15` for such wheat
years, writes the file, and then sets any crop 15 matching the same test
back to 7. That test also catches real summer fallow (crop 15, dryland),
which leaves `DEPLT` as winter wheat. Its yield is then computed as wheat
from zero transpiration (NaN), its end-of-year state says the last crop
was wheat, and the wheat "live crop" flag is set (a wheat crop planted
this fall), which changes the next year's start if wheat follows. The output files still say 15, so
this does not show in the reports.

**Fix.** Leave crop 15 as 15.

**Test.** `test_fallow_crop`: off, the state after each fallow year says
wheat with a live crop and the yield is NaN; on, the crop
stays 15 with no live crop and the yield is `YMAX`, while the year's water
balance is the same.

## PERENNIAL_ROOTS: perennial forage roots at full depth

**Original** (ROOTZN 1742, SIM reader 831). Root depth grows from `RZMIN`
at `GDDROOT` to `RZMAX` at `GDDFLO`. Only crops 1-9 read `GDDFLO` from
the SIM file. For crops 10 and up it is 0 in the kernel (in the original
program it keeps whatever the previous SIM file set, so results depend on
run order). With `GDDFLO = 0` the equation gives `RZMAX` only on a day
with no growing degree days yet, and falls toward `RZMIN` as they accrue.
A water balance that starts on Jan 1 gets `RZMAX` on day 1 and keeps it,
but one that starts after planting (GDD already above 0) keeps the roots
at `RZMIN` all year. On the test parcels that also leads to a 0/0 in the
uptake loop, and every layer's water turns NaN from the second day.

**Fix.** Decided by Heath (2026-11-13): perennial crops are already
established, so they use the soil-scaled `RZMAX` every day and skip the
growth equation. The covers counted as perennial:

| Code | Cover | Perennial roots |
| --- | --- | --- |
| 10-13 | Alfalfa, irrigated hay, irrigated pasture, native pasture/range | Yes |
| 14 | Urban turf | Yes |
| 15 | Summer fallow | No (no crop) |
| 16, 17 | Riparian and non-riparian woodlands | Yes |
| 18, 19 | Wetlands: cattails and bulrush, reed swamp | Yes |
| 20, 21 | Open water, shallow and deep | No (ET comes from the water) |
| 22 | Residential, roads, farmsteads | No (mixed cover) |

**Test.** `test_perennial_roots`: alfalfa whose balance starts on Apr 15
(`alfalfa_spring_start`). Off, the roots stay at `RZMIN` (4 in) all
season; on, they stay at `RZMAX` (33.6 in on soil 421, 48 in on 832) and
transpiration rises. A Jan 1 start and row crops are unchanged.

## RZMIN_CAP: starting root depth deeper than the soil allows

**Original** (849-856). For soils in the 300-600 series `RZMAX` and
`RZMGMT` are scaled down (to as little as 60%), but `RZMIN` is not. If
`RZMIN` is larger than the scaled `RZMAX`, the root depth equation clips
to `RZMAX` and then raises it back to `RZMIN`, so the roots start, and
stay, deeper than the soil's limit.

**Fix.** Decided by Heath (2026-11-13): cap `RZMIN` at the soil-scaled
`RZMAX`.

**Test.** `test_rzmin_cap`: irrigated corn with `RZMIN` 16 in and `RZMAX`
20 in (`corn_shallow_roots`). On soil 421 `RZMAX` scales to 14 in; off,
the roots sit at 16 in, on, at 14 in. Soils 622 and 832, where `RZMIN` is
below the scaled `RZMAX`, are unchanged.

## LEAP_CALENDAR: no leap years

**Original** (DAYOFYR 1549, CALDAY 1455). Month-day dates from the SIM
file (planting, start and end of the water balance) become days of the
year through a fixed 365-day table, and daily values are added to months
through the same table. The weather is read by day of year: a .WEA file
holds one row per day, labelled year and day of year (`2012060` is
Feb 29), with 366 rows in a leap year. In a leap year:

* every SIM date after February lands a day early (May 5 becomes day 125,
  which is May 4);
* an end date of Dec 31 becomes day 365, so the last day of weather is
  never simulated and the state carried into the next year is from Dec 30;
* Feb 29 is added to March, and the first day of every later month to the
  month before.

Dates given as days of the year (cutting dates, `JFIRST`, `JSTOPI`, `JGOI`,
known irrigation dates) are not converted and are not changed by the fix.

**Fix.** Decided by Heath (2026-11-13): use a leap-aware calendar
(Gregorian rule on the weather year) for both conversions.

**Test.** `test_leap_calendar`: corn in 2012. Off, the run ends on day
365 and each month's ETR total is the sum over the 365-day table's days;
on, it ends on day 366, planting is a day later, and each month's total is
the sum over the real calendar month. 2011 is unchanged.

## TAILWATER_FURROW: tailwater for IRRTYP 5 in rotation scheduling only

**Original** (IRRIGA 2824, 2857, 2911, 2972). Water that infiltrates from
an irrigation is reduced by tailwater runoff and increased by its reuse
(`PRUNOF`, `EREUSE`). Demand scheduling applies this only to furrow
irrigation (`IRRTYP` 4); rotation deliveries (`IRRSCH` 3) apply it to
`IRRTYP` 4 and 5.

**Fix.** Decided by Heath (2026-11-13): tailwater applies only to furrow
irrigation (`IRRTYP` 4). Other types infiltrate the net irrigation, as in
demand scheduling.

**Test.** `test_tailwater_furrow`: border irrigation (`IRRTYP` 5) on
rotation (`corn_border`). Off, each day's infiltrated water is the gross
depth times `1 - (1 - EREUSE)*PRUNOF`; on, it is the gross depth times
`EAPP`. A furrow (`IRRTYP` 4) rotation run is unchanged.
