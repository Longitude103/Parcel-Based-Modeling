import json, sys, pathlib
week, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
d = json.loads(week.read_text())
d['provenance'] = json.loads(pathlib.Path(sys.argv[3]).read_text()) if len(sys.argv) > 3 else []
t = pathlib.Path(__file__).parent/'template.html'.read_text()
js = json.dumps(d, separators=(',', ':')).replace('</', '<\\/')
out.write_text(t.replace('/*DATA*/null', js))
print(out, len(js)//1024, 'KB')
