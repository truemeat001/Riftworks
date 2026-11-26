#!/usr/bin/env python3
"""Recomputable analytical P05 baseline, NOT combat simulation or human playtest."""
from pathlib import Path
from fractions import Fraction as F
import hashlib, json, re, math
root=Path(__file__).resolve().parents[1]
src=(root/'src/Run.gd').read_bytes()
assert hashlib.sha256(src).hexdigest()=="7f623075e85a6f4f8ce898c9622c75f0d605694be1a5c114b06570088bd2e0e0", "baseline changed; consciously version this model"
s=src.decode()
def scalar(k):return F(re.search(r'^const '+k+r'=(\d+(?:\.\d+)?)$',s,re.M).group(1))
def arr(k):return [F(str(v)) for v in json.loads(re.search(r'^const '+k+r'=(\[.*?\])$',s,re.M).group(1))]
cost=scalar('DRAW_COST'); p=scalar('CHARACTER_WEIGHT'); q=scalar('RELIC_WEIGHT')
assert p+q==1
damage,cd,ranks,range_base,range_rank,wave_hp=(arr(n) for n in ('BASE_DAMAGE','BASE_COOLDOWN','RANK_DAMAGE','BASE_RANGE','RANK_RANGE','WAVE_HP'))
# Draw all 4 initial chests, no sales/merge, no capacity/max-rank effects. First two forced-uniform role.
dist={2:q*q,3:2*p*q,4:p*p}
assert sum(dist.values())==1
expected=sum(n*prob for n,prob in dist.items())
assert expected==F(17,5)
print('opening four draws (analytic):', {n:float(v) for n,v in dist.items()}, 'mean characters',float(expected))
print('opening first two same role:',float(F(1,3)), 'two later relics:',float(q*q))
print('conditional no requested role in four eligible category draws:',float((1-p/3)**4))
print('gold from initial+5 nonfinal base wins:',24+5*12, 'max risk bonus both stage2 waves:',2*6)
print('draw cost',float(cost),'base salvage',4,'net liquidation -2; 3 failed-target sales cost 6')
for i,name in enumerate(('pulse','frost','burst')):
 print(name,'rank1 damage',float(damage[i]),'base nominal DPS',round(float(damage[i]/cd[i]),3),'rank2 DPS',round(float(damage[i]*ranks[1]/cd[i]),3),'rank3 DPS',round(float(damage[i]*ranks[2]/cd[i]),3))
print('rank2 per input efficiency',float(ranks[1]/2),'rank3 per input efficiency',float(ranks[2]/4))
# Pure HP sum, not actual kill budget or duration: role ordering copied from frozen source; no slow/overkill/splash/positions.
for stage in range(3):
 for wave in range(2):
  main=8+wave*3+stage*4; counts={k:0 for k in ('normal','runner','guard','boss')}
  for idx in range(main):
   role='boss' if stage==2 and wave==1 and idx==main-1 else ('normal' if stage==0 and wave==0 else ('guard' if stage>=1 and idx%5==3 else ('runner' if idx%4==1 else 'normal')))
   counts[role]+=1
  hp=wave_hp[stage*2+wave]; net=hp*(counts['normal']+F(3,5)*counts['runner']+F(8,5)*counts['guard'])+scalar('BOSS_HP')*counts['boss']
  extra=(5+wave)*hp*2 if stage==1 else F(0)
  print(f's{stage+1}w{wave+1}',counts,'total_hp',float(net),'optional_extra_hp',float(extra))
# Hand check R2 Pulse, one power + one range + amplifier + relay1.
d=damage[0]*ranks[1]*(1+F(35,100))*F(135,100)*F(125,100)
r=range_base[0]+1+range_rank[1]+F(1,2)+F(1,4)
print('R2 Pulse power1/range1/amp/relay1:',float(d),float(r),'conductive hit',float(d*F(6,5)))
assert d==F(532899,12800) and r==F(99,20)
