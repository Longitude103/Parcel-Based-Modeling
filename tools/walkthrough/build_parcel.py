"""Lay out a CropSim run folder for one irrigated corn parcel in central Nebraska.

usage: build_parcel.py RUNDIR WEATHER_DIR YEAR [YEAR...]
WEATHER_DIR holds SITE<year>.WEA files in CropSim format.
"""
import sys, shutil, pathlib
FIX = pathlib.Path(__file__).resolve().parents[2]/'tests'/'fixtures'
run = pathlib.Path(sys.argv[1]); wdir = pathlib.Path(sys.argv[2]); years = [int(y) for y in sys.argv[3:] if y.isdigit()]
SITE = sys.argv[-1] if not sys.argv[-1].isdigit() else 'SCTB'
years = [y for y in years]
SOIL = 822   # water-holding class 8, hydrologic group B
shutil.rmtree(run, ignore_errors=True)
cs = run/'CSMODEL'; (cs/'WEA').mkdir(parents=True); (cs/'SOIL').mkdir()
zone = run/'CSModel'/'SIM'/'98'/'ZONE1'; zone.mkdir(parents=True)
out = run/'Results'/'Update2013'/'98'
for s in ('Mon','YR','Precip'): (out/s).mkdir(parents=True)
(run/'RESULTS').mkdir()
# Model constants: the repo's test BLOCK.DAT (SCS curve numbers, ETRFACT 0.95, 4-8-12x8 in layers)
shutil.copy(FIX/'BLOCK.DAT', cs/'BLOCK.DAT')
shutil.copy(FIX/'TILLAGE.DAT', cs/'TILLAGE.DAT')
# Soil: representative silt loam (Hord / Hastings type), 2.2 in/ft available water
fc  = [0.280, 0.280, 0.280, 0.270, 0.270, 0.270, 0.260, 0.260, 0.260, 0.260]
pwp = [0.110, 0.110, 0.110, 0.100, 0.100, 0.100, 0.090, 0.090, 0.090, 0.090]
(cs/'SOIL'/'NESOILS.DAT').write_text("CODE BULKD ORGM FC(1-10) PWP(1-10) AIRDRY(1-2)\n"
    f"{SOIL} 1.40 1.5 " + " ".join(f"{v:.3f}" for v in fc) + " " + " ".join(f"{v:.3f}" for v in pwp) + " 0.040 0.070\n")
codes = (411,412,421,422,431,432,442,512,521,522,532,542,612,621,622,631,632,642,721,722,731,732,821,822,831,832,921,922)
(cs/'SOIL'/'NE_allsoil.CSV').write_text("NWS,MUID,SOILS\n" + f"{SITE},1," + ",".join('1' if c == SOIL else '0' for c in codes) + "\n")
# Start of the spin-up year: profile at 85% of available water, corn residue on the surface
th = [round(p + 0.85*(f-p), 3) for f, p in zip(fc, pwp)]
(cs/'INITIAL.DAT').write_text(" ".join(f"{v:7.3f}" for v in th) + "\n     8      6000.0     0\n"
    "      32.0      0.00      30.0   32.0   35.0   40.0   45.0   48.0   50.0   50.0   50.0   50.0\n")
# Daily printout for this site and soil (the original's own detailed output, used as a cross-check)
(cs/'PRFILE').write_text(f"3 1 {SOIL} {years[0]} {years[-1]} 1\n{SITE}\n")
(cs/'WsiteInfo_ALL2013.txt').write_text(f"{SITE} 1 1 {years[0]}\n")
for y in years: shutil.copy(wdir/f"{SITE}{y}.WEA", cs/'WEA'/f"{SITE}{y}.WEA")
# Irrigated corn under a centre pivot, continuous corn, planted May 1, no-till (planter pass only)
sim = """8 10
5 5 1 1 12 31
650 1250 1800 1150 1100 2400
6.0 60.0 50.0 100.0 36.0
2 230.0 1.0
0 0.0 0.0 0.0
1 1
1 0 6
3 0.50 0.40 0.50 0.50 0.50
0.25 0.25 0.25 0.25 0.25 0.30
0.90 0.90 0.90 0.90 0.90
0.75 0.75 0.75 0.75 0.75
1.10 1.10 1.10 1.10 1.10
0.50 0.50 0.50 0.50 0.50
300.0 2200.0 1 0
0.85 0.85 0.85 0.85 0.85
0.0 0.0 0.0 0.0 0.0
0.0 0.0 0.0 0.0 0.0
"""
(zone/'CRNIRR.SIM').write_text(sim)
(zone/'Cropping2013.csv').write_text("".join(f"CRNIRR,{y}\n" for y in years))
print('ok', run)
