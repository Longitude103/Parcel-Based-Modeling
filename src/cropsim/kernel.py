"""The CropSim compute kernel (fortran/kernel).

`Kernel` runs the same model as `Engine` but through the re-written kernel:
no global state (safe to call from many threads), daily results, a water
balance check, and switches for each known bug fix (`Fix`). With
``fixes=Fix.NONE`` it gives the original program's results.
"""

from __future__ import annotations

import ctypes
import enum

from . import _lib
from .model import Block, CropSimError, Engine, Result, Sim, Soil, State, Tillage, Weather


class Fix(enum.IntFlag):
    """Bug-fix switches. Combine with |; see docs/kernel/fixes.md."""

    NONE = 0

    KC_GDD_LAG = 1
    """Crop coefficient uses the day's GDD, not the previous day's (original READWEAT 3693-3697)."""
    SNOWMELT_BASE = 2
    """Snow melts above params%smtmp (default 32 F) instead of an unset SMTMP of 0 F (original SNOWMELT 3994-3999)."""
    IRRIGATION_COUNT = 4
    """Irrigation count and first irrigation date count real irrigations (original DEPLT 2123, IRRIGA 2869-2925)."""
    ROTATION_FREQUENCY = 8
    """Rotation deliveries (IRRSCH 3) at most every JDFREQ days (original DEPLT 2111, JDFREQ read but never used)."""
    FORAGE_CUTTING_STAGE = 16
    """Alfalfa and hay use the current cutting cycle as the growth stage in the water balance (original DEPLT 1880, 1953; ICUT stuck at 1)."""
    ALFALFA_REGROWTH = 32
    """Alfalfa with two cuttings measures its final regrowth from cutting 2 (original CROPCO 3137)."""
    TRANSPIRATION_LIMIT = 64
    """Reported transpiration equals the water taken from the soil (original DEPLT 2267-2310)."""

ALL_FIXES = Fix(0)
for _f in Fix:
    ALL_FIXES |= _f

DAILY = tuple(n[2:] for n in _lib.KDAILY)
"""Names of the daily series in Result.daily (index 0 = Jan 1)."""


class Kernel:
    """CropSim kernel. Holds the parameters; every run is independent."""

    def __init__(self, block: Block, tillage: list[Tillage], *, smtmp: float = 32.0):
        self._lib = _lib.klib()
        self.params = self._params_struct(block, tillage, smtmp)

    @staticmethod
    def _params_struct(b: Block, tillage: list[Tillage], smtmp: float) -> _lib.ParamsT:
        p = _lib.ParamsT(etrfact=b.etrfact, nfday=b.nfday, ytrend=b.ytrend, smtmp=smtmp)
        for name in ("depth", "ydens", "resrat", "spgrav", "fragil", "restyp", "kcl", "kcu",
                     "tbase", "tceil", "cnfallow"):
            arr = getattr(p, name)
            for k, v in enumerate(getattr(b, name)):
                arr[k] = v
        for crop in range(22):
            for stage in range(3):
                for pt in range(10):
                    p.cc[crop + 22 * stage + 66 * pt] = b.cc[crop][stage][pt]
            for g in range(4):
                p.cn[crop + 22 * g] = b.cn[crop][g]
        (p.sftmp, p.smfmx, p.smfmn, p.snocovmx, p.snocov1, p.snocov2, p.timp) = b.snow
        for row in tillage:
            if not 1 <= row.code <= 80:
                raise ValueError(f"tillage code {row.code} is outside 1-80")
            p.tilfac[row.code - 1] = row.factor1
            p.tilfac[row.code - 1 + 80] = row.factor2
        return p

    def run_year(self, sim: Sim, soil: Soil, weather: Weather, state: State, *,
                 fixes: Fix | int = Fix.NONE, livecond: bool = False,
                 legacy_rounding: bool = False, raise_on_error: bool = True) -> Result:
        """Run one year; returns results (with .daily) and the end-of-year state."""
        n = len(weather.tmax)
        if not 1 <= n <= 366:
            raise ValueError(f"weather must have 1 to 366 days, got {n}")
        for name in ("tmin", "precip", "epan", "etr"):
            if len(getattr(weather, name)) != n:
                raise ValueError(f"weather.{name} has {len(getattr(weather, name))} days, "
                                 f"tmax has {n}")
        if len(sim.tillage_ops) > 20:
            raise ValueError("at most 20 tillage operations")
        if len(sim.irrigation_events) > 50:
            raise ValueError("at most 50 irrigation events")
        opt = _lib.OptionsT(fixes=int(fixes), livecond=int(livecond),
                            legacy_round=int(legacy_rounding))
        out_state = _lib.StateT()
        res = _lib.KResultT()
        status = self._lib.csk_run_year(
            ctypes.byref(self.params), ctypes.byref(Engine._sim_struct(sim)),
            ctypes.byref(Engine._soil_struct(soil)), ctypes.byref(Engine._weather_struct(weather)),
            ctypes.byref(Engine._state_struct(state)), ctypes.byref(opt),
            ctypes.byref(out_state), ctypes.byref(res))
        if status and raise_on_error:
            raise CropSimError(status)
        new_state = State(theta=list(out_state.THETA), oldcrp=out_state.OLDCRP,
                          oldres=out_state.OLDRES, livecrop=out_state.LIVECROP,
                          snotmp=out_state.SNOTMP, snoh2o=out_state.SNOH2O,
                          soilt=list(out_state.SOILT))
        skip = set(_lib.MONTHLY + _lib.WEEKLY + _lib.KDAILY + ("NUMIRR", "STATUS", "WSMON"))
        annual = {name.lower(): getattr(res, name) for name, _ in _lib.KResultT._fields_
                  if name not in skip}
        monthly = {name.lower(): list(getattr(res, name)) for name in _lib.MONTHLY + ("WSMON",)}
        monthly["numirr"] = list(res.NUMIRR)
        weekly = {name.lower(): list(getattr(res, name)) for name in _lib.WEEKLY}
        daily = {name[2:]: list(getattr(res, name)) for name in _lib.KDAILY}
        return Result(status=status, crop=sim.crop, crop_yr=res.CROP_YR, crop_mon=res.CROP_MON,
                      year=weather.year, annual=annual, monthly=monthly, weekly=weekly,
                      state=new_state, daily=daily)
