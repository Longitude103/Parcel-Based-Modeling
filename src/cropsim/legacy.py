"""Readers for the original CropSim text input files.

These let existing CropSim run folders (BLOCK.DAT, TILLAGE.DAT, NESOILS.DAT,
*.SIM, *.WEA, INITIAL.DAT) be used with the library. New work can build the
same objects directly from a database or any other source instead.

The readers follow Fortran list-directed input: each READ starts on a new
line, takes values across as many lines as it needs, and ignores the rest of
its last line.
"""

from __future__ import annotations

import re
from pathlib import Path

from .model import Block, Sim, Soil, State, Tillage, Weather

_SPLIT = re.compile(r"[,\s]+")

# Drainage values the original looked up by soil code (DCOFSOIL, DDAYSOIL).
SOIL_CODES = (411, 412, 421, 422, 431, 432, 442, 512, 521, 522, 532, 542, 612, 621,
              622, 631, 632, 642, 721, 722, 731, 732, 821, 822, 831, 832, 921, 922)
DRAIN_DAYS = (2.0, 2.0, 2.0, 2.0, 4.0, 4.0, 6.0, 2.0, 2.0, 2.0, 4.0, 6.0, 3.0, 3.0,
              3.0, 4.0, 4.0, 6.0, 3.0, 3.0, 4.0, 4.0, 4.0, 4.0, 6.0, 6.0, 4.0, 4.0)
DRAIN_COEFF = 0.50


class ListReader:
    """Fortran list-directed READ over a text file."""

    def __init__(self, text: str):
        self.lines = text.splitlines()
        self.pos = 0

    def skip(self, n: int = 1) -> None:
        self.pos += n

    def read(self, n: int) -> list[str]:
        values: list[str] = []
        while len(values) < n:
            if self.pos >= len(self.lines):
                raise EOFError("unexpected end of file")
            line = self.lines[self.pos]
            self.pos += 1
            for tok in _SPLIT.split(line.strip()):
                if not tok:
                    continue
                if tok.startswith("/"):
                    break
                if "*" in tok:
                    count, _, val = tok.partition("*")
                    values.extend([val] * int(count))
                else:
                    values.append(tok.strip("'\""))
        return values[:n]

    def floats(self, n: int) -> list[float]:
        return [float(v) for v in self.read(n)]

    def ints(self, n: int) -> list[int]:
        return [int(float(v)) for v in self.read(n)]

    def at_end(self) -> bool:
        return all(not ln.strip() for ln in self.lines[self.pos:])


def _fixed_float(field: str, decimals: int) -> float:
    """Fortran Fw.d input: a field without a decimal point has d implied decimals."""
    field = field.replace(" ", "")
    if not field:
        return 0.0
    if "." in field or "e" in field.lower():
        return float(field)
    return int(field) / 10 ** decimals


def _fixed_int(field: str) -> int:
    field = field.replace(" ", "")
    return int(field) if field else 0


def read_block(path: str | Path) -> Block:
    r = ListReader(Path(path).read_text())
    etrfact, nfday, ytrend = r.read(3)
    b = Block(etrfact=float(etrfact), nfday=int(float(nfday)), ytrend=int(float(ytrend)))
    b.depth = r.floats(10)
    b.ydens = r.floats(22)
    b.resrat = r.floats(22)
    b.spgrav = r.floats(22)
    b.fragil = r.ints(22)
    b.restyp = r.ints(22)
    cc = [[[0.0] * 10 for _ in range(3)] for _ in range(22)]
    for crop in range(7):
        cc[crop][0] = r.floats(10)
        cc[crop][1] = r.floats(10)
    for stage in range(3):
        cc[9][stage] = r.floats(10)  # alfalfa
    b.cc = cc
    b.kcl = r.floats(22)
    b.kcu = r.floats(22)
    b.tbase = r.floats(22)
    b.tceil = r.floats(22)
    b.snow = r.floats(7)
    b.cnfallow = r.floats(4)
    b.cn = [r.floats(4) for _ in range(22)]
    return b


def read_tillage(path: str | Path) -> list[Tillage]:
    """TILLAGE.DAT: two header lines, then FORMAT(I4,2(2X,F7.0),5X,A20)."""
    rows = []
    for line in Path(path).read_text().splitlines()[2:]:
        if not line.strip():
            continue
        line = line.ljust(45)
        rows.append(Tillage(
            code=_fixed_int(line[0:4]),
            factor1=_fixed_float(line[6:13], 0),
            factor2=_fixed_float(line[15:22], 0),
            name=line[27:47].strip(),
        ))
    return rows


def read_soils(path: str | Path) -> dict[int, Soil]:
    """NESOILS.DAT: one header line, then code, BULKD, ORGM, FIELDC(10), PWP(10), AIRDRY(2)."""
    r = ListReader(Path(path).read_text())
    r.skip()
    soils: dict[int, Soil] = {}
    while not r.at_end():
        v = r.floats(25)
        code = int(v[0])
        soils.setdefault(code, Soil(
            soil=code, bulkd=v[1], orgm=v[2], fieldc=v[3:13], pwp=v[13:23],
            airdry=v[23:25], drncoe=DRAIN_COEFF,
            drnday=DRAIN_DAYS[SOIL_CODES.index(code)] if code in SOIL_CODES else 2.0,
        ))
    return soils


def read_sim(path: str | Path, previous: Sim | None = None) -> Sim:
    """Read a .SIM file (original main program lines 828-910).

    The original only reads the values each crop type needs and keeps the
    rest from whatever SIM file it read before. Pass that earlier Sim as
    ``previous`` to reproduce the original exactly; otherwise unread values
    are left at zero.
    """
    s = Sim() if previous is None else previous.copy()
    r = ListReader(Path(path).read_text())
    s.crop, s.layers = r.ints(2)
    s.implt, s.idplt, s.imbg, s.idbg, s.imend, s.idend = r.ints(6)
    if s.crop < 10:
        s.gddveg, s.gddflo, s.gddripe, s.gyform, s.gddefc, s.gddmat = r.floats(6)
    if s.crop in (10, 11):
        v = r.ints(6)
        s.ncut, s.jdycut = v[0], v[1:6]
    if s.crop >= 12:
        s.gddefc, s.gddmat = r.floats(2)
    s.rzmin, s.rzmax, s.tbreak, s.gddroot, s.rzmgmt = r.floats(5)
    v = r.read(3)
    s.iyield, s.ymax, s.ycoeff = int(float(v[0])), float(v[1]), float(v[2])
    v = r.read(4)
    s.iterrc, s.chand, s.chanw, s.tintrv = int(float(v[0])), float(v[1]), float(v[2]), float(v[3])
    s.ntills, s.itflag = r.ints(2)
    s.tillage_ops = [tuple(r.ints(3)) for _ in range(s.ntills)]
    v = r.read(6)
    s.irrtyp, s.pad = int(float(v[0])), [float(x) for x in v[1:6]]
    v = r.floats(6)
    s.rainal, s.syscap = v[0:5], v[5]
    s.iper = r.floats(5)
    s.apmin = r.floats(5)
    s.apmax = r.floats(5)
    s.smalli = r.floats(5)
    v = r.read(4)
    s.gstart, s.gstop, s.irrsch, s.jfirst = float(v[0]), float(v[1]), int(float(v[2])), int(float(v[3]))
    if s.irrsch == 3:
        if 10 <= s.crop <= 13:
            v = r.read(2)
            s.jdfreq, s.ddepth = int(float(v[0])), float(v[1])
        else:
            v = r.read(4)
            s.jstopi, s.jgoi, s.jdfreq = (int(float(x)) for x in v[:3])
            s.ddepth = float(v[3])
    s.eapp = r.floats(5)
    s.ereuse = r.floats(5)
    s.prunof = r.floats(5)
    if s.irrtyp == 2:
        s.fdfile = r.read(1)[0]
        s.alpha1, a1, a2 = r.floats(3)
        s.sim_airdry = [a1, a2]
        s.sim_fieldc = r.floats(10)
        s.sim_pwp = r.floats(10)
        s.sim_bulkd = r.floats(1)[0]
    return s


def read_irrigation_events(path: str | Path) -> list[tuple[int, float, float]]:
    """Read an FDFILE of known irrigations: KIRR, then day, gross depth, fraction."""
    r = ListReader(Path(path).read_text())
    n = r.ints(1)[0]
    return [(int(float(d)), float(g), float(f)) for d, g, f in (r.read(3) for _ in range(n))]


def read_weather(path: str | Path, year: int | None = None) -> Weather:
    """Read a .WEA file (original subroutine READWEAT)."""
    lines = Path(path).read_text().splitlines()
    head = lines[1].ljust(62)
    imstr = _fixed_int(head[0:3])
    idstr = _fixed_int(head[3:6])
    # FORMAT(2I3,I6,7X,F7.2,8X,F8.2,12X,F8.0)
    lat = _fixed_float(head[19:26], 2)
    lon = _fixed_float(head[34:42], 2)
    elev = _fixed_float(head[54:62], 0)
    r = ListReader("\n".join(lines[3:]))
    tmax, tmin, precip, epan, etr = [], [], [], [], []
    while not r.at_end():
        v = r.read(6)
        tmax.append(float(v[1]))
        tmin.append(float(v[2]))
        precip.append(float(v[3]))
        epan.append(float(v[4]))
        etr.append(float(v[5]))
    if year is None:
        m = re.search(r"(\d{4})\.WEA$", str(path), re.IGNORECASE)
        year = int(m.group(1)) if m else 0
    return Weather(year=year, start_month=imstr, start_day=idstr, lat=lat, long=lon,
                   elev=elev, tmax=tmax, tmin=tmin, precip=precip, epan=epan, etr=etr,
                   header=lines[0][:80])


def read_initial(path: str | Path) -> State:
    """Read INITIAL.DAT (carryover state)."""
    r = ListReader(Path(path).read_text())
    theta = r.floats(10)
    v = r.read(3)
    v2 = r.floats(12)
    return State(theta=theta, oldcrp=int(float(v[0])), oldres=float(v[1]),
                 livecrop=int(float(v[2])), snotmp=v2[0], snoh2o=v2[1], soilt=v2[2:12])


def write_initial(state: State, path: str | Path) -> None:
    """Write INITIAL.DAT in the original formats 476-478."""
    t = "".join(f"  {x:6.3f}" for x in state.theta)
    c = f"  {state.oldcrp:4d}  {state.oldres:9.1f}  {state.livecrop:4d}"
    s = f"  {state.snotmp:8.1f}    {state.snoh2o:6.2f}    " + "".join(f"  {x:5.1f}" for x in state.soilt)
    Path(path).write_text("\n".join([t, c, s]) + "\n")
