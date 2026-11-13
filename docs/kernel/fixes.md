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
