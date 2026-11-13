"""Reading the IRRSCH 3 rotation line of .SIM files in either layout, and
upgrading older files (cropsim.legacy.read_sim, upgrade_sim)."""

from __future__ import annotations

import logging
from pathlib import Path

import pytest

from cropsim import legacy

FIX = Path(__file__).resolve().parent / "fixtures" / "sim"


def rotation_sim(tmp_path: Path, base: str, rotation: str, crop: int | None = None,
                 newline: str = "\n") -> Path:
    """A copy of a fixture SIM on rotation delivery (IRRSCH 3, first
    delivery day 120) with the given rotation line."""
    lines = (FIX / f"{base}.SIM").read_text().splitlines()
    if crop is not None:
        lines[0] = f"{crop} {lines[0].split()[1]}"
    k = next(i for i, ln in enumerate(lines) if ln.startswith("500.0 2500.0"))
    lines[k] = "500.0 2500.0 3 120"
    lines.insert(k + 1, rotation)
    p = tmp_path / f"{base}.SIM"
    p.write_bytes(newline.join(lines + [""]).encode())
    return p


def test_forage_two_values_is_the_original_layout(tmp_path):
    s = legacy.read_sim(rotation_sim(tmp_path, "ALFIRR01", "14 1.5"))
    assert (s.jstopi, s.jgoi, s.jdfreq, s.ddepth) == (0, 0, 14, 1.5)
    assert s.eapp == [0.85] * 5          # the next line is read as EAPP


def test_forage_two_values_keep_previous_cutoff_like_the_original(tmp_path):
    prev = legacy.read_sim(FIX / "CRNIRR01.SIM")
    prev.jstopi, prev.jgoi = 170, 230
    s = legacy.read_sim(rotation_sim(tmp_path, "ALFIRR01", "14 1.5"), previous=prev)
    assert (s.jstopi, s.jgoi) == (170, 230)


def test_forage_four_values(tmp_path, caplog):
    with caplog.at_level(logging.INFO, logger="cropsim"):
        s = legacy.read_sim(rotation_sim(tmp_path, "ALFIRR01", "170 230 14 1.5"))
    assert (s.jstopi, s.jgoi, s.jdfreq, s.ddepth) == (170, 230, 14, 1.5)
    assert s.eapp == [0.85] * 5


def test_row_crop_two_values_tolerated(tmp_path):
    """The original reads four values for row crops and would run on into
    the EAPP line; a two-value line is read as JDFREQ DDEPTH."""
    s = legacy.read_sim(rotation_sim(tmp_path, "CRNIRR01", "10 2.0"))
    assert (s.jdfreq, s.ddepth) == (10, 2.0)
    assert s.eapp == [0.85] * 5


def test_row_crop_four_values(tmp_path):
    s = legacy.read_sim(rotation_sim(tmp_path, "CRNIRR01", "0 0 10 2.0"))
    assert (s.jstopi, s.jgoi, s.jdfreq, s.ddepth) == (0, 0, 10, 2.0)


def test_trailing_comment_is_not_counted(tmp_path):
    s = legacy.read_sim(rotation_sim(tmp_path, "ALFIRR01", "14 1.5   JDFREQ DDEPTH"))
    assert (s.jdfreq, s.ddepth) == (14, 1.5)
    s = legacy.read_sim(rotation_sim(tmp_path, "ALFIRR01", "170 230 14 1.5 ! cutoff"))
    assert (s.jstopi, s.jgoi) == (170, 230)


def test_values_split_over_lines_read_as_the_original(tmp_path):
    s = legacy.read_sim(rotation_sim(tmp_path, "ALFIRR01", "14\n1.5"))
    assert (s.jdfreq, s.ddepth) == (14, 1.5)
    assert s.eapp == [0.85] * 5


def test_short_layout_logs_a_note(tmp_path, caplog):
    with caplog.at_level(logging.INFO, logger="cropsim"):
        legacy.read_sim(rotation_sim(tmp_path, "ALFIRR01", "14 1.5"))
    assert "upgrade_sim" in caplog.text


@pytest.mark.parametrize("newline", ["\n", "\r\n"])
def test_upgrade_sim(tmp_path, newline):
    p = rotation_sim(tmp_path, "ALFIRR01", "  14 1.5  rotation", newline=newline)
    before = p.read_bytes()
    old = legacy.read_sim(p)
    bak = legacy.upgrade_sim(p)
    assert bak == p.with_name("ALFIRR01.SIM.bak")
    assert bak.read_bytes() == before
    after = p.read_bytes().decode()
    assert "  0 0 14 1.5  rotation" + newline in after
    assert after.count(newline) == before.decode().count(newline)
    new = legacy.read_sim(p)
    assert new == old                          # same values, so same results
    assert legacy.upgrade_sim(p) is None       # already upgraded
    # A second upgrade of another old file keeps the first backup.
    p.write_bytes(before)
    assert legacy.upgrade_sim(p) == p.with_name("ALFIRR01.SIM.bak2")


def test_upgrade_sim_leaves_other_files_alone(tmp_path):
    p = tmp_path / "CRNIRR01.SIM"
    p.write_bytes((FIX / "CRNIRR01.SIM").read_bytes())
    assert legacy.upgrade_sim(p) is None
    assert not p.with_name("CRNIRR01.SIM.bak").exists()
