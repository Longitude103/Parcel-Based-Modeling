"""Each bug fix: a test that shows the original behaviour (fix off) and the
corrected behaviour (fix on). See docs/kernel/fixes.md.
"""

from __future__ import annotations

import math

import pytest

import scenarios as sc
from cropsim import ALL_FIXES, Fix, Kernel


@pytest.fixture(scope="module")
def inp():
    return sc.inputs()


@pytest.fixture(scope="module")
def kernel(inp):
    return Kernel(inp.block, inp.tillage)


def chain(kernel, inp, name, soil=622, fixes=Fix.NONE, sim=None):
    sim = sim or sc.scenarios()[name]
    return sc.run_chain(kernel.run_year, sim, inp.soils[soil], inp, fixes=fixes)


def season(r):
    """Day-of-year indexes (0-based) simulated in a result."""
    return range(r.annual["jdybg"] - 1, r.annual["jdyend"])


def corn_kc(gdd, gddmat, kcu=1.0, kcl=0.2):
    """CROPCO's corn curve (Watts 1982, Stegman 1988)."""
    kc = kcu
    if gdd < 0.42 * gddmat:
        kc = 0.15 + .85 * (gdd - 0.12 * gddmat) / (0.3 * gddmat)
    if gdd <= 0.12 * gddmat:
        kc = 0.15
    if gdd > 0.78 * gddmat:
        kc = 1.0 - 0.7 * (gdd - 0.78 * gddmat) / (0.22 * gddmat)
    if gdd > gddmat:
        kc = 0.15
    return min(max(kc, 0.15, kcl), kcu)


def test_kc_gdd_lag(kernel, inp):
    sim = sc.scenarios()["corn_dry"]
    w = inp.weather[2012]
    for fixes, lag in ((Fix.NONE, 1), (Fix.KC_GDD_LAG, 0)):
        r = kernel.run_year(sim, inp.soils[622], w, inp.initial, fixes=fixes)
        gdd, kc = r.daily["gdd"], r.daily["kc"]
        frz = r.annual["jdyfrz"]
        for d in range(r.annual["jdyplt"], frz - 1):
            assert kc[d] == pytest.approx(corn_kc(gdd[d - lag], sim.gddmat), abs=1e-5), (fixes, d)


def test_snowmelt_base(kernel, inp):
    """Off: snow melts on days below freezing. On: only above SMTMP (32 F)."""
    melt_below_32 = {}
    for fixes in (Fix.NONE, Fix.SNOWMELT_BASE):
        n = 0
        for r in chain(kernel, inp, "range", fixes=fixes):
            snow = r.daily["snow"]
            tmax = inp.weather[r.year].tmax
            for d in season(r):
                if d > 0 and r.daily["precip"][d] == 0 and snow[d] < snow[d - 1] - 1e-6:
                    assert tmax[d] > 0.0
                    if tmax[d] <= 32.0:
                        n += 1
        melt_below_32[fixes] = n
    assert melt_below_32[Fix.NONE] > 0
    assert melt_below_32[Fix.SNOWMELT_BASE] == 0


@pytest.mark.parametrize("name", ["corn_pivot", "corn_forecast_rain", "corn_known_dates"])
def test_irrigation_count(kernel, inp, name):
    for fixes in (Fix.NONE, Fix.IRRIGATION_COUNT):
        for r in chain(kernel, inp, name, fixes=fixes):
            days = [d + 1 for d in season(r) if r.daily["grirr"][d] > 0]
            assert days
            if fixes:
                assert r.annual["irigno"] == len(days)
                assert r.annual["jfirst"] == days[0]
            elif name == "corn_forecast_rain":
                assert r.annual["irigno"] > len(days) + 1   # counts dry checks too
            else:
                assert r.annual["irigno"] == len(days) + 1
                assert r.annual["jfirst"] == 0


@pytest.mark.parametrize("name", ["soy_rotation", "alfalfa_rotation", "corn_border"])
def test_rotation_frequency(kernel, inp, name):
    freq = sc.scenarios()[name].jdfreq
    gaps = {}
    for fixes in (Fix.NONE, Fix.ROTATION_FREQUENCY):
        g = []
        for r in chain(kernel, inp, name, fixes=fixes):
            days = [d for d in season(r) if r.daily["grirr"][d] > 0]
            g += [b - a for a, b in zip(days, days[1:])]
        gaps[fixes] = g
    assert min(gaps[Fix.NONE]) < freq
    assert min(gaps[Fix.ROTATION_FREQUENCY]) >= freq
