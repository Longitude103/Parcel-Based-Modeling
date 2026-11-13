"""Write the week's full trace as CSV and XLSX."""
import sys, json, csv, pathlib
from parse_trace import parse
from meta import STEPS, VARS
run, ri, year, d0, outdir = pathlib.Path(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), pathlib.Path(sys.argv[5])
import datetime
r = parse(run/'fort.99')[ri]
rows = []
order = ['W1', 'W2', 'D0', 'D1', 'D2', 'D3', 'D4', 'D5', 'D5b', 'W3', 'D6', 'D7', 'D8', 'D9', 'D10']
for j in range(d0, d0+7):
    date = (datetime.date(year, 1, 1) + datetime.timedelta(days=j-1)).isoformat()
    recs = r['W'][j] + r['D'][j]
    seq = 0; upass = 0
    for st in order:
        for (s, name, idx, val) in recs:
            if s != st: continue
            if s in ('W3',) and name == 'GDDS_today': pass
            if name == 'pass': upass = int(val); continue
            seq += 1
            n, title, routine, sect = STEPS[s]
            unit, desc = VARS.get(name, ('', ''))
            rows.append(dict(date=date, day_of_year=j, diagram_step=n, step=title, routine=routine, tech_ref_section=sect,
                             order=seq, variable=name, layer=idx if idx else '', uptake_pass=upass if name in ('uptake', 'layer_avail') else '',
                             value=float(f'{val:.7g}'), units=unit, meaning=desc))
cols = list(rows[0].keys())
with open(outdir/'trace_week.csv', 'w', newline='') as fh:
    w = csv.DictWriter(fh, cols); w.writeheader(); w.writerows(rows)
print(len(rows))
# Excel copy: frozen header, filters, widths
from openpyxl import Workbook
from openpyxl.styles import Font
wb = Workbook(); ws = wb.active; ws.title = 'trace'
ws.append(cols)
for r_ in rows: ws.append([r_[c] for c in cols])
for c in ws[1]: c.font = Font(bold=True)
ws.freeze_panes = 'A2'; ws.auto_filter.ref = ws.dimensions
for col, wdt in zip('ABCDEFGHIJKLM', [11, 6, 6, 34, 20, 40, 6, 16, 6, 6, 14, 10, 50]): ws.column_dimensions[col].width = wdt
info = wb.create_sheet('read me')
for line in [
    'Trace of the original CropSim v8.0 program for one irrigated corn parcel, one week.',
    'Every value was written by the program itself while running (WRITE statements added to a copy of the frozen source; model results byte-identical to the untraced build).',
    'diagram_step: step number in the "How CropSim works" diagram. tech_ref_section: section of the CropSim v8.0 Technical Reference.',
    'order: execution order within the day. layer: soil layer 1-10 (blank for single values). uptake_pass: root uptake pass (step 8).',
    'Water depths in inches, water contents volumetric (in/in), temperatures in deg F. Step 1 weather rows (READWEAT) and step 6 Kc rows (CROPCO) are computed once at setup for every day of the year.',
]: info.append([line])
info.column_dimensions['A'].width = 140
wb.save(outdir/'trace_week.xlsx')
