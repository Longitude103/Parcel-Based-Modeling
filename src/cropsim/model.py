"""Python objects for CropSim inputs and results, and the Engine that runs them."""

from __future__ import annotations

import copy
import ctypes
from dataclasses import dataclass, field

from . import _lib

STATUS_MESSAGES = {
    1: "negative runoff or effective precipitation above rain (EFPRECIP check)",
    2: "effective precipitation above rain (DEPLT check)",
    3: "transpiration loop did not converge",
    4: "negative monthly runoff",
    10: "cs_set_block has not been called",
    11: "an input is out of range",
}

CROP_NAMES = ("SM.GRAIN", "ED BEANS", "SOYBEANS", "POTATOES", "S. BEETS", "SORGHUM",
              "W. WHEAT", "CORN", "SUNFLOWR", "ALFALFA", "IRR HAY", "IRR PAST",
              "N. RANGE", "TURF", "FALLOW", "R. WOODS", "NR. WOOD", "CATTAILS",
              "REED/RUSH", "SHAL H2O", "DEEP H2O", "FARMSTED")


class CropSimError(RuntimeError):
    """Raised when the engine reports an error for a run."""

    def __init__(self, status: int):
        self.status = status
        super().__init__(f"CropSim status {status}: {STATUS_MESSAGES.get(status, 'unknown error')}")


def _zeros(n: int) -> list[float]:
    return [0.0] * n


@dataclass
class Block:
    """Model parameters from BLOCK.DAT. Per-crop lists have 22 entries."""

    etrfact: float = 1.0
    nfday: int = 0
    ytrend: int = 0
    depth: list[float] = field(default_factory=lambda: _zeros(10))
    ydens: list[float] = field(default_factory=lambda: _zeros(22))
    resrat: list[float] = field(default_factory=lambda: _zeros(22))
    spgrav: list[float] = field(default_factory=lambda: _zeros(22))
    fragil: list[int] = field(default_factory=lambda: [0] * 22)
    restyp: list[int] = field(default_factory=lambda: [0] * 22)
    cc: list[list[list[float]]] = field(
        default_factory=lambda: [[_zeros(10) for _ in range(3)] for _ in range(22)])
    """Crop coefficients cc[crop-1][stage][point]."""
    kcl: list[float] = field(default_factory=lambda: _zeros(22))
    kcu: list[float] = field(default_factory=lambda: _zeros(22))
    tbase: list[float] = field(default_factory=lambda: _zeros(22))
    tceil: list[float] = field(default_factory=lambda: _zeros(22))
    snow: list[float] = field(default_factory=lambda: _zeros(7))
    """SFTMP, SMFMX, SMFMN, SNOCOVMX, SNOCOV1, SNOCOV2, TIMP."""
    cnfallow: list[float] = field(default_factory=lambda: _zeros(4))
    cn: list[list[float]] = field(default_factory=lambda: [_zeros(4) for _ in range(22)])
    """Curve numbers cn[crop-1][hydrologic group A-D]."""


@dataclass
class Tillage:
    code: int
    factor1: float
    factor2: float
    name: str = ""


@dataclass
class Sim:
    """One crop / irrigation / tillage combination (a .SIM file)."""

    crop: int = 8
    layers: int = 10
    implt: int = 0
    idplt: int = 0
    imbg: int = 1
    idbg: int = 1
    imend: int = 12
    idend: int = 31
    gddveg: float = 0.0
    gddflo: float = 0.0
    gddripe: float = 0.0
    gyform: float = 0.0
    gddefc: float = 0.0
    gddmat: float = 0.0
    ncut: int = 0
    jdycut: list[int] = field(default_factory=lambda: [0] * 5)
    rzmin: float = 0.0
    rzmax: float = 0.0
    tbreak: float = 0.0
    gddroot: float = 0.0
    rzmgmt: float = 0.0
    iyield: int = 0
    ymax: float = 0.0
    ycoeff: float = 0.0
    iterrc: int = 0
    chand: float = 0.0
    chanw: float = 0.0
    tintrv: float = 0.0
    ntills: int = 0
    itflag: int = 0
    tillage_ops: list[tuple[int, int, int]] = field(default_factory=list)
    """(timing code ITILTM, days TILDAY, tillage code TILCOD) per operation."""
    irrtyp: int = 1
    pad: list[float] = field(default_factory=lambda: _zeros(5))
    rainal: list[float] = field(default_factory=lambda: _zeros(5))
    syscap: float = 0.0
    iper: list[float] = field(default_factory=lambda: _zeros(5))
    apmin: list[float] = field(default_factory=lambda: _zeros(5))
    apmax: list[float] = field(default_factory=lambda: _zeros(5))
    smalli: list[float] = field(default_factory=lambda: _zeros(5))
    gstart: float = 0.0
    gstop: float = 0.0
    irrsch: int = 1
    jfirst: int = 0
    jstopi: int = 0
    jgoi: int = 0
    jdfreq: int = 0
    ddepth: float = 0.0
    eapp: list[float] = field(default_factory=lambda: _zeros(5))
    ereuse: list[float] = field(default_factory=lambda: _zeros(5))
    prunof: list[float] = field(default_factory=lambda: _zeros(5))
    # IRRTYP = 2 (known irrigation dates and depths)
    fdfile: str = ""
    alpha1: float = 0.0
    sim_airdry: list[float] = field(default_factory=lambda: _zeros(2))
    sim_fieldc: list[float] = field(default_factory=lambda: _zeros(10))
    sim_pwp: list[float] = field(default_factory=lambda: _zeros(10))
    sim_bulkd: float = 0.0
    irrigation_events: list[tuple[int, float, float]] = field(default_factory=list)
    """(day of year, gross depth in, fraction infiltrated), used when irrtyp == 2."""

    def copy(self) -> "Sim":
        return copy.deepcopy(self)


@dataclass
class Soil:
    """Soil properties for one soil class (a NESOILS.DAT row)."""

    soil: int
    bulkd: float
    orgm: float
    fieldc: list[float]
    pwp: list[float]
    airdry: list[float]
    drncoe: float = 0.5
    drnday: float = 2.0


@dataclass
class Weather:
    """One year of daily weather starting on start_month/start_day."""

    year: int
    start_month: int
    start_day: int
    lat: float
    long: float
    elev: float
    tmax: list[float]
    tmin: list[float]
    precip: list[float]
    epan: list[float]
    etr: list[float]
    header: str = ""


@dataclass
class State:
    """Carryover state for one soil between years (the INITIAL.DAT contents)."""

    theta: list[float]
    oldcrp: int = 15
    oldres: float = 0.0
    livecrop: int = 0
    snotmp: float = 0.0
    snoh2o: float = 0.0
    soilt: list[float] = field(default_factory=lambda: _zeros(10))

    def copy(self) -> "State":
        return copy.deepcopy(self)


@dataclass
class Result:
    """Results for one year. Monthly values are lists of 12 (Jan-Dec), weekly of 53."""

    status: int
    crop: int
    crop_yr: int
    crop_mon: int
    year: int
    annual: dict[str, float]
    monthly: dict[str, list[float]]
    weekly: dict[str, list[float]]
    state: State
    daily: dict[str, list[float]] | None = None
    """Daily series by day of year (kernel only)."""


def _fill(arr, values) -> None:
    for i, v in enumerate(values):
        arr[i] = v


class Engine:
    """CropSim engine. Set the block and tillage once, then run years.

    The engine has no hidden carryover: each call takes the soil state in
    and returns the new state, so keep one State per soil per parcel.
    """

    def __init__(self, block: Block, tillage: list[Tillage]):
        self._lib = _lib.lib()
        self.set_block(block)
        self.set_tillage(tillage)

    def set_block(self, b: Block) -> None:
        f = ctypes.c_float
        i = ctypes.c_int
        cc = (f * 660)()
        for crop in range(22):
            for stage in range(3):
                for pt in range(10):
                    cc[crop + 22 * stage + 66 * pt] = b.cc[crop][stage][pt]
        cn = (f * 88)()
        for crop in range(22):
            for g in range(4):
                cn[crop + 22 * g] = b.cn[crop][g]
        status = self._lib.cs_set_block(
            b.etrfact, b.nfday, b.ytrend, (f * 10)(*b.depth),
            (f * 22)(*b.ydens), (f * 22)(*b.resrat), (f * 22)(*b.spgrav),
            (i * 22)(*b.fragil), (i * 22)(*b.restyp), cc,
            (f * 22)(*b.kcl), (f * 22)(*b.kcu), (f * 22)(*b.tbase), (f * 22)(*b.tceil),
            (f * 7)(*b.snow), (f * 4)(*b.cnfallow), cn)
        if status:
            raise CropSimError(status)

    def set_tillage(self, rows: list[Tillage]) -> None:
        n = len(rows)
        if n == 0:
            return
        status = self._lib.cs_set_tillage(
            n, (ctypes.c_int * n)(*[r.code for r in rows]),
            (ctypes.c_float * n)(*[r.factor1 for r in rows]),
            (ctypes.c_float * n)(*[r.factor2 for r in rows]))
        if status:
            raise CropSimError(status)

    @staticmethod
    def _sim_struct(s: Sim) -> _lib.SimT:
        t = _lib.SimT()
        for name in ("crop", "layers", "implt", "idplt", "imbg", "idbg", "imend", "idend",
                     "gddveg", "gddflo", "gddripe", "gyform", "gddefc", "gddmat", "ncut",
                     "rzmin", "rzmax", "tbreak", "gddroot", "rzmgmt", "iyield", "ymax",
                     "ycoeff", "iterrc", "chand", "chanw", "tintrv", "itflag", "irrtyp",
                     "syscap", "gstart", "gstop", "irrsch", "jfirst", "jstopi", "jgoi",
                     "jdfreq", "ddepth", "alpha1"):
            setattr(t, name.upper(), getattr(s, name))
        _fill(t.JDYCUT, s.jdycut)
        t.NTILLS = len(s.tillage_ops)
        for k, (tm, day, code) in enumerate(s.tillage_ops):
            t.ITILTM[k], t.TILDAY[k], t.TILCOD[k] = tm, day, code
        for name in ("pad", "rainal", "iper", "apmin", "apmax", "smalli", "eapp", "ereuse",
                     "prunof"):
            _fill(getattr(t, name.upper()), getattr(s, name))
        _fill(t.AIRDRY, s.sim_airdry)
        _fill(t.FIELDC, s.sim_fieldc)
        _fill(t.PWP, s.sim_pwp)
        t.BULKD = s.sim_bulkd
        t.KIRR = len(s.irrigation_events)
        for k, (doy, gross, frac) in enumerate(s.irrigation_events):
            t.FDIRRIG[k][0], t.FDIRRIG[k][1], t.FDIRRIG[k][2] = doy, gross, frac
        return t

    @staticmethod
    def _soil_struct(s: Soil) -> _lib.SoilT:
        t = _lib.SoilT(SOIL=s.soil, BULKD=s.bulkd, ORGM=s.orgm, DRNCOE=s.drncoe, DRNDAY=s.drnday)
        _fill(t.FIELDC, s.fieldc)
        _fill(t.PWP, s.pwp)
        _fill(t.AIRDRY, s.airdry)
        return t

    @staticmethod
    def _weather_struct(w: Weather) -> _lib.WeatherT:
        n = len(w.tmax)
        t = _lib.WeatherT(YEAR=w.year, IMSTR=w.start_month, IDSTR=w.start_day, NDAYS=n,
                          LAT=w.lat, LONG=w.long, ELEV=w.elev)
        for name in ("tmax", "tmin", "precip", "epan", "etr"):
            _fill(getattr(t, name.upper()), getattr(w, name))
        return t

    @staticmethod
    def _state_struct(s: State) -> _lib.StateT:
        t = _lib.StateT(OLDCRP=s.oldcrp, LIVECROP=s.livecrop, OLDRES=s.oldres,
                        SNOTMP=s.snotmp, SNOH2O=s.snoh2o)
        _fill(t.THETA, s.theta)
        _fill(t.SOILT, s.soilt)
        return t

    def run_year(self, sim: Sim, soil: Soil, weather: Weather, state: State, *,
                 livecond: bool = False, legacy_rounding: bool = False,
                 raise_on_error: bool = True) -> Result:
        """Run one year and return its results and the end-of-year state.

        legacy_rounding rounds the returned state the way the original
        INITIAL.DAT file did, which is needed to match old runs exactly.
        """
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
        out_state = _lib.StateT()
        res = _lib.ResultT()
        status = self._lib.cs_run_year(
            ctypes.byref(self._sim_struct(sim)), ctypes.byref(self._soil_struct(soil)),
            ctypes.byref(self._weather_struct(weather)), ctypes.byref(self._state_struct(state)),
            int(livecond), int(legacy_rounding), ctypes.byref(out_state), ctypes.byref(res))
        if status and raise_on_error:
            raise CropSimError(status)
        new_state = State(theta=list(out_state.THETA), oldcrp=out_state.OLDCRP,
                          oldres=out_state.OLDRES, livecrop=out_state.LIVECROP,
                          snotmp=out_state.SNOTMP, snoh2o=out_state.SNOH2O,
                          soilt=list(out_state.SOILT))
        annual = {name.lower(): getattr(res, name) for name, _ in _lib.ResultT._fields_
                  if name not in _lib.MONTHLY + _lib.WEEKLY + ("NUMIRR", "STATUS")}
        monthly = {name.lower(): list(getattr(res, name)) for name in _lib.MONTHLY}
        monthly["numirr"] = list(res.NUMIRR)
        weekly = {name.lower(): list(getattr(res, name)) for name in _lib.WEEKLY}
        return Result(status=status, crop=sim.crop, crop_yr=res.CROP_YR, crop_mon=res.CROP_MON,
                      year=weather.year, annual=annual, monthly=monthly, weekly=weekly,
                      state=new_state)
