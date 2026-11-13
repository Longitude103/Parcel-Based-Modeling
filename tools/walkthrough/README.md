# Seven-day parcel walkthrough

Tools that build the "Corn Parcel Week" page: one irrigated corn parcel run
through the **original, unchanged** CropSim v8.0 Fortran, with every
intermediate value of every daily step written to a trace and laid out
equation by equation for the technical review group.

The original source (`fortran/original/CROPSIM_V8.0.F90`) is never edited.
`make_traced.py` writes a separate copy that has the repo's three parity edits
(run-folder path, path separators, module reset between soils) plus `WRITE`-only
`CALL TRC(...)` lines to unit 99. The traced build's outputs are byte-identical
to an untraced build (`ref_build.py`).

## Steps

```bash
# 1. traced build (needs gfortran)
python3 make_traced.py ../../fortran/original/CROPSIM_V8.0.F90 traced.f90
gfortran -O2 -ffree-line-length-none -std=legacy -o cropsim_traced traced.f90

# 2. one-parcel run folder: WEA_DIR holds SITEyyyy.WEA files; first year is spin-up
python3 build_parcel.py run_2018 WEA_DIR 2017 2018 SCTB
(cd run_2018 && ../cropsim_traced)          # writes run_2018/fort.99

# 3. pick a week (scores rain, runoff, irrigation, drainage); run index 1 = second year
python3 select_week.py run_2018/fort.99 1 191

# 4. page data, trace table, page
python3 gen_week.py run_2018 1 2018 191 out "$(cat site.json)"   # out/week.json, cross-checks vs *_OUT.TXT
python3 write_table.py run_2018 1 2018 191 out                     # out/trace_week.csv, .xlsx
python3 assemble.py out/week.json out/page.html provenance.json

# 5. optional screenshot check (Playwright + katex from npm, or KATEX_JS=path)
node shot.js out/page.html out/s.png "0:1,2:5,6:3"
```

`gen_week.py` compares the traced values with the model's own daily printout
(print level 3) and stores the result in `week.json` (`check_summary`).

## Files

| File | What it does |
| --- | --- |
| `make_traced.py` | Writes the traced copy of the Fortran (string-anchored inserts, asserts if an anchor moves) |
| `ref_build.py` | Untraced copy with the parity edits only, for the byte-identical check |
| `build_parcel.py`, `setup_run.py` | Lay out a run folder: representative soil 822, corn SIM with demand scheduling, repo test-fixture BLOCK/TILLAGE |
| `parse_trace.py` | Reads `fort.99` into runs → days → steps |
| `meta.py` | Trace step → diagram step, routine, tech-reference section; variable units and meanings |
| `select_week.py`, `gen_week.py`, `write_table.py`, `assemble.py` | Week choice, page data, trace table, page assembly |
| `template.html` | The page (KaTeX for equations) |
| `site.json`, `provenance.json` | Text used for the published Scottsbluff 2018 example |
