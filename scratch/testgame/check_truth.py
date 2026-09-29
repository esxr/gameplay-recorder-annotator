import json,sys
rs=[json.loads(l) for l in open(sys.argv[1])]
g=[r["gf"] for r in rs]
print("lines",len(rs),"gf",g[0],g[-1],"contiguous",g==list(range(g[0],g[-1]+1)))
print("rendered false:",sum(1 for r in rs if not r.get("rendered",True)))
runs=[];i=0
while i<len(rs):
  if rs[i]["flash"]:
    j=i
    while j+1<len(rs) and rs[j+1]["flash"]: j+=1
    runs.append((rs[i]["gf"],j-i+1)); i=j+1
  else: i+=1
print("flash runs",runs, "len1",sum(1 for r in runs if r[1]==1),"len2",sum(1 for r in runs if r[1]==2))
ch=sum(1 for a,b in zip(rs,rs[1:]) if a["hud"]!=b["hud"]); print("hud changes",ch)
print("objectives",sorted(set(r["objective"] for r in rs)),"scenes",[ (r["gf"],r["scene"]) for a,r in zip(rs,rs[1:]) if a["scene"]!=r["scene"]])
ids={};
for r in rs:
  for e in r["enemies"]: ids.setdefault(e["id"],[]).append(r["gf"])
for k,v in sorted(ids.items()): print("enemy",k,"first",v[0],"last",v[-1],"frames",len(v),"gaps",sum(1 for a,b in zip(v,v[1:]) if b!=a+1))
