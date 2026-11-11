"""Generate fortran/src/cropsim_engine.f90 from the frozen original source.

The original CropSim v8.0 file (fortran/original/CROPSIM_V8.0.F90) is never
edited. The library engine is produced from it by the small, mechanical edits
listed in EDITS below, so every difference from the original is visible here.
None of the edits change the water-balance science. They only:

  * add library-mode variables to MODULE PARM,
  * drop the PROGRAM block (its per-year logic lives in cropsim_api.f90),
  * stop the subroutines writing text files when called from the library,
  * take weather from arrays instead of a .WEA file in library mode,
  * turn STOP statements into an error code in library mode, so a bad input
    raises a Python error instead of killing the Python process,
  * give three CROPCO variables that were read before being set (PCT, IEFC,
    GDDCUT) a defined value, so results no longer depend on the compiler,
  * add MODULE PARM_SNAPSHOT (generated from the PARM declarations), which
    saves every PARM variable once the parameters are set and restores them
    before each library run, so no value can carry over from an earlier run.

When LIBMODE is .FALSE. every edited line behaves exactly like the original.

Usage:
    python tools/make_engine.py            # write fortran/src/cropsim_engine.f90
    python tools/make_engine.py --check    # fail if the checked-in file is stale
"""

from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL = ROOT / "fortran" / "original" / "CROPSIM_V8.0.F90"
ENGINE = ROOT / "fortran" / "src" / "cropsim_engine.f90"

# SHA-256 of the frozen original. If this ever fails, the original was edited.
ORIGINAL_SHA256 = "eb15d9cc2228870aa52206113ae8df030a73902b2524aeca7c2f9909ccfdb0eb"

HEADER = """\
!=======================================================================
!  CropSim v8.0 engine for the cropsim Python package.
!
!  GENERATED FILE - DO NOT EDIT. Produced by tools/make_engine.py from the
!  frozen original fortran/original/CROPSIM_V8.0.F90. Lines changed from
!  the original are marked with  !LIB  comments.
!=======================================================================
"""

MODULE_ADDITIONS = """\
!LIB  ---- Library-mode state (added by tools/make_engine.py) ----
      LOGICAL ::   LIBMODE = .FALSE.   !LIB  .TRUE. when called through cropsim_api
      INTEGER ::   CS_STATUS = 0       !LIB  first error code raised in library mode
      INTEGER ::   WX_NDAYS            !LIB  number of daily weather values supplied
      REAL ::      WX_TMAX(366)        !LIB  daily weather supplied by the caller,
      REAL ::      WX_TMIN(366)        !LIB  starting on the weather start day
      REAL ::      WX_PRECIP(366)      !LIB
      REAL ::      WX_EPAN(366)        !LIB
      REAL ::      WX_ETR(366)         !LIB
!LIB  CROPCO used these as ordinary local variables but reads them before
!LIB  setting them on some days (PCT before alfalfa green-up, IEFC on days
!LIB  between cuttings, GDDCUT after the hay cutting), so their values
!LIB  depended on the compiler. Declaring them here makes CROPCO use these
!LIB  module variables instead: they keep their value from day to day within
!LIB  a run, and cs_run_year resets them to PCT=0, IEFC=1, GDDCUT=0 at the
!LIB  start of every run.
      REAL ::      PCT                 !LIB
      INTEGER ::   IEFC                !LIB
      REAL ::      GDDCUT              !LIB
"""


def stop_to_status(code: int, lines: list[str], label: str = "") -> list[str]:
    """Wrap an original 'write a message and STOP' block.

    In library mode the error code is recorded and the run carries on to the
    end of the year, so the API can return the code to Python. Outside
    library mode the original lines run unchanged.
    """
    lead = f"{label:<8}" if label else "        "
    out = [
        f"{lead}IF (LIBMODE) THEN                       !LIB",
        f"          IF (CS_STATUS.EQ.0) CS_STATUS = {code}       !LIB",
        "        ELSE                                    !LIB",
    ]
    for ln in lines:
        if label and ln.startswith(label):
            ln = " " * len(label) + ln[len(label):]
        out.append(ln)
    out.append("        END IF                                  !LIB")
    return out


DECL = re.compile(
    r"^\s*(REAL ::|INTEGER ::|CHARACTER\*\d+)\s+([A-Z0-9_]+)(\([0-9, ]+\))?\s*(!.*)?$")


def snapshot_module(decl_lines: list[str]) -> list[str]:
    """MODULE PARM_SNAPSHOT: a saved copy of every variable in MODULE PARM."""
    names, decls = [], []
    for ln in decl_lines:
        m = DECL.match(ln)
        if not m:
            continue
        kind, name, dims = m.group(1), m.group(2), m.group(3) or ""
        names.append(name)
        sep = " " if kind.startswith("CHARACTER") else " "
        decls.append(f"      {kind}{sep}S_{name}{dims}")
    if len(names) < 300:
        sys.exit(f"Only {len(names)} PARM variables found; declaration parsing broke.")
    out = [
        "",
        "!LIB  ---- Generated by tools/make_engine.py ----",
        "!LIB  Saved copy of every MODULE PARM variable. PARM_SAVE is called once",
        "!LIB  the block and tillage parameters are set; PARM_RESTORE before each",
        "!LIB  library run, so a run never sees values left by an earlier run.",
        "      MODULE PARM_SNAPSHOT",
        "      USE PARM",
        *decls,
        "      CONTAINS",
        "      SUBROUTINE PARM_SAVE",
        *[f"      S_{n} = {n}" for n in names],
        "      END SUBROUTINE PARM_SAVE",
        "      SUBROUTINE PARM_RESTORE",
        *[f"      {n} = S_{n}" for n in names],
        "      END SUBROUTINE PARM_RESTORE",
        "      END MODULE PARM_SNAPSHOT",
    ]
    return out


def build() -> str:
    raw = ORIGINAL.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    if digest != ORIGINAL_SHA256:
        sys.exit(f"Original source changed (sha256 {digest}); it must stay frozen.")
    src = raw.decode("ascii").split("\n")

    def line(n: int) -> str:  # 1-indexed
        return src[n - 1]

    def expect(n: int, text: str) -> None:
        if text not in line(n):
            sys.exit(f"Line {n} does not contain {text!r}: {line(n)!r}")

    # Anchor checks, so the edits below can never land on the wrong lines.
    expect(547, "END MODULE PARM")
    expect(555, "PROGRAM CROPSIMv7")
    expect(1442, "END PROGRAM CROPSIMv7")
    expect(1721, "' @ 1487:'")
    expect(1723, "STOP")
    expect(2027, "' @ 1729: '")
    expect(2029, "STOP")
    expect(2311, "245     WRITE(*,246)")
    expect(2314, "STOP")
    expect(2540, "' @ 2150:'")
    expect(2542, "STOP")
    expect(2724, "WRITE(10,451)")
    expect(2743, "WRITE(14,480)")
    expect(3562, "READ(1,40)(LOCATE(I), I=1,80)")
    expect(3565, "READ(1,45)IMSTR,IDSTR,NDAYS,LAT,LONG,ELEV")
    expect(3569, "READ(1,*)ETHEAD")
    expect(3588, "100     READ(1,*,END=200) IDATE,TMAX(I),TMIN(I),PRECIP(I),EPAN(I),ETR(I)")

    edits: dict[int, list[str]] = {}  # first line -> replacement; covers a span
    spans: dict[int, int] = {}

    def replace(first: int, last: int, new: list[str]) -> None:
        edits[first] = new
        spans[first] = last

    # 1. Library-mode variables at the end of MODULE PARM.
    replace(547, 547, MODULE_ADDITIONS.rstrip("\n").split("\n") + [line(547)])

    # 2. Drop the PROGRAM block. Its per-year logic is re-expressed in
    #    fortran/src/cropsim_api.f90 (CS_RUN_YEAR).
    replace(555, 1442, [
        "!LIB  PROGRAM CROPSIMv7 (original lines 555-1442) removed: the per-year",
        "!LIB  logic is in cropsim_api.f90, subroutine CS_RUN_YEAR.",
    ])

    # 3. STOP statements become error codes in library mode.
    replace(1721, 1723, stop_to_status(1, [line(1721), line(1722), line(1723)]))
    replace(2027, 2029, stop_to_status(2, [line(2027), line(2028), line(2029)]))
    replace(2311, 2314, stop_to_status(
        3, [line(2311), line(2312), line(2313), line(2314)], label="245"))
    replace(2540, 2542, stop_to_status(4, [line(2540), line(2541), line(2542)]))

    # 4. No monthly (unit 10) or weekly (unit 14) text output in library mode.
    #    The same numbers are returned through the API instead.
    replace(2724, 2724, [line(2724).replace(
        "WRITE(10,451)", "IF(.NOT.LIBMODE) WRITE(10,451)") + "  !LIB"])
    replace(2743, 2743, [line(2743).replace(
        "WRITE(14,480)", "IF(.NOT.LIBMODE) WRITE(14,480)") + "  !LIB"])

    # 5. Weather from arrays in library mode (READWEAT).
    for n in (3562, 3565, 3569):
        replace(n, n, [line(n).replace("READ(1", "IF(.NOT.LIBMODE) READ(1", 1) + "  !LIB"])
    replace(3588, 3588, [
        "100     IF (LIBMODE) THEN                       !LIB",
        "          IF ((I-JDYSTR+1.GT.WX_NDAYS).OR.(I.GT.366)) GOTO 200   !LIB",
        "          TMAX(I)   = WX_TMAX(I-JDYSTR+1)     !LIB",
        "          TMIN(I)   = WX_TMIN(I-JDYSTR+1)     !LIB",
        "          PRECIP(I) = WX_PRECIP(I-JDYSTR+1)   !LIB",
        "          EPAN(I)   = WX_EPAN(I-JDYSTR+1)     !LIB",
        "          ETR(I)    = WX_ETR(I-JDYSTR+1)      !LIB",
        "        ELSE                                    !LIB",
        "          READ(1,*,END=200) IDATE,TMAX(I),TMIN(I),PRECIP(I),EPAN(I),ETR(I)",
        "        END IF                                  !LIB",
    ])

    # 6. Snapshot module for the PARM variables (declared on lines 132-546).
    replace(547, 547, edits[547] + snapshot_module(src[131:546]))

    out: list[str] = HEADER.rstrip("\n").split("\n")
    n = 1
    while n <= len(src):
        if n in edits:
            out.extend(edits[n])
            n = spans[n] + 1
        else:
            out.append(src[n - 1])
            n += 1
    return "\n".join(out)


def main() -> None:
    text = build()
    if "--check" in sys.argv:
        if not ENGINE.exists() or ENGINE.read_text() != text:
            sys.exit("fortran/src/cropsim_engine.f90 is stale; run python tools/make_engine.py")
        print("engine is up to date")
        return
    ENGINE.write_text(text)
    print(f"wrote {ENGINE.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
