"""cropsim_kernel.h must describe the same structures as the Fortran kernel.

Compiles a small C program against the header and compares every struct
size, and the API version, with what the built library reports. This is
what Rust (or any other C caller) relies on. The program is not linked to
the library, so the check also works on a repaired wheel.
"""

import shutil
import subprocess
import sys
from pathlib import Path

import pytest

from cropsim import _lib
from cropsim.kernel import REVERT_ALL

ROOT = Path(__file__).resolve().parents[1]


@pytest.mark.skipif(sys.platform == "win32" or shutil.which("cc") is None,
                    reason="needs a C compiler")
def test_header_matches_library(tmp_path):
    exe = tmp_path / "header_check"
    subprocess.run(["cc", "-I", str(ROOT / "fortran" / "kernel"),
                    str(ROOT / "tests" / "c" / "header_check.c"), "-o", str(exe)], check=True)
    version, sizes = subprocess.run([str(exe)], capture_output=True, text=True,
                                    check=True).stdout.splitlines()
    lib = _lib.klib()
    version, revert_all = version.split()
    assert int(version) == lib.csk_version()
    assert int(revert_all) == REVERT_ALL
    assert [int(s) for s in sizes.split()] == [lib.csk_struct_size(k) for k in range(1, 8)]
