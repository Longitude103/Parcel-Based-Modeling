"""Write the small synthetic CropSim input set used by the parity tests.

The values are plausible for Nebraska but made up, and the weather is
generated, so the fixtures carry no State data. They exist only to check that
the library gives the same answers as the original program.

    python tools/make_fixtures.py   # writes tests/fixtures/
"""

from __future__ import annotations

import math
import random
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "tests" / "fixtures"
SITE = "TEST"
YEARS = range(2009, 2015)
SOILS = (421, 622, 832)

# 22 crops: SM.GRAIN ... FARMSTED
YDENS = [60, 60, 60, 60, 60, 56, 60, 56, 30, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
RESRAT = [1.5, 1.0, 1.5, 0.5, 0.5, 1.0, 1.7, 1.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
          0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
SPGRAV = [1.3, 1.3, 1.3, 1.3, 1.3, 1.3, 1.3, 1.3, 1.3, 1.3, 1.3, 1.3, 1.3, 1.3, 1.3,
          1.3, 1.3, 1.3, 1.3, 1.3, 1.3, 1.3]
FRAGIL = [1, 2, 2, 2, 2, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
RESTYP = [1, 2, 2, 2, 2, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
KCL = [0.20, 0.20, 0.20, 0.20, 0.20, 0.20, 0.20, 0.20, 0.20, 0.25, 0.25, 0.25, 0.20,
       0.50, 0.15, 0.30, 0.30, 0.30, 0.30, 1.05, 1.05, 0.15]
KCU = [1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 0.95, 0.90, 0.80,
       0.85, 0.20, 1.00, 0.90, 1.10, 1.10, 1.10, 1.10, 0.30]
TBASE = [32, 50, 50, 45, 40, 50, 32, 50, 44, 41, 41, 41, 41, 41, 41, 41, 41, 41, 41,
         41, 41, 41]
TCEIL = [86, 86, 86, 86, 86, 86, 86, 86, 86, 86, 86, 86, 86, 86, 86, 86, 86, 86, 86,
         86, 86, 86]


def kc_curve(lo: float, hi: float) -> list[float]:
    return [round(lo + (hi - lo) * (i + 1) / 10, 3) for i in range(10)]


def block() -> str:
    lines = ["0.95 5 0", " ".join(["4", "8", "12", "12", "12", "12", "12", "12", "12", "12"])]
    for arr in (YDENS, RESRAT, SPGRAV, FRAGIL, RESTYP):
        lines.append(" ".join(str(v) for v in arr))
    for crop in range(7):
        lines.append(" ".join(f"{v:.3f}" for v in kc_curve(0.2, 1.0)))
        lines.append(" ".join(f"{v:.3f}" for v in kc_curve(1.0, 0.4)))
    for _ in range(3):  # alfalfa
        lines.append(" ".join(f"{v:.3f}" for v in kc_curve(0.3, 1.0)))
    for arr in (KCL, KCU, TBASE, TCEIL):
        lines.append(" ".join(str(v) for v in arr))
    lines.append("32.0 0.18 0.05 1.0 0.5 0.95 0.5")
    lines.append("77 86 91 94")
    for crop in range(22):
        lines.append("67 78 85 89" if crop not in (12, 15, 16) else "39 61 74 80")
    return "\n".join(lines) + "\n"


def tillage() -> str:
    rows = ["CODE   FACTOR1  FACTOR2     NAME", "-" * 40]
    for code, f1, f2, name in [(1, 100, 100, "NONE"), (2, 90, 75, "DISK"),
                               (3, 70, 50, "CHISEL"), (4, 10, 5, "MOLDBOARD"),
                               (5, 85, 70, "FIELD CULT"), (6, 95, 90, "PLANTER")]:
        rows.append(f"{code:4d}  {f1:7.0f}  {f2:7.0f}     {name:<20}")
    return "\n".join(rows) + "\n"


def soils() -> str:
    rows = ["CODE BULKD ORGM FC(1-10) PWP(1-10) AIRDRY(1-2)"]
    for code in SOILS:
        awc = (code // 100) / 4 / 12  # quarter inches per foot -> volumetric
        fc = [round(0.18 + awc + 0.01 * (k % 3), 3) for k in range(10)]
        pwp = [round(f - awc, 3) for f in fc]
        rows.append(f"{code} 1.40 1.8 " + " ".join(map(str, fc)) + " "
                    + " ".join(map(str, pwp)) + " 0.04 0.07")
    return "\n".join(rows) + "\n"


def sim(crop: int, irrigated: bool, *, alfalfa: bool = False, native: bool = False,
        itflag: int = 1, irrsch: int = 1) -> str:
    L = [f"{crop} 10"]
    if crop == 7:
        L.append("9 20 1 1 12 31")
    elif alfalfa or native:
        L.append("4 1 1 1 12 31")
    else:
        L.append("5 5 1 1 12 31")
    if crop < 10:
        L.append("750 1400 2000 1300 1250 2600" if crop != 7 else "300 1100 1500 1000 900 1900")
    elif crop in (10, 11):
        L.append("4 150 185 220 260 0")
    else:
        L.append("900 2600")
    L.append("4.0 48.0 0.50 100.0 36.0")
    L.append("2 200.0 1.0" if crop < 12 else "1 4.0 1.0")
    L.append("0 0.0 0.0 0.0")
    if crop == 7:
        L.append("2 2")
        L.append("1 10 3")
        L.append("3 20 5")
    elif native:
        L.append("0 1")
    else:
        L.append(f"2 {itflag}")
        L.append("1 14 2")
        L.append("2 0 6")
    if irrigated:
        L.append("3 0.5 0.5 0.5 0.5 0.5")
        L.append("0.25 0.25 0.25 0.25 0.25 0.33")
        L.append("1.0 1.0 1.0 1.0 1.0")
        L.append("0.75 0.75 0.75 0.75 0.75")
        L.append("1.25 1.25 1.25 1.25 1.25")
        L.append("0.50 0.50 0.50 0.50 0.50")
        L.append(f"500.0 2500.0 {irrsch} 0")
        if irrsch == 3:
            L.append("150 220 10 1.25" if not alfalfa else "10 1.25")
        L.append("0.85 0.85 0.85 0.85 0.85")
        L.append("0.0 0.0 0.0 0.0 0.0")
        L.append("0.0 0.0 0.0 0.0 0.0")
    else:
        L.append("1 0.5 0.5 0.5 0.5 0.5")
        L.append("0.0 0.0 0.0 0.0 0.0 0.0")
        L.append("1.0 1.0 1.0 1.0 1.0")
        L.append("0.0 0.0 0.0 0.0 0.0")
        L.append("0.0 0.0 0.0 0.0 0.0")
        L.append("0.0 0.0 0.0 0.0 0.0")
        L.append("0.0 0.0 1 0")
        L.append("1.0 1.0 1.0 1.0 1.0")
        L.append("0.0 0.0 0.0 0.0 0.0")
        L.append("0.0 0.0 0.0 0.0 0.0")
    return "\n".join(L) + "\n"


SIMS = {
    "CRNIRR01": sim(8, True),
    "CRNDRY01": sim(8, False),
    "SOYDRY01": sim(3, False, itflag=2),
    "SOYIRR03": sim(3, True, irrsch=3),
    "WWTDRY01": sim(7, False),
    "ALFIRR01": sim(10, True, alfalfa=True),
    "NRANGE01": sim(13, False, native=True),
    "SORDRY01": sim(6, False),
}

# (SIM file, year) rows in run order, like a Cropping*.csv file.
CROPPING = (
    [("CRNIRR01", y) for y in YEARS]
    + [("WWTDRY01", y) for y in YEARS]
    + [("SOYDRY01", 2012), ("CRNDRY01", 2013), ("ALFIRR01", 2011), ("ALFIRR01", 2012),
       ("NRANGE01", 2010), ("SOYIRR03", 2012), ("SORDRY01", 2014), ("CRNIRR01", 2012)]
)


def weather(year: int) -> str:
    rnd = random.Random(year)
    ndays = 366 if year % 4 == 0 else 365
    rows = [f"{'TEST STATION, SYNTHETIC WEATHER':<80}",
            f"{1:3d}{1:3d}{ndays:6d}{'':7}{41.25:7.2f}{'':8}{-98.75:8.2f}{'':12}{2100:8.0f}",
            "DATE      TMAX   TMIN  PRECIP   EPAN    ETR"]
    for d in range(1, ndays + 1):
        season = math.sin(2 * math.pi * (d - 110) / 365)
        tmax = 62 + 30 * season + rnd.gauss(0, 7)
        tmin = tmax - 22 + rnd.gauss(0, 4)
        wet = rnd.random() < (0.18 + 0.12 * max(season, 0))
        precip = min(round(rnd.expovariate(1 / 0.35), 2), 3.5) if wet else 0.0
        etr = max(0.02, 0.17 + 0.15 * season + rnd.gauss(0, 0.03) - (0.08 if wet else 0))
        rows.append(f"{year}{d:03d} {tmax:6.1f} {tmin:6.1f} {precip:6.2f} {0.0:6.2f} {etr:6.3f}")
    return "\n".join(rows) + "\n"


INITIAL = (
    "   0.300   0.300   0.300   0.300   0.300   0.300   0.300   0.300   0.300   0.300\n"
    "     8      1500.0     0\n"
    "      32.0      0.00      30.0   32.0   35.0   40.0   45.0   48.0   50.0   50.0   50.0   50.0\n"
)


def main() -> None:
    (OUT / "sim").mkdir(parents=True, exist_ok=True)
    (OUT / "wea").mkdir(parents=True, exist_ok=True)
    (OUT / "BLOCK.DAT").write_text(block())
    (OUT / "TILLAGE.DAT").write_text(tillage())
    (OUT / "NESOILS.DAT").write_text(soils())
    (OUT / "INITIAL.DAT").write_text(INITIAL)
    for name, text in SIMS.items():
        (OUT / "sim" / f"{name}.SIM").write_text(text)
    for y in YEARS:
        (OUT / "wea" / f"{SITE}{y}.WEA").write_text(weather(y))
    (OUT / "cropping.csv").write_text("".join(f"{s},{y}\n" for s, y in CROPPING))
    flags = ",".join("1" if c in SOILS else "0" for c in
                     (411, 412, 421, 422, 431, 432, 442, 512, 521, 522, 532, 542, 612, 621,
                      622, 631, 632, 642, 721, 722, 731, 732, 821, 822, 831, 832, 921, 922))
    (OUT / "soilsites.csv").write_text(f"NWS,MUID,SOILS\n{SITE},1,{flags}\n")
    print(f"wrote fixtures to {OUT}")


if __name__ == "__main__":
    main()
