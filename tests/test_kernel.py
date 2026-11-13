"""The compute kernel against the original model.

* With no fixes, every test parcel must give exactly the reference
  engine's results (annual, monthly, weekly and end-of-year state), run in
  the same process. The reference engine is the frozen original with only
  the library edits, and test_parity.py checks it against the original
  program's output files.
* The golden file (tests/golden/original.csv, from tools/make_golden.py)
  pins the original's results, so a change to the reference engine or the
  build that moves them is caught too.
* Runs are independent and thread-safe.
"""

from __future__ import annotations

import csv
import math
import platform
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pytest

import scenarios as sc
from cropsim import CropSimError, Engine, Kernel

GOLDEN = Path(__file__).resolve().parent / "golden" / "original.csv"


@pytest.fixture(scope="module")
def inp():
    return sc.inputs()


@pytest.fixture(scope="module")
def kernel(inp):
    return Kernel(inp.block, inp.tillage)


@pytest.fixture(scope="module")
def engine(inp):
    return Engine(inp.block, inp.tillage)


def same(a, b) -> bool:
    if isinstance(a, float) and math.isnan(a):
        return isinstance(b, float) and math.isnan(b)
    return a == b


CASES = [(name, soil) for name in sc.scenarios() for soil in sc.SOILS]


@pytest.mark.parametrize("name,soil", CASES)
def test_kernel_equals_reference(inp, kernel, engine, name, soil):
    sim = sc.scenarios()[name]
    ref = sc.run_chain(engine.run_year, sim, inp.soils[soil], inp)
    ker = sc.run_chain(kernel.run_year, sim, inp.soils[soil], inp)
    for a, b in zip(ref, ker):
        where = f"{name} soil {soil} year {a.year}"
        assert a.status == b.status, where
        assert (a.crop_yr, a.crop_mon) == (b.crop_yr, b.crop_mon), where
        for k, v in a.annual.items():
            assert same(v, b.annual[k]), f"{where}: {k} {v} != {b.annual[k]}"
        for k, v in a.monthly.items():
            assert all(map(same, v, b.monthly[k])), f"{where}: monthly {k}"
        for k, v in a.weekly.items():
            assert all(map(same, v, b.weekly[k])), f"{where}: weekly {k}"
        sa, sb = vars(a.state), vars(b.state)
        for k, v in sa.items():
            vals = v if isinstance(v, list) else [v]
            other = sb[k] if isinstance(sb[k], list) else [sb[k]]
            assert all(map(same, vals, other)), f"{where}: state {k}"


def _golden_rows():
    with GOLDEN.open() as f:
        return list(csv.DictReader(f))


def test_kernel_matches_golden(inp, kernel):
    """Golden values, exact on x86-64; within float rounding elsewhere."""
    exact = platform.machine().lower() in ("x86_64", "amd64")
    rows = {(r["scenario"], int(r["soil"]), int(r["year"])): r for r in _golden_rows()}
    assert len(rows) == len(CASES) * len(sc.YEARS)
    for name, sim in sc.scenarios().items():
        for soil in sc.SOILS:
            for r in sc.run_chain(kernel.run_year, sim, inp.soils[soil], inp):
                g = rows[(name, soil, r.year)]
                assert int(g["status"]) == r.status
                assert int(g["irigno"]) == r.annual["irigno"]
                got = dict(r.annual)
                got.update({f"theta{k + 1}": v for k, v in enumerate(r.state.theta)})
                got.update({f"soilt{k + 1}": v for k, v in enumerate(r.state.soilt)})
                got.update(oldres=r.state.oldres, snotmp=r.state.snotmp, snoh2o=r.state.snoh2o)
                for k, v in got.items():
                    if k not in g or k in ("status",):
                        continue
                    want = float(g[k])
                    if math.isnan(want):
                        assert math.isnan(v), (name, soil, r.year, k)
                    elif exact:
                        assert v == want, (name, soil, r.year, k, v, want)
                    else:
                        assert v == pytest.approx(want, rel=1e-4, abs=1e-4), (name, soil, r.year, k)


def test_threads_give_same_results(inp, kernel):
    """Runs on many threads at once match runs made one at a time."""
    jobs = [(sim, inp.soils[soil]) for sim in sc.scenarios().values() for soil in sc.SOILS]

    def run(job):
        sim, soil = job
        return [(r.annual, r.monthly, r.state) for r in
                sc.run_chain(kernel.run_year, sim, soil, inp)]

    serial = [run(j) for j in jobs]
    with ThreadPoolExecutor(max_workers=8) as pool:
        threaded = list(pool.map(run, jobs))
    assert repr(serial) == repr(threaded)


def test_daily_values_add_up(inp, kernel):
    sim = sc.scenarios()["corn_pivot"]
    r = kernel.run_year(sim, inp.soils[622], inp.weather[2012], inp.initial)
    d = r.daily
    assert sum(d["drain"]) == pytest.approx(r.annual["drains"], abs=1e-3)
    assert sum(d["grirr"]) == pytest.approx(r.annual["sgrirr"], abs=1e-3)
    assert sum(d["precip"]) == pytest.approx(r.annual["precips"], abs=1e-3)
    assert sum(d["et"]) == pytest.approx(r.annual["ets"], abs=1e-3)
    assert sum(d["balerr"]) == pytest.approx(r.annual["balerr"], abs=1e-4)


def test_bad_input_is_an_error(inp, kernel):
    sim = sc.scenarios()["corn_pivot"].copy()
    sim.crop = 23
    with pytest.raises(CropSimError) as err:
        kernel.run_year(sim, inp.soils[622], inp.weather[2012], inp.initial)
    assert err.value.status == 11
