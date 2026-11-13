"""Measure what each bug fix changes, and by how much, on the test parcels.

Runs every scenario in tests/scenarios.py (34 setups x 3 soils x 6 years,
630 runs, each soil carrying its own state) through the kernel with no
fixes, with each fix alone, and with all fixes, and writes the differences
to docs/kernel/fix-impact.md.

The fixture inputs are synthetic, so the sizes are indicative of how each
fix behaves, not of what it will do to the statewide model.

    python tools/fix_impact.py
"""

from __future__ import annotations

import math
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))

import scenarios as sc  # noqa: E402
from cropsim import ALL_FIXES, Fix, Kernel  # noqa: E402

OUT = ROOT / "docs" / "kernel" / "fix-impact.md"

# (key in Result.annual, column label)
METRICS = [
    ("drains", "Deep perc."),
    ("ets", "ET"),
    ("ts", "Transp."),
    ("es", "Evap."),
    ("snirr", "Net irr."),
    ("sgrirr", "Gross irr."),
    ("totrof", "Runoff"),
    ("eprecips", "Eff. precip"),
    ("wetsups", "Wetland supply"),
    ("etmax", "Seasonal ET for yield (ETMAX)"),
    ("etyld", "Seasonal ET for yield (ETYLD)"),
]
COUNTS = [("irigno", "Irrigations"), ("jfirst", "First irr. day")]
KEY = ["drains", "ets", "snirr", "totrof"]
TOL = 1e-4


def run_all(kernel: Kernel, inp, fixes: int) -> dict:
    out = {}
    for name, sim in sc.scenarios().items():
        for code in sc.SOILS:
            rs = sc.run_chain(kernel.run_year, sim, inp.soils[code], inp, fixes=fixes)
            for r in rs:
                out[(name, code, r.year)] = r
    return out


def val(r, key):
    if key == "infmon":
        return float(sum(r.monthly["infmon"]))
    return float(r.annual[key])


def diff(a: float, b: float) -> float:
    if math.isnan(a) and math.isnan(b):
        return 0.0
    if math.isnan(a) or math.isnan(b):
        return math.nan
    return b - a


def fmt(x: float, digits: int = 2) -> str:
    if math.isnan(x):
        return "NaN"
    if abs(x) < 0.5 * 10 ** -digits:
        return "0"
    return f"{x:+.{digits}f}"


def compare(base: dict, other: dict) -> dict:
    """Per run and metric differences; plus which runs changed at all."""
    keys = [k for k, _ in METRICS] + [k for k, _ in COUNTS] + ["yield", "yldratio", "infmon", "balerr"]
    d = {k: {run: diff(val(base[run], k), val(other[run], k)) for run in base} for k in keys}
    changed = set()
    for k in keys:
        if k == "balerr":
            continue
        for run, x in d[k].items():
            if math.isnan(x) or abs(x) > TOL:
                changed.add(run)
    # state differences also count as a change
    for run in base:
        s0, s1 = base[run].state, other[run].state
        if any(abs(a - b) > TOL for a, b in zip(s0.theta, s1.theta)) or \
                s0.livecrop != s1.livecrop or s0.oldcrp != s1.oldcrp:
            changed.add(run)
    return {"d": d, "changed": changed}


def mean(xs):
    xs = [x for x in xs if not math.isnan(x)]
    return sum(xs) / len(xs) if xs else 0.0


def biggest(xs):
    xs = [x for x in xs if not math.isnan(x)]
    return max(xs, key=abs) if xs else 0.0


def by_scenario(cmp: dict, key: str) -> dict:
    acc = defaultdict(list)
    for (name, _soil, _yr), x in cmp["d"][key].items():
        acc[name].append(x)
    return {n: mean(v) for n, v in acc.items()}


def fix_section(fix: Fix, cmp: dict, base: dict, other: dict, total: int) -> list[str]:
    lines = [f"### {fix.name}", ""]
    changed = cmp["changed"]
    if not changed:
        lines += ["No run changed on the test parcels.", ""]
        return lines
    names = sorted({run[0] for run in changed})
    lines += [f"Changed {len(changed)} of {total} runs, in {len(names)} scenario(s): "
              + ", ".join(f"`{n}`" for n in names) + ".", ""]
    rows = []
    for key, label in METRICS + COUNTS + [("infmon", "Infiltration (INFMON)"),
                                          ("yield", "Yield"),
                                          ("yldratio", "Yield ratio")]:
        xs = [cmp["d"][key][r] for r in changed]
        if all((not math.isnan(x)) and abs(x) <= TOL for x in xs):
            continue
        digits = 0 if key in ("irigno", "jfirst") else 3 if key == "yldratio" else 2
        nan = sum(math.isnan(x) for x in xs)
        rows.append(f"| {label} | {fmt(mean(xs), digits)} | {fmt(biggest(xs), digits)} |"
                    + (f" {nan} run(s) change to or from NaN |" if nan else " |"))
    if rows:
        lines += ["| Output | Mean change (changed runs) | Largest change | Note |",
                  "| --- | ---: | ---: | --- |"] + rows + [""]
    else:
        lines += ["Only the carried-over soil state changed.", ""]
    # per scenario for the key water-budget terms
    per = {k: by_scenario(cmp, k) for k in KEY + ["wetsups"]}
    show = [k for k in KEY + ["wetsups"] if any(abs(per[k][n]) > TOL for n in names)]
    if len(names) > 1 and show:
        labels = dict(METRICS)
        lines += ["By scenario (mean change per year over 3 soils x 6 years):", "",
                  "| Scenario | " + " | ".join(labels[k] for k in show) + " |",
                  "| --- |" + " ---: |" * len(show)]
        for n in names:
            lines.append(f"| `{n}` | " + " | ".join(fmt(per[k][n]) for k in show) + " |")
        lines.append("")
    return lines


def main() -> None:
    inp = sc.inputs()
    kernel = Kernel(inp.block, inp.tillage)
    base = run_all(kernel, inp, 0)
    total = len(base)
    fixes = [f for f in Fix if f]
    results = {f: compare(base, run_all(kernel, inp, int(f))) for f in fixes}
    allrun = run_all(kernel, inp, int(ALL_FIXES))
    allcmp = compare(base, allrun)

    out = [
        "# What each fix changes",
        "",
        "Generated by `tools/fix_impact.py`. Do not edit by hand.",
        "",
        f"Every scenario in `tests/scenarios.py` ({len(sc.scenarios())} crop and irrigation "
        f"setups x {len(sc.SOILS)} soils x {len(sc.YEARS)} years = {total} runs, each soil "
        "carrying its own state from year to year) was run with no fixes, with each fix on "
        "its own, and with all fixes. The tables give the change from the original "
        "(fix minus original) in inches per year unless noted.",
        "",
        "**The fixture inputs are synthetic** (`tools/make_fixtures.py`): made-up weather "
        "and soils built to exercise every code path. The sizes below show how each fix "
        "behaves and which setups it touches; they are not estimates of what it does to the "
        "statewide model. Rerun this on real parcels before deciding which fixes to adopt.",
        "",
        "A run counts as changed if any annual output or the carried-over soil state moves "
        f"by more than {TOL:g}. Because state carries over, a fix that changes one year also "
        "changes later years.",
        "",
        "## Summary",
        "",
        "Mean change per year over the runs each fix changes.",
        "",
        "| Fix | Runs changed | Deep perc. | ET | Net irr. | Runoff |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
    ]
    for f in fixes:
        c = results[f]
        ch = c["changed"]
        cells = [fmt(mean([c["d"][k][r] for r in ch])) if ch else "0" for k in KEY]
        out.append(f"| [{f.name}](#{f.name.lower()}) | {len(ch)} | " + " | ".join(cells) + " |")
    ch = allcmp["changed"]
    out.append(f"| **All fixes** | {len(ch)} | "
               + " | ".join(fmt(mean([allcmp["d"][k][r] for r in ch])) for k in KEY) + " |")
    out.append("")

    # Water balance
    b0 = [abs(val(r, "balerr")) for r in base.values()]
    b1 = [abs(val(r, "balerr")) for r in allrun.values()]
    out += [
        "## Water balance",
        "",
        "The kernel checks every day that the change in soil water and snow equals water in "
        "(precipitation, run-on, infiltrated irrigation, wetland supply) minus water out "
        "(runoff, evaporation, transpiration, drainage). The residual is `balerr`.",
        "",
        "| | Runs with \\|error\\| > 0.01 in | Mean \\|error\\| | Largest \\|error\\| |",
        "| --- | ---: | ---: | ---: |",
        f"| No fixes (original) | {sum(x > 0.01 for x in b0)} of {total} | {mean(b0):.3f} | "
        f"{max(b0):.3f} |",
        f"| All fixes | {sum(x > 0.01 for x in b1)} of {total} | {mean(b1):.4f} | "
        f"{max(b1):.4f} |",
        "",
    ]
    berr = by_scenario({"d": {"balerr": {k: val(r, "balerr") for k, r in base.items()}}},
                       "balerr")
    worst = sorted(berr.items(), key=lambda kv: -abs(kv[1]))[:8]
    out += ["Scenarios with the largest error in the original (mean per year):", "",
            "| Scenario | Error (in/yr) |", "| --- | ---: |"]
    out += [f"| `{n}` | {fmt(x)} |" for n, x in worst]
    out += ["", "The fixes that close most of it are TRANSPIRATION_LIMIT (transpiration "
            "reported but never taken from the soil), WETLAND_BALANCE (wetland ET not "
            "taken from the soil) and DRAINAGE_SPREAD (held-back drainage spread over the "
            "wrong number of layers).", ""]

    # All fixes by scenario
    per = {k: by_scenario(allcmp, k) for k in KEY + ["wetsups"]}
    out += ["## All fixes, by scenario", "",
            "Mean change per year over 3 soils x 6 years.", "",
            "| Scenario | Deep perc. | ET | Net irr. | Runoff | Wetland supply |",
            "| --- | ---: | ---: | ---: | ---: | ---: |"]
    for n in sc.scenarios():
        out.append(f"| `{n}` | " + " | ".join(fmt(per[k][n]) for k in KEY + ["wetsups"])
                   + " |")
    out += ["", "For wetland, riparian and open-water covers, the net groundwater effect is "
            "deep percolation minus wetland supply: the fixed model takes the water these "
            "covers use beyond rain from the water table.", ""]

    out += [
        "## Reading the results",
        "",
        "* **Reporting-only fixes.** IRRIGATION_COUNT, INFILTRATION_OUTPUT and FALLOW_CROP "
        "change what is reported (irrigation count and first date, monthly infiltration, "
        "the crop label and yield of fallow), not the water moved.",
        "* **No change on these parcels.** FORAGE_CUTTING_STAGE matters only where a SIM "
        "file gives different values by cutting, and ET_ACCUMULATION only on days with "
        "almost no evaporative demand; the fixture inputs have neither. Each has a unit "
        "test that builds such a case (`tests/test_fixes.py`).",
        "* **Largest water-budget changes.** WETLAND_BALANCE (wetland, riparian and water "
        "covers now take their ET from the soil and the water table), ROTATION_FREQUENCY "
        "(the original delivered rotation water every day instead of every JDFREQ days) "
        "and RESIDUE_CN (the original cut the post-harvest curve number twice for residue, "
        "so it under-reports fall runoff). The RESIDUE_CN effect grows with residue "
        "amount and with rain after maturity, both of which are large in the fixture "
        "data; check it on real parcels.",
        "* **SNOWMELT_BASE** touches every run because snow melted at 0 F instead of 32 F, "
        "so the original melted snow on most winter days.",
        "",
        "## Each fix",
        "",
    ]
    for f in fixes:
        out += fix_section(f, results[f], base, None, total)

    OUT.write_text("\n".join(out).rstrip() + "\n")
    print(f"wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
