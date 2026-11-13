import sys
from parse_trace import parse, day_steps
runs = parse(sys.argv[1]); r = runs[int(sys.argv[2]) if len(sys.argv) > 2 else -1]
days = {}
for d, recs in r['D'].items():
    s = day_steps(recs)
    days[d] = dict(P=s['D0']['PRECIP'], RO=s.get('D3', {}).get('RUNOFF', 0.0), IRR=s['D10']['NETIRR_day'],
                   DR=s['D9']['DRAIN'], ET=s.get('D7', {}).get('E', 0) + s.get('D8', {}).get('T_final', 0),
                   KC=s['D6']['KC'], SR=s.get('D8', {}).get('SR', 1), AWD=s['D10']['AWDPLN_end'])
cands = []
for d0 in range(152, 245):
    w = [days[d] for d in range(d0, d0+7)]
    ro = sum(x['RO'] for x in w); irr = sum(1 for x in w if x['IRR'] > 0); dr = sum(x['DR'] for x in w)
    rain = sum(x['P'] for x in w)
    score = (3 if ro > 0.05 else 0) + (3 if irr else 0) + (2 if dr > 0.02 else 0) + (1 if any(x['P'] == 0 for x in w[:3]) else 0) + min(ro, 1)
    cands.append((score, d0, round(rain, 2), round(ro, 2), irr, round(dr, 2)))
cands.sort(reverse=True)
for c in cands[:12]: print(c)
if len(sys.argv) > 3:
    d0 = int(sys.argv[3])
    for d in range(d0, d0+7): print(d, {k: round(v, 3) for k, v in days[d].items()})
