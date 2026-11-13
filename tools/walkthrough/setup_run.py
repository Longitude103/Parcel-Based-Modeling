import sys, shutil, pathlib
FIX = pathlib.Path(__file__).resolve().parents[2]/'tests'/'fixtures'
def make(run, fix=FIX, site='TEST', year1=2010, prfile="3 1 0 2010 2014 0\n", wea_glob=None):
    run = pathlib.Path(run); shutil.rmtree(run, ignore_errors=True)
    cs = run/'CSMODEL'; (cs/'WEA').mkdir(parents=True); (cs/'SOIL').mkdir()
    zone = run/'CSModel'/'SIM'/'98'/'ZONE1'; zone.mkdir(parents=True)
    out = run/'Results'/'Update2013'/'98'
    for s in ('Mon','YR','Precip'): (out/s).mkdir(parents=True)
    (run/'RESULTS').mkdir()
    for f in ('BLOCK.DAT','TILLAGE.DAT','INITIAL.DAT'): shutil.copy(fix/f, cs/f)
    shutil.copy(fix/'NESOILS.DAT', cs/'SOIL'/'NESOILS.DAT')
    shutil.copy(fix/'soilsites.csv', cs/'SOIL'/'NE_allsoil.CSV')
    (cs/'PRFILE').write_text(prfile)
    (cs/'WsiteInfo_ALL2013.txt').write_text(f"{site} 1 1 {year1}\n")
    for f in (fix/'wea').iterdir(): shutil.copy(f, cs/'WEA'/f.name)
    for f in (fix/'sim').iterdir(): shutil.copy(f, zone/f.name)
    shutil.copy(fix/'cropping.csv', zone/'Cropping2013.csv')
if __name__ == '__main__': make(sys.argv[1])
