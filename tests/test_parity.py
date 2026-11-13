"""The library must give the same results as the original CropSim program.

Builds the frozen original (with only its hard-coded paths changed), runs it
on the fixtures, then repeats the same runs through the library and compares
the yearly, monthly and weekly output files and the final INITIAL.DAT text
character for character. The compute kernel (no fixes) is checked the same
way.
"""

import shutil

import pytest

import legacy_run

pytestmark = pytest.mark.skipif(shutil.which("gfortran") is None,
                                reason="gfortran is needed to build the original program")


@pytest.fixture(scope="module")
def outputs(tmp_path_factory):
    work = tmp_path_factory.mktemp("original")
    exe = legacy_run.build_original(work)
    run = work / "run"
    legacy_run.make_run_dir(run)
    return (legacy_run.run_original(exe, run), legacy_run.run_library(),
            legacy_run.run_library(use_kernel=True))


@pytest.mark.parametrize("name", ["yr", "mon", "weekly", "initial"])
def test_matches_original(outputs, name):
    original, library, _ = outputs
    assert library[name].splitlines() == original[name].splitlines()


@pytest.mark.parametrize("name", ["yr", "mon", "weekly", "initial"])
def test_kernel_matches_original(outputs, name):
    original, _, kernel = outputs
    assert kernel[name].splitlines() == original[name].splitlines()
