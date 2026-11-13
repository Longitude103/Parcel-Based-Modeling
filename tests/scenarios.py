"""Test parcels for the kernel: golden-output and bug-fix tests.

Each scenario is one crop/irrigation setup run for the six fixture years
(2009-2014) on each of the three fixture soils, carrying its own soil state
from year to year, the way the parcel layer will run them. The setups cover
all 22 crop codes, all irrigation types and scheduling methods, terraces and
known irrigation dates.

The inputs are synthetic (tools/make_fixtures.py), not State data.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from cropsim import legacy
from cropsim.model import Sim

FIX = Path(__file__).resolve().parent / "fixtures"
YEARS = tuple(range(2009, 2015))
SOILS = (421, 622, 832)


def _sim(name: str, **changes) -> Sim:
    s = legacy.read_sim(FIX / "sim" / f"{name}.SIM")
    for k, v in changes.items():
        setattr(s, k, v)
    return s


def _forage(crop: int, irrigated: bool, **changes) -> Sim:
    """A crop 11-22 setup built on the native range SIM."""
    base = _sim("NRANGE01", crop=crop)
    if irrigated:
        irr = _sim("CRNIRR01")
        for k in ("irrtyp", "pad", "rainal", "syscap", "iper", "apmin", "apmax", "smalli",
                  "gstart", "gstop", "irrsch", "eapp", "ereuse", "prunof"):
            setattr(base, k, getattr(irr, k))
    for k, v in changes.items():
        setattr(base, k, v)
    return base


# Known irrigation events for the IRRTYP 2 setup: (day, gross in, fraction).
KNOWN_EVENTS = [(180, 1.2, 0.85), (192, 1.0, 0.85), (205, 1.2, 0.85), (218, 1.0, 0.85),
                (231, 1.1, 0.85), (244, 0.9, 0.85)]


def scenarios() -> dict[str, Sim]:
    s: dict[str, Sim] = {
        # Row and grain crops
        "corn_pivot": _sim("CRNIRR01"),
        "corn_dry": _sim("CRNDRY01"),
        "corn_district_demand": _sim("CRNIRR01", irrsch=2),
        "corn_forecast_rain": _sim("CRNIRR01", irrsch=4),
        "corn_forecast_balance": _sim("CRNIRR01", irrsch=5),
        "corn_furrow": _sim("CRNIRR01", irrtyp=4, ereuse=[0.3] * 5, prunof=[0.25] * 5,
                            eapp=[0.65] * 5),
        "corn_border": _sim("CRNIRR01", irrtyp=5, irrsch=3, jfirst=150, jstopi=0, jgoi=0,
                            jdfreq=10, ddepth=2.0, ereuse=[0.3] * 5, prunof=[0.25] * 5),
        # Known dates take their soil from the SIM (here soil 622's values).
        "corn_known_dates": _sim("CRNIRR01", irrtyp=2, irrigation_events=KNOWN_EVENTS,
                                 alpha1=0.0, sim_airdry=[0.04, 0.07],
                                 sim_fieldc=[0.305, 0.315, 0.325] * 3 + [0.305],
                                 sim_pwp=[0.18, 0.19, 0.2] * 3 + [0.18], sim_bulkd=1.4),
        "corn_terrace": _sim("CRNDRY01", iterrc=1, chand=0.5, chanw=10.0, tintrv=100.0),
        "soy_dry": _sim("SOYDRY01"),
        "soy_rotation": _sim("SOYIRR03"),
        "sorghum_dry": _sim("SORDRY01"),
        "wheat_fallow": _sim("WWTDRY01"),
        "wheat_irrigated": _sim("WWTDRY01", irrtyp=3, pad=[0.5] * 5, rainal=[0.25] * 5,
                                syscap=0.33, iper=[1.0] * 5, apmin=[0.75] * 5,
                                apmax=[1.25] * 5, smalli=[0.5] * 5, gstart=300.0,
                                gstop=1800.0, irrsch=1, eapp=[0.85] * 5),
        "smallgrain_dry": _sim("CRNDRY01", crop=1),
        "beans_pivot": _sim("CRNIRR01", crop=2),
        "potato_pivot": _sim("CRNIRR01", crop=4),
        "sugarbeet_furrow": _sim("CRNIRR01", crop=5, irrtyp=4, ereuse=[0.3] * 5,
                                 prunof=[0.2] * 5, eapp=[0.7] * 5),
        "sunflower_dry": _sim("CRNDRY01", crop=9),
        # Forage
        "alfalfa_pivot": _sim("ALFIRR01"),
        "alfalfa_two_cuts": _sim("ALFIRR01", ncut=2, jdycut=[165, 230, 0, 0, 0]),
        "alfalfa_rotation": _sim("ALFIRR01", irrsch=3, jfirst=120, jstopi=200, jgoi=240,
                                 jdfreq=14, ddepth=1.5),
        "hay_pivot": _sim("ALFIRR01", crop=11, ncut=1, jdycut=[185, 0, 0, 0, 0],
                          gddmat=2600.0),
        "pasture_pivot": _forage(12, True, gddefc=900.0, gddmat=2600.0),
        "pasture_rotation": _forage(12, True, irrsch=3, jfirst=120, jstopi=200, jgoi=240,
                                    jdfreq=14, ddepth=1.5),
        "range": _sim("NRANGE01"),
        "turf_pivot": _forage(14, True),
        "fallow": _forage(15, False),
        "farmstead": _forage(22, False),
        # Woodland, wetland and water
        "riparian_wood": _forage(16, False),
        "upland_wood": _forage(17, False),
        "cattail": _forage(18, False),
        "reed_swamp": _forage(19, False),
        "shallow_water": _forage(20, False),
        "deep_water": _forage(21, False),
    }
    return s


@dataclass
class Inputs:
    block: object
    tillage: list
    soils: dict
    weather: dict
    initial: object


def inputs() -> Inputs:
    return Inputs(
        block=legacy.read_block(FIX / "BLOCK.DAT"),
        tillage=legacy.read_tillage(FIX / "TILLAGE.DAT"),
        soils=legacy.read_soils(FIX / "NESOILS.DAT"),
        weather={y: legacy.read_weather(FIX / "wea" / f"TEST{y}.WEA") for y in YEARS},
        initial=legacy.read_initial(FIX / "INITIAL.DAT"),
    )


def run_chain(run_year, sim: Sim, soil, inp: Inputs, **kw) -> list:
    """Run the six years for one scenario and soil; returns the Results."""
    state = inp.initial.copy()
    out = []
    for y in YEARS:
        r = run_year(sim, soil, inp.weather[y], state, raise_on_error=False, **kw)
        state = r.state
        out.append(r)
    return out
