#!/usr/bin/env python3
"""Score completed blinded listening CSVs; missing responses are not invented."""
import argparse,csv,json,statistics
from collections import Counter,defaultdict
TIERS=('crew','relic','upgrade')
FIELDS=('clarity_1_5','impact_1_5','material_fit_1_5','tail_natural_1_5','style_fit_1_5','fatigue_1_5_high_is_bad')

def main():
    p=argparse.ArgumentParser();p.add_argument('--key',required=True);p.add_argument('responses',nargs='+');a=p.parse_args()
    with open(a.key,encoding='utf-8-sig') as f:key={(r['block'],r['trial_id']):r['true_tier'] for r in csv.DictReader(f)}
    conf=defaultdict(Counter);ratings=defaultdict(lambda:defaultdict(list));n=Counter();correct=Counter();per_listener=[]
    for path in a.responses:
        seen=set();single_count=Counter();single_correct=Counter()
        with open(path,encoding='utf-8-sig') as f:
            for r in csv.DictReader(f):
                k=r['block'],r['trial_id']
                if k not in key or k in seen:raise ValueError(f'{path}: invalid or repeated trial {k}')
                seen.add(k);truth=key[k];guess=r['guessed_tier_crew_relic_upgrade'].strip().lower()
                if guess:
                    if guess not in TIERS:raise ValueError(f'{path}: invalid tier {guess!r}')
                    conf[r['block']][f'{truth}->{guess}']+=1;n[r['block']]+=1;single_count[r['block']]+=1
                    if guess==truth:correct[r['block']]+=1;single_correct[r['block']]+=1
                for f0 in FIELDS:
                    if r.get(f0,'').strip():
                        v=int(r[f0]);assert 1<=v<=5,(path,k,f0)
                        ratings[(r['block'],truth)][f0].append(v)
        per_listener.append({'file':path,'accuracy':{b:single_correct[b]/v for b,v in single_count.items()}})
    out={'response_files':len(a.responses),'blocks':{b:{'answered':n[b],'correct':correct[b],'accuracy':correct[b]/n[b] if n[b] else None,'confusion':dict(conf[b])} for b in sorted(set(n)|{k[0] for k in key})},
         'ratings':{f'{block}/{tier}':{field:{'n':len(v),'median':statistics.median(v)} for field,v in vals.items()} for (block,tier),vals in ratings.items()},
         'per_listener':per_listener,'note':'Repeated trials within the same listener are not independent participants; no subjective score reported for missing answers.'}
    print(json.dumps(out,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
