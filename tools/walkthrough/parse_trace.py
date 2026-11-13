import collections, json, sys
def parse(path):
    runs = []; cur = None; last_kind = 'D'
    for line in open(path):
        step, day, name, idx, val = [x.strip() for x in line.split(',')]
        day, idx, val = int(day), int(idx), float(val)
        kind = step[0]
        if kind == 'W' and last_kind == 'D':
            cur = {'W': collections.defaultdict(list), 'D': collections.defaultdict(list)}; runs.append(cur)
        last_kind = kind
        cur[kind][day].append((step, name, idx, val))
    return runs
def day_steps(recs):
    """records for one day -> {step: {name: value or {idx: value}}}; repeated names in D8 uptake kept as lists"""
    out = collections.OrderedDict()
    for step, name, idx, val in recs:
        s = out.setdefault(step, collections.OrderedDict())
        if name in ('pass', 'uptake', 'layer_avail'):
            s.setdefault(name, []).append((idx, val))
        elif idx:
            s.setdefault(name, {})[idx] = val
        else:
            s[name] = val
    return out
if __name__ == '__main__':
    runs = parse(sys.argv[1])
    print(len(runs), [len(r['D']) for r in runs])
