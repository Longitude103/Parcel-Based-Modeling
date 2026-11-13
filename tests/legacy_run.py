"""Run the original CropSim program and the library on the same inputs.

Used by test_parity.py. The original program has its input paths hard-coded
for a Windows drive (S:\\Cropsim\\Run004\\). For the test, a temporary copy of
the frozen source is made with only those path strings changed, then built
with gfortran and run inside a folder laid out the way it expects.
"""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

from cropsim import CROP_NAMES, Engine, Kernel
from cropsim import legacy

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL = ROOT / "fortran" / "original" / "CROPSIM_V8.0.F90"
FIX = ROOT / "tests" / "fixtures"
SITE = "TEST"
SOIL_ORDER = legacy.SOIL_CODES
FFLAGS = ["-O2", "-ffree-line-length-none", "-std=legacy", "-ffp-contract=off"]


# CROPCO reads PCT, IEFC and GDDCUT before setting them on some days, so the
# original's results there depend on the compiler. The library gives them a
# defined value (see tools/make_engine.py). The reference build gets the same
# definition: module variables, reset at the start of each run.
CROPCO_DECLS = (
    "      REAL ::      PCT\n"
    "      INTEGER ::   IEFC\n"
    "      REAL ::      GDDCUT\n"
    "      END MODULE PARM"
)
CROPCO_RESET = "        IRIGNO = 0\n        PCT = 0.0\n        IEFC = 1\n        GDDCUT = 0.0"


def build_original(work: Path, fc: str = "gfortran") -> Path:
    """Compile the original program with its file paths pointed at the run folder.

    Besides the paths, the only change is the CROPCO definition described
    above CROPCO_DECLS.
    """
    src = ORIGINAL.read_text()
    src = src.replace("DATA DRIVE/'S:\\Cropsim\\Run004\\'/", "DATA DRIVE/'./'/")
    assert src.count("      END MODULE PARM") == 1
    src = src.replace("      END MODULE PARM", CROPCO_DECLS)
    assert src.count("        IRIGNO = 0\n") == 1
    src = src.replace("        IRIGNO = 0\n", CROPCO_RESET + "\n")
    patched = []
    for line in src.split("\n"):
        if "'" in line and "\\" in line:
            line = line.replace("\\", "/")
        patched.append(line)
    path = work / "cropsim_original_paths.f90"
    path.write_text("\n".join(patched))
    exe = work / "cropsim_original"
    subprocess.run([fc, *FFLAGS, "-o", str(exe), str(path)], check=True, cwd=work,
                   capture_output=True)
    return exe


def make_run_dir(run: Path) -> None:
    """Lay out the fixtures the way the original program's paths expect.

    The original mixes CSMODEL/CSModel and RESULTS/Results. On macOS and
    Windows those are the same folder, so every mkdir tolerates existing.
    """
    cs = run / "CSMODEL"
    (cs / "WEA").mkdir(parents=True, exist_ok=True)
    (cs / "SOIL").mkdir(exist_ok=True)
    zone = run / "CSModel" / "SIM" / "98" / "ZONE1"
    zone.mkdir(parents=True, exist_ok=True)
    out = run / "Results" / "Update2013" / "98"
    for sub in ("Mon", "YR", "Precip"):
        (out / sub).mkdir(parents=True, exist_ok=True)
    (run / "RESULTS").mkdir(exist_ok=True)
    shutil.copy(FIX / "BLOCK.DAT", cs / "BLOCK.DAT")
    shutil.copy(FIX / "TILLAGE.DAT", cs / "TILLAGE.DAT")
    shutil.copy(FIX / "INITIAL.DAT", cs / "INITIAL.DAT")
    shutil.copy(FIX / "NESOILS.DAT", cs / "SOIL" / "NESOILS.DAT")
    shutil.copy(FIX / "soilsites.csv", cs / "SOIL" / "NE_allsoil.CSV")
    (cs / "PRFILE").write_text("3 1 0 2010 2014 0\n")
    (cs / "WsiteInfo_ALL2013.txt").write_text(f"{SITE} 1 1 2010\n")
    for f in (FIX / "wea").iterdir():
        shutil.copy(f, cs / "WEA" / f.name)
    for f in (FIX / "sim").iterdir():
        shutil.copy(f, zone / f.name)
    shutil.copy(FIX / "cropping.csv", zone / "Cropping2013.csv")


def run_original(exe: Path, run: Path) -> dict[str, str]:
    subprocess.run([str(exe)], check=True, cwd=run, capture_output=True, timeout=300)
    out = run / "Results" / "Update2013" / "98"
    return {
        "yr": (out / "YR" / f"{SITE}_YR.TXT").read_text(),
        "mon": (out / "Mon" / f"{SITE}_MON.TXT").read_text(),
        "weekly": (out / "Precip" / f"{SITE}_PRECIP.CSV").read_text(),
        "initial": (run / "CSMODEL" / "INITIAL.DAT").read_text(),
    }


# ---- Fortran edit descriptors, for writing library results the same way ----

def F(x: float, w: int, d: int) -> str:
    s = f"{x:.{d}f}"
    if s.startswith("0.") and len(s) > w:
        s = s[1:]
    elif s.startswith("-0.") and len(s) > w:
        s = "-" + s[2:]
    return s.rjust(w) if len(s) <= w else "*" * w


def I(n: int, w: int) -> str:
    s = str(n)
    return s.rjust(w) if len(s) <= w else "*" * w


def run_library(use_kernel: bool = False) -> dict[str, str]:
    """Repeat the original program's loops with the library.

    use_kernel runs them through the compute kernel (no fixes) instead of
    the reference engine.
    """
    block = legacy.read_block(FIX / "BLOCK.DAT")
    tillage = legacy.read_tillage(FIX / "TILLAGE.DAT")
    engine = Kernel(block, tillage) if use_kernel else Engine(block, tillage)
    soils = legacy.read_soils(FIX / "NESOILS.DAT")
    rows = [(s, int(y)) for s, y in (ln.split(",") for ln in
                                     (FIX / "cropping.csv").read_text().split())]
    flags = (FIX / "soilsites.csv").read_text().splitlines()[1].split(",")[2:]
    year1 = 2010

    # The original kept one INITIAL.DAT for everything, so state flows from
    # each run to the next, across SIM files and soils. Repeat that here.
    state = legacy.read_initial(FIX / "INITIAL.DAT")
    previous_sim = None
    yr, mon, weekly = [], [], []
    weather_cache = {}
    for isoil, code in enumerate(SOIL_ORDER):
        if int(flags[isoil]) < 1:
            continue
        soil = soils[code]
        last_sim, last_yr = None, None
        for ii, (simname, year) in enumerate(rows):
            if year < year1:
                continue
            livecond = ii > 0 and simname == last_sim and year < last_yr
            last_sim, last_yr = simname, year
            sim = legacy.read_sim(FIX / "sim" / f"{simname}.SIM", previous=previous_sim)
            previous_sim = sim
            if year not in weather_cache:
                weather_cache[year] = legacy.read_weather(FIX / "wea" / f"{SITE}{year}.WEA")
            r = engine.run_year(sim, soil, weather_cache[year], state, livecond=livecond,
                                legacy_rounding=True)
            state = r.state
            a, m, w = r.annual, r.monthly, r.weekly

            if year > 1938:
                line = (" " + SITE + "  " + I(year, 5) + I(code, 5) + I(r.crop_mon, 3)
                        + I(a["itflag"], 3) + I(sim.irrtyp, 3))
                for k in range(a["imbg"] - 1, a["imend"]):
                    line += "  " + "".join(F(m[n][k], 7, 2) for n in
                                           ("etmon", "ermon", "irnmon", "dramon", "rofmon",
                                            "ramon"))
                mon.append(line)
            for k in range(52):
                weekly.append(f"{SITE},{I(year, 5)},{I(k + 1, 3)},{I(code, 4)},{I(sim.crop, 3)},"
                              f"{I(a['itflag'], 2)},{I(sim.irrtyp, 2)},{I(sim.iterrc, 2)},"
                              + "".join(F(w[n][k], 7, 2) + "," for n in
                                        ("etrwk", "etwk", "erwk", "rawk", "irnwk", "irgwk")))
            if year != 1949:
                yr.append(
                    " " + SITE + "  " + simname.ljust(8) + " "
                    + "".join(I(v, 5) for v in (code, year, a["jdyplt"], a["jfirst"],
                                                a["jfirst"], a["jdyefc"], a["jdymat"],
                                                a["jdyfrz"]))
                    + F(a["yield"], 8, 1) + "  "
                    + "".join(F(a[n], 7, 2) for n in ("ets", "sgrirr", "snirr"))
                    + I(a["irigno"], 5) + "  "
                    + "".join(F(a[n], 6, 2) for n in ("precips", "eprecips", "drains", "dplbg"))
                    + "  " + "  " + CROP_NAMES[r.crop_yr - 1].ljust(8)
                    + I(r.crop_yr, 3) + I(a["itflag"], 3) + I(sim.irrtyp, 3)
                    + F(a["totrof"], 7, 2))

    initial_path = Path(__file__).parent / "_initial_tmp.dat"
    legacy.write_initial(state, initial_path)
    initial = initial_path.read_text()
    initial_path.unlink()
    return {"yr": "\n".join(yr) + "\n", "mon": "\n".join(mon) + "\n",
            "weekly": "\n".join(weekly) + "\n", "initial": initial}
