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
