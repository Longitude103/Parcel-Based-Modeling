import sys, pathlib
REPO = pathlib.Path(__file__).resolve().parents[2]; sys.path.insert(0, str(REPO/'tests'))
src = (REPO/'fortran'/'original'/'CROPSIM_V8.0.F90').read_text()
src = src.replace("DATA DRIVE/'S:\\Cropsim\\Run004\\'/", "DATA DRIVE/'./'/")
src = src.replace("      END MODULE PARM", "      REAL ::      PCT\n      INTEGER ::   IEFC\n      REAL ::      GDDCUT\n      END MODULE PARM")
src = src.replace("        IRIGNO = 0\n", "        IRIGNO = 0\n        PCT = 0.0\n        IEFC = 1\n        GDDCUT = 0.0\n")
out = []
for l in src.split("\n"):
    if "'" in l and "\\" in l: l = l.replace("\\", "/")
    out.append(l)
pathlib.Path('ref.f90').write_text("\n".join(out))
