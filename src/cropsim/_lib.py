"""ctypes binding to the CropSim Fortran library.

The structures here mirror the BIND(C) types in fortran/src/cropsim_api.f90
field for field. Keep the two in step: lib() checks the sizes against cs_struct_size.
"""

from __future__ import annotations

import ctypes
import os
import sys
from ctypes import POINTER, c_float, c_int
from pathlib import Path

API_VERSION = 1


def _f(n: int) -> type:
    return c_float * n


def _i(n: int) -> type:
    return c_int * n


class SimT(ctypes.Structure):
    _fields_ = [
        ("CROP", c_int), ("LAYERS", c_int),
        ("IMPLT", c_int), ("IDPLT", c_int), ("IMBG", c_int), ("IDBG", c_int),
        ("IMEND", c_int), ("IDEND", c_int),
        ("GDDVEG", c_float), ("GDDFLO", c_float), ("GDDRIPE", c_float),
        ("GYFORM", c_float), ("GDDEFC", c_float), ("GDDMAT", c_float),
        ("NCUT", c_int), ("JDYCUT", _i(5)),
        ("RZMIN", c_float), ("RZMAX", c_float), ("TBREAK", c_float),
        ("GDDROOT", c_float), ("RZMGMT", c_float),
        ("IYIELD", c_int), ("YMAX", c_float), ("YCOEFF", c_float),
        ("ITERRC", c_int), ("CHAND", c_float), ("CHANW", c_float), ("TINTRV", c_float),
        ("NTILLS", c_int), ("ITFLAG", c_int),
        ("ITILTM", _i(20)), ("TILDAY", _i(20)), ("TILCOD", _i(20)),
        ("IRRTYP", c_int),
        ("PAD", _f(5)), ("RAINAL", _f(5)), ("SYSCAP", c_float), ("IPER", _f(5)),
        ("APMIN", _f(5)), ("APMAX", _f(5)), ("SMALLI", _f(5)),
        ("GSTART", c_float), ("GSTOP", c_float),
        ("IRRSCH", c_int), ("JFIRST", c_int), ("JSTOPI", c_int), ("JGOI", c_int),
        ("JDFREQ", c_int), ("DDEPTH", c_float),
        ("EAPP", _f(5)), ("EREUSE", _f(5)), ("PRUNOF", _f(5)),
        ("ALPHA1", c_float), ("AIRDRY", _f(2)), ("FIELDC", _f(10)), ("PWP", _f(10)),
        ("BULKD", c_float), ("KIRR", c_int),
        ("FDIRRIG", _f(3) * 50),  # Fortran FDIRRIG(3,50): [event][doy, gross, frac]
    ]


class SoilT(ctypes.Structure):
    _fields_ = [
        ("SOIL", c_int), ("BULKD", c_float), ("ORGM", c_float),
        ("FIELDC", _f(10)), ("PWP", _f(10)), ("AIRDRY", _f(2)),
        ("DRNCOE", c_float), ("DRNDAY", c_float),
    ]


class WeatherT(ctypes.Structure):
    _fields_ = [
        ("YEAR", c_int), ("IMSTR", c_int), ("IDSTR", c_int), ("NDAYS", c_int),
        ("LAT", c_float), ("LONG", c_float), ("ELEV", c_float),
        ("TMAX", _f(366)), ("TMIN", _f(366)), ("PRECIP", _f(366)),
        ("EPAN", _f(366)), ("ETR", _f(366)),
    ]


class StateT(ctypes.Structure):
    _fields_ = [
        ("THETA", _f(10)), ("OLDCRP", c_int), ("LIVECROP", c_int),
        ("OLDRES", c_float), ("SNOTMP", c_float), ("SNOH2O", c_float),
        ("SOILT", _f(10)),
    ]


MONTHLY = ("ETRMON", "EMON", "TMON", "ETMON", "ERMON", "RAMON", "ROFMON", "RONMON",
           "IRNMON", "IRGMON", "INFMON", "DRAMON", "DPLMON")
WEEKLY = ("ETRWK", "ETWK", "ERWK", "RAWK", "IRNWK", "IRGWK")


class ResultT(ctypes.Structure):
    _fields_ = (
        [("STATUS", c_int), ("CROP_YR", c_int), ("CROP_MON", c_int),
         ("IMBG", c_int), ("IMEND", c_int),
         ("JDYPLT", c_int), ("JFIRST", c_int), ("JDYEFC", c_int), ("JDYMAT", c_int),
         ("JDYFRZ", c_int), ("IRIGNO", c_int), ("ITFLAG", c_int)]
        + [(n, c_float) for n in ("YIELD", "YLDRATIO", "BVALUE", "ETMAX", "ETYLD",
                                  "ETS", "ETRS", "ES", "TS", "SGRIRR", "SNIRR",
                                  "PRECIPS", "EPRECIPS", "DRAINS", "DPLBG", "TOTROF")]
        + [(n, _f(12)) for n in MONTHLY]
        + [("NUMIRR", _i(12))]
        + [(n, _f(53)) for n in WEEKLY]
    )


def _library_names() -> list[str]:
    if sys.platform == "win32":
        return ["cropsim.dll", "libcropsim.dll"]
    if sys.platform == "darwin":
        return ["libcropsim.dylib", "libcropsim.so"]
    return ["libcropsim.so"]


def find_library() -> Path:
    """Locate the compiled library.

    CROPSIM_LIBRARY overrides the search (useful while developing).
    Otherwise the library installed inside this package is used.
    """
    override = os.environ.get("CROPSIM_LIBRARY")
    if override:
        return Path(override)
    here = Path(__file__).resolve().parent
    for name in _library_names():
        candidate = here / name
        if candidate.exists():
            return candidate
    raise OSError(
        "The CropSim Fortran library was not found next to the cropsim package. "
        "Install a built wheel, or set CROPSIM_LIBRARY to the path of a compiled "
        "libcropsim."
    )


_LIB = None


def lib() -> ctypes.CDLL:
    """Load the library once and declare the function signatures."""
    global _LIB
    if _LIB is not None:
        return _LIB
    path = find_library()
    if sys.platform == "win32":
        os.add_dll_directory(str(path.parent))
    handle = ctypes.CDLL(str(path))

    handle.cs_version.restype = c_int
    handle.cs_version.argtypes = []

    fp, ip = POINTER(c_float), POINTER(c_int)
    handle.cs_set_block.restype = c_int
    handle.cs_set_block.argtypes = [
        c_float, c_int, c_int, fp,  # ETRFACT, NFDAY, YTREND, DEPTH
        fp, fp, fp, ip, ip,          # YDENS, RESRAT, SPGRAV, FRAGIL, RESTYP
        fp,                          # CC(22,3,10)
        fp, fp, fp, fp,              # KCL, KCU, TBASE, TCEIL
        fp, fp, fp,                  # SNOW(7), CNFALLOW(4), CN(22,4)
    ]

    handle.cs_set_tillage.restype = c_int
    handle.cs_set_tillage.argtypes = [c_int, ip, fp, fp]

    handle.cs_run_year.restype = c_int
    handle.cs_run_year.argtypes = [
        POINTER(SimT), POINTER(SoilT), POINTER(WeatherT), POINTER(StateT),
        c_int, c_int, POINTER(StateT), POINTER(ResultT),
    ]

    handle.cs_struct_size.restype = c_int
    handle.cs_struct_size.argtypes = [c_int]
    for which, struct in enumerate((SimT, SoilT, WeatherT, StateT, ResultT), start=1):
        if handle.cs_struct_size(which) != ctypes.sizeof(struct):
            raise OSError(f"{struct.__name__} layout does not match libcropsim "
                          f"({ctypes.sizeof(struct)} vs {handle.cs_struct_size(which)} bytes)")

    version = handle.cs_version()
    if version != API_VERSION:
        raise OSError(
            f"libcropsim at {path} has API version {version}, expected {API_VERSION}."
        )
    _LIB = handle
    return handle


# ---- Kernel (fortran/kernel, csk_* functions) ----
# The SIM, soil, weather and state structures have the same layout as the
# reference engine's, so SimT, SoilT, WeatherT and StateT serve both.

KERNEL_API_VERSION = 2


class ParamsT(ctypes.Structure):
    _fields_ = [
        ("etrfact", c_float), ("nfday", c_int), ("ytrend", c_int),
        ("depth", _f(10)),
        ("ydens", _f(22)), ("resrat", _f(22)), ("spgrav", _f(22)),
        ("fragil", _i(22)), ("restyp", _i(22)),
        ("cc", c_float * 660),                       # Fortran cc(22,3,10)
        ("kcl", _f(22)), ("kcu", _f(22)), ("tbase", _f(22)), ("tceil", _f(22)),
        ("sftmp", c_float), ("smfmx", c_float), ("smfmn", c_float),
        ("snocovmx", c_float), ("snocov1", c_float), ("snocov2", c_float),
        ("timp", c_float),
        ("cnfallow", _f(4)), ("cn", c_float * 88),   # Fortran cn(22,4)
        ("tilfac", c_float * 160),                   # Fortran tilfac(80,2)
        ("smtmp", c_float),
    ]


class OptionsT(ctypes.Structure):
    _fields_ = [("revert", c_int), ("livecond", c_int), ("legacy_round", c_int),
                ("reserved", c_int)]


KDAILY = ("d_gdd", "d_kc", "d_rzd", "d_etr", "d_precip", "d_eprecip", "d_runoff",
          "d_runon", "d_grirr", "d_nirr", "d_irrinf", "d_e", "d_t", "d_et", "d_drain",
          "d_wetsup", "d_snow", "d_soilw", "d_dpln", "d_awdpln", "d_balerr")


class KResultT(ctypes.Structure):
    _fields_ = (
        list(ResultT._fields_)
        + [("JDYBG", c_int), ("JDYEND", c_int), ("WETSUPS", c_float), ("WSMON", _f(12)),
           ("BALERR", c_float)]
        + [(n, _f(366)) for n in KDAILY]
    )


_KLIB = None


def klib() -> ctypes.CDLL:
    """The library with the kernel's csk_* signatures declared."""
    global _KLIB
    if _KLIB is not None:
        return _KLIB
    handle = lib()
    handle.csk_version.restype = c_int
    handle.csk_version.argtypes = []
    handle.csk_struct_size.restype = c_int
    handle.csk_struct_size.argtypes = [c_int]
    handle.csk_run_year.restype = c_int
    handle.csk_run_year.argtypes = [
        POINTER(ParamsT), POINTER(SimT), POINTER(SoilT), POINTER(WeatherT),
        POINTER(StateT), POINTER(OptionsT), POINTER(StateT), POINTER(KResultT),
    ]
    for which, struct in enumerate((ParamsT, SimT, SoilT, WeatherT, StateT, OptionsT,
                                    KResultT), start=1):
        if handle.csk_struct_size(which) != ctypes.sizeof(struct):
            raise OSError(f"{struct.__name__} layout does not match the kernel "
                          f"({ctypes.sizeof(struct)} vs {handle.csk_struct_size(which)} bytes)")
    if handle.csk_version() != KERNEL_API_VERSION:
        raise OSError(f"kernel API version {handle.csk_version()}, "
                      f"expected {KERNEL_API_VERSION}")
    _KLIB = handle
    return handle
