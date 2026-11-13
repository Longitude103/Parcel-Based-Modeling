"""Write the golden outputs of the original model for the test parcels.

Runs every scenario in tests/scenarios.py (35 crop/irrigation setups x 3
soils x 6 years, each soil carrying its own state) through the reference
engine: the frozen v8.0 source with only the library edits listed in
tools/make_engine.py, whose output tests/test_parity.py checks character
for character against the original program. The annual results and the
end-of-year state are saved at full precision in tests/golden/original.csv.

The kernel with no fixes must reproduce these (tests/test_kernel.py).
Regenerate only if the reference engine itself changes:

    python tools/make_golden.py
"""

from __future__ import annotations

import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))

import scenarios as sc  # noqa: E402
from cropsim import Engine  # noqa: E402

OUT = ROOT / "tests" / "golden" / "original.csv"

INTS = ("status", "crop_yr", "crop_mon", "jdyplt", "jfirst", "jdyefc", "jdymat", "jdyfrz",
        "irigno", "itflag")
FLOATS = ("yield", "yldratio", "etmax", "etyld", "ets", "etrs", "es", "ts", "sgrirr", "snirr",
          "precips", "eprecips", "drains", "dplbg", "totrof")
STATE = ([f"theta{k + 1}" for k in range(10)] + ["oldcrp", "livecrop", "oldres", "snotmp",
                                                 "snoh2o"] + [f"soilt{k + 1}" for k in range(10)])
COLUMNS = ("scenario", "soil", "year") + INTS + FLOATS + tuple(STATE)


def row(name: str, soil: int, r) -> list:
    a = r.annual
    s = r.state
    vals = [name, soil, r.year, r.status, r.crop_yr, r.crop_mon]
    vals += [a[k] for k in INTS[3:]]
    vals += [repr(float(a[k])) for k in FLOATS]
    vals += [repr(float(x)) for x in s.theta]
    vals += [s.oldcrp, s.livecrop, repr(float(s.oldres)), repr(float(s.snotmp)),
             repr(float(s.snoh2o))]
    vals += [repr(float(x)) for x in s.soilt]
    return vals


def main() -> None:
    inp = sc.inputs()
    engine = Engine(inp.block, inp.tillage)
    rows = []
    for name, sim in sc.scenarios().items():
        for code in sc.SOILS:
            for r in sc.run_chain(engine.run_year, sim, inp.soils[code], inp):
                rows.append(row(name, code, r))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(COLUMNS)
        w.writerows(rows)
    print(f"wrote {len(rows)} runs to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
