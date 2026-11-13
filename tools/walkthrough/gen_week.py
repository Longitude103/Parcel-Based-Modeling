"""Turn the traced run into the walkthrough data (JSON for the page) and the trace table (CSV, XLSX).

usage: gen_week.py RUNDIR RUN_INDEX YEAR D0 OUTDIR
"""
import sys, json, csv, datetime, pathlib, re
from parse_trace import parse, day_steps
run, ri, year, d0, outdir = pathlib.Path(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), pathlib.Path(sys.argv[5])
outdir.mkdir(parents=True, exist_ok=True)
runs = parse(run/'fort.99'); r = runs[ri]
def date_of(j): return datetime.date(year, 1, 1) + datetime.timedelta(days=j-1)
days = []
for j in range(d0, d0+7):
    s = day_steps(r['D'][j]); w = day_steps(r['W'][j])
    pw = day_steps(r['W'][j-1]) if (j-1) in r['W'] else {}
    days.append({'jday': j, 'date': date_of(j).isoformat(), 'steps': s, 'W': w,
                 'prevGDDS': pw.get('W2', {}).get('GDDS', 0.0)})
season = []
for j in sorted(r['D']):
    s = day_steps(r['D'][j])
    th = s['D9']['THETA_end']; dep = s['D0']['DEPTH']
    season.append({'j': j, 'P': s['D0']['PRECIP'], 'RO': s.get('D3', {}).get('RUNOFF', 0.0),
                   'I': s['D10']['NETIRR_day'], 'IG': s['D10']['GROIRR_day'],
                   'E': s.get('D7', {}).get('E', 0.0), 'T': s.get('D8', {}).get('T_final', 0.0),
                   'D': s['D9']['DRAIN'], 'AWD': s['D10']['AWDPLN_end'], 'DPLA': s.get('D5', {}).get('DPLA'),
                   'KC': s['D6']['KC'], 'RZD': s['D1']['RZD'], 'ETR': s['D0']['ETR'], 'GDD': s['D0']['GDDS'],
                   'S': sum(th[k]*dep[k] for k in th)})
# annual line from the original's YR output
yr = [l for l in (run/'Results/Update2013/98/YR').glob('*_YR.TXT').__next__().read_text().splitlines() if f' {year} ' in l][0]
f = yr.split()
annual = dict(jdyplt=int(f[4]), jdyefc=int(f[7]), jdymat=int(f[8]), jdyfrz=int(f[9]), yield_=float(f[10]),
              ets=float(f[11]), sgrirr=float(f[12]), snirr=float(f[13]), irigno=int(f[14]), precips=float(f[15]),
              eprecips=float(f[16]), drains=float(f[17]))
# ---- cross-check against the original program's own daily printout (unit 7, CCTY_OUT.TXT) ----
out_txt = (run/'Results/Update2013/98').glob('*_OUT.TXT').__next__().read_text().splitlines()
# split into years: header line "CCTY<year>"
blocks, cur = {}, None
for l in out_txt:
    m = re.match(r'\s*[A-Z]{4}(\d{4})\s*$', l)
    if m: cur = int(m.group(1)); blocks[cur] = []; continue
    if cur and re.match(r'\s*\d+\s+\d+\s+-?\d', l): blocks[cur].append(l.split())
cum = {}
for row in blocks[year]:
    mo, dy = int(row[0]), int(row[1])
    j = datetime.date(2001, mo, dy).timetuple().tm_yday   # CropSim's CALDAY ignores leap years
    cum[j] = row
checks = []
cols = ['ETR','ETRS','ES','TS','ETS','SNIRR','SGRIRR','PRECIPS','EPRECIPS','SNOH2O','RUNONS','CURVNO','RESIDUE','GDD','DRAINS','KC','DPLN','AWDPLN','DPLPER','RZD','PAW','AWATER','TOTWAT']
for d in days:
    j = d['jday']; s = d['steps']
    if j not in cum: continue
    row = dict(zip(cols, map(float, cum[j][2:])))
    pairs = [('ETR', s['D0']['ETR']), ('ES', s['D10']['ES']), ('TS', s['D10']['TS']), ('ETS', s['D10']['ETS']),
             ('SNIRR', s['D10']['SNIRR']), ('SGRIRR', s['D10']['SGRIRR']), ('PRECIPS', s['D10']['PRECIPS']),
             ('EPRECIPS', s['D10']['EPRECIPS']), ('DRAINS', s['D10']['DRAINS']), ('KC', s['D6']['KC']),
             ('AWDPLN', s['D10']['AWDPLN_end']), ('RZD', s['D1']['RZD']), ('PAW', s['D1']['PAW']), ('AWATER', s['D1']['AWATER']),
             ('DPLN', s['D10']['DPLN_profile'])]
    for k, v in pairs:
        checks.append({'jday': j, 'var': k, 'printout': row[k], 'trace': v, 'ok': abs(round(v, 2) - row[k]) <= 0.011})
soil = (run/'CSMODEL/SOIL/NESOILS.DAT').read_text().splitlines()[1].split()
sim = [l.split() for l in (run/'CSModel/SIM/98/ZONE1/CRNIRR.SIM').read_text().splitlines()]
inputs = {'soil_code': int(soil[0]), 'bulkd': float(soil[1]), 'fc': [float(x) for x in soil[3:13]],
          'pwp': [float(x) for x in soil[13:23]], 'airdry': [float(x) for x in soil[23:25]],
          'plant': sim[1][:2], 'gdd': dict(zip(['GDDVEG','GDDFLO','GDDRIPE','GYFORM','GDDEFC','GDDMAT'], map(float, sim[2]))),
          'roots': dict(zip(['RZMIN','RZMAX','TBREAK','GDDROOT','RZMGMT'], map(float, sim[3]))),
          'yield': sim[4], 'pad': sim[8][1:], 'rainal': sim[9][:5], 'syscap': float(sim[9][5]), 'iper': sim[10],
          'apmin': sim[11], 'apmax': sim[12], 'smalli': sim[13], 'gstart': float(sim[14][0]), 'gstop': float(sim[14][1]),
          'eapp': sim[15], 'tbase': 50.0, 'tceil': 86.0, 'etrfact': 0.95, 'cn': [67, 78, 85, 89], 'cnfallow': [77, 86, 91, 94],
          'resid_init': 6000.0}
data = {'inputs': inputs, 'site': json.loads(sys.argv[6]) if len(sys.argv) > 6 else {}, 'year': year, 'd0': d0, 'days': days, 'season': season, 'annual': annual, 'checks': checks,
        'check_summary': {'n': len(checks), 'ok': sum(c['ok'] for c in checks)}}
(outdir/'week.json').write_text(json.dumps(data))
print('checks', data['check_summary'], [c for c in checks if not c['ok']][:5])
