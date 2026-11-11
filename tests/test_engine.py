"""Behaviour of the library that the original program did not have."""

import subprocess
import sys
from pathlib import Path

import pytest

from cropsim import CropSimError, Engine, legacy

FIX = Path(__file__).parent / "fixtures"
ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture(scope="module")
def inputs():
    engine = Engine(legacy.read_block(FIX / "BLOCK.DAT"), legacy.read_tillage(FIX / "TILLAGE.DAT"))
    soils = legacy.read_soils(FIX / "NESOILS.DAT")
    weather = legacy.read_weather(FIX / "wea" / "TEST2012.WEA")
    state = legacy.read_initial(FIX / "INITIAL.DAT")
    return engine, soils, weather, state


def test_engine_file_is_generated_from_frozen_original():
    subprocess.run([sys.executable, str(ROOT / "tools" / "make_engine.py"), "--check"],
                   check=True)


def test_no_state_leaks_between_runs(inputs):
    """A run depends only on its inputs, not on what ran before it."""
    engine, soils, weather, state = inputs
    corn = legacy.read_sim(FIX / "sim" / "CRNIRR01.SIM")
    wheat = legacy.read_sim(FIX / "sim" / "WWTDRY01.SIM")
    first = engine.run_year(corn, soils[622], weather, state)
    engine.run_year(wheat, soils[832], weather, state)
    engine.run_year(corn, soils[421], weather, first.state)
    again = engine.run_year(corn, soils[622], weather, state)
    assert again.annual == first.annual
    assert again.monthly == first.monthly
    assert again.state == first.state


def test_input_state_is_not_changed(inputs):
    engine, soils, weather, state = inputs
    before = state.copy()
    engine.run_year(legacy.read_sim(FIX / "sim" / "CRNDRY01.SIM"), soils[622], weather, state)
    assert state == before


def test_known_irrigation_events(inputs):
    """IRRTYP 2 applies the given irrigations (the second pass of the two-pass plan)."""
    engine, soils, weather, state = inputs
    sim = legacy.read_sim(FIX / "sim" / "CRNDRY01.SIM")
    sim.irrtyp = 2
    soil = soils[622]
    sim.sim_fieldc, sim.sim_pwp = soil.fieldc, soil.pwp
    sim.sim_airdry, sim.sim_bulkd = soil.airdry, soil.bulkd
    sim.irrigation_events = [(180, 1.0, 0.85), (195, 1.0, 0.85), (210, 1.25, 0.85)]
    r = engine.run_year(sim, soil, weather, state)
    # The engine counts IRRTYP 2 events from 1, so IRIGNO ends one above the count.
    assert r.annual["irigno"] == 4
    assert r.annual["sgrirr"] == pytest.approx(3.25)
    assert r.annual["snirr"] == pytest.approx(3.25 * 0.85, rel=1e-5)
    assert sum(r.monthly["irgmon"]) == pytest.approx(3.25)


def test_bad_input_raises(inputs):
    engine, soils, weather, state = inputs
    sim = legacy.read_sim(FIX / "sim" / "CRNDRY01.SIM")
    sim.crop = 99
    with pytest.raises(CropSimError):
        engine.run_year(sim, soils[622], weather, state)
