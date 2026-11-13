"""cropsim_kernel.h must describe the same structures as the Fortran kernel.

Compiles a small C program against the header and the built library and
compares every struct size with csk_struct_size. This is what Rust (or any
other C caller) relies on.
"""

import shutil
import subprocess
import sys

import pytest

from cropsim import _lib

ROOT = __import__("pathlib").Path(__file__).resolve().parents[1]


@pytest.mark.skipif(sys.platform == "win32" or shutil.which("cc") is None,
                    reason="needs a C compiler")
def test_header_matches_library(tmp_path):
    lib = _lib.find_library()
    exe = tmp_path / "header_check"
    subprocess.run(["cc", "-I", str(ROOT / "fortran" / "kernel"),
                    str(ROOT / "tests" / "c" / "header_check.c"), str(lib),
                    f"-Wl,-rpath,{lib.parent}", "-o", str(exe)], check=True)
    out = subprocess.run([str(exe)], capture_output=True, text=True)
    assert out.returncode == 0, out.stdout + out.stderr
