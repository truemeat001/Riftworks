# P10-lab: 4-sector / 8-wave campaign insertion
**Independent lab only, not P09.** P09 frozen Run.gd SHA256 0302d739d13c69bf931f6b0644eee80fdfa0f9a98ec23baba87db002dffa4d25. Initial insertion Run.gd 943cd6578585153975dda3fa0561204bf38f9f0cf6c7d63fb6d7954753960e81. Validated Twin Beacons sector inserted **between** original Twin-Tide Bay and Echo Reef (old final sector moves from 3rd to 4th), preserving all original six-wave cohort parameters and optional risk rules. This model tests the full additional playtime and economy, not a production UI or map resource commit.

## Campaign design
| Wave | Sector | Main HP baseline | Main count | Specific rule |
|---:|---|---:|---:|---|
| 1 | Tidecross Ferry | 22 | 8 | Teach draw, positioning, switch original long/short route |
| 2 | Tidecross Ferry | 38 | 11 | Runners introduce crowd-control |
| 3 | Twin-Tide Bay | 66 | 12 | Guard escort, optional risk lane adds5 at twice HP |
| 4 | Twin-Tide Bay | 96 | 15 | Optional risk adds6, zero leak +6; keep original gate |
| 5 | **Twin Beacons** | 125 | 16 | Mandatory simultaneous independent north/south exits, shared HP; choose long-route side |
| 6 | **Twin Beacons** | 155 | 19 | Same parity role allocation, tighter pressure; no extra bonus |
| 7 (old5) | Echo Reef | 180 | 16 | Original amplifiers and Relay |
| 8 (old6) | Echo Reef | 215 | 19 incl. Boss1275 | Original boss, fixed1.1 speed; escape immediate loss |

New Twin Beacons HP125/155 is explicit progression interpolation between unchanged preceding96 and following180, not a change to existing waves. New sector uses third-cohort original count/speed rules; shifted Echo keeps effective cohort 2 count/speed, original role mix and HP. Only final wave contains Boss. Both Twin Beacon routes are mandatory main, parity of original main indices (no second flag), distinct exits(11,0)/(11,7) share health. Before each W5/6 choose north-long15/south-short11 or reverse, free, reversible, build-only; both route unions reserved. Equal pressure cannot be assumed; earlier replacement experiment measured genuine positional tradeoff. Existing P09 Guard Escort / optional SCREEN and CLUSTER, P08 Tide, tower/relic rarity/cost and all damage rules intact.

## Explicit economy
P09 closed-risk initial24 + base 5×12 =84 gross spendable through final build. Insertion closed-risk initial24 +7×12 =108, **+24** (four more 6-coin draws if pool/space permit). Old risk bonus unchanged: W3/W4 optional open followed by zero-leak gets additional+6 each; both model variants preserve these from same matching prefix. Final wave never grants base payout. No hidden adjustment to income/coins/damage/HP/boss; evaluate whether the larger roster and relic budget render the unchanged boss trivial or make health loss unrecoverable. Any compensation must be a separate controlled experiment, never quietly mixed into the initial comparison.

## Visual and UX requirements (not built in this lab)
Two distant visible core/beacon destinations linked to one global HP meter (show damage pulse from actual respective endpoint), two lane forecast cards with role counts and explicit long/short geometry, no risk bonus icon for mandatory sector, path and occupied cells remain valid when switching. Avoid rendering previous Twin-Tide art as if it were this new layout. New sector concept art, edge character sprite margins, readable placement/route preview and independent real-user tasks required before any production integration.

## Rule verification
Godot4.7.2 actual candidate entry tests/insertion_rules.gd, 708/708 passed. Actual forecast/spawn for all eight wave ordinals, old risk extra cases, same old HP/speeds/counts/role identities, no new enemy duplicates, explicit 7 base payouts and 108 gross total, terminal boss only W8, old risk payout condition, new sector does not receive old final amp, shifted Echo retains exact original damage/range. These are direct fixtures, not actual user play.

## Experiment design
30 seeds 437–466 × risk closed/open; baseline six-wave P09 and four inserted strategies (north-long balanced; south-long balanced; adaptive plan north-long then compare weaker-lane geometric coverage and optionally change orientation with same layout; novice random near-path only during new sector). Same actual paid RNG, no asset injection, legal deployment, merge when ownership>5; maintain optional P09 SCREEN/CLUSTER targeting consistently. Prefix through W4 and paid assets before entering original final/new inserted sector must match; when risk changes outcome, those failures are counted in both and not silently removed. Track per-wave leaks, bonus, actual draws, terminal Boss escape residual HP, final assets, and full campaign HP. Reward and combat RNG invariants checked per wave; model only, no player claim.

## Actual initial comparison (300 full runs; no compensation)
60 P09 (30 seeds×risk open/closed), 240 inserted (30×2×4 policies). **All 240 candidate histories through first four waves exactly equal their corresponding P09 prefix, 240/240**, including paid assets/HP/loot state; four candidate runs sharing the one failing open-risk seed did not arrive at Twin and were counted in denominator. Zero invariant failure. The desired +24 base rewards and +4 actual paid draws were observed in **every paired final-reaching case**, not just a budget formula. No additional currency leak. The table reports entire campaign wins and final wave reached (identical in this high-coverage-final-policy sample because every candidate reaching Echo ultimately won). Aggregate Twin leak counts cover played W5+W6 only, and include terminal deaths.

| Risk | Middle strategy | Won/30 | Median end HP | Twin total leaks | Mean total paid draws |
|---|---|---:|---:|---:|---:|
| Closed | P09 baseline | 30 | 15 | — | 14.00 |
| Closed | Fixed north long, balanced | 28 | 9 | 184 | 17.73 |
| Closed | Fixed south long, balanced | 28 | 8 | 198 | 17.73 |
| Closed | Adaptive orientation using weakest coverage | 26 | 8.5 | 222 | 17.47 |
| Closed | Near-path random only Twin | 19 | 1 | 368 | 16.53 |
| Open | P09 baseline | 29 | 9.5 | — | 14.30 |
| Open | Fixed north long, balanced | 20 | 4 | 112 | 16.77 |
| Open | Fixed south long, balanced | 20 | 3.5 | 125 | 16.77 |
| Open | Adaptive orientation using weakest coverage | 15 | 1 | 144 | 16.23 |
| Open | Near-path random only Twin | 11 | 0 | 226 | 15.37 |

**Important negative evidence:** the heuristic that improved the early replacement W3 fixed-layout test does not reliably improve the same new sector when inserted at W5/6. Aggregate weakest-coverage adaptive performs worse than both fixed balanced orientations in this later high-growth sample. Do not ship automatic "optimal side" or claim geometry solves damage/timing/role choices. Keep choice and explicit per-lane information. Always-open risk is a stressful policy, not mandatory gameplay; accumulated HP loss now matters much more in the following dual sector. Low-information Twin policy has material failure probability; tutorial and player feedback are essential.

## Terminal pressure telemetry (240 additional paired full runs)
Re-run same 30 seeds×2 risk for P09 and inserted adaptive, with two final Echo deployment policies: original strong coverage and **near-path random only final sector** (both W7/8 or original W5/6). First four wave prefixes equal60/60 for each paired set. Count actual Boss escaped vs reached/cleared and record remaining real path at kill (larger means killed earlier with more margin), Boss surviving HP immediately before escape. Both models use same unchanged Boss HP1275.

| Final policy | Risk | P09 / insertion reached final | P09 / insertion won | P09 / insertion Boss escapes | P09 / insertion median remaining path at Boss kill (cells) |
|---|---|---:|---:|---:|---:|
| Strong | Closed | 30 / 26 | 30 / 26 | 0 / 0 | 6.04 / 9.55 |
| Strong | Open | 29 / 15 | 29 / 15 | 0 / 0 | 6.34 / 9.73 |
| Near-path random | Closed | 30 / 26 | 4 / 22 | 25 / 4 | 1.76 / 5.39 |
| Near-path random | Open | 25 / 15 | 6 / 13 | 18 / 1 | 1.75 / 6.81 |

Survivor bias handled separately: **both versions reached final** for 26 closed/15 open in strong comparison, all paired killed Boss; median per-pair remaining path distance change +2.657/+1.830 cells. Near-path random has26 closed/13 open both-final pairs: wins4→22/4→12 and Boss escapes21→4/9→1; all paired actual paid draw differences +4. This is direct repeated-policy evidence of greater character budget improving late-wave resilience among those surviving the new middle sector, not proof that +24 alone caused all differences (extra stage placement/merge ownership and HP can interact). Across entire sample, near-path random closed candidate turns18 old losses into wins, no opposite; open turns9 old losses into wins and loses2 old wins—new sector can kill earlier. No claims about real player difficulty distribution.

**Initial conclusion:** progression pressure shifts into Twin Beacons, while additional normal growth makes the unchanged finale easier for surviving high-coverage play and substantially improves low-information late layouts. Do not simply inflate Boss or reduce rewards based on skilled final-only success: that ignores cumulative HP risk and removes demonstrated recovery potential. Assess budget effect separately and test a balanced optional-risk decision and real player feedback before production adoption.

## Separate economy counterfactual: hold earned funds, don't change rewards (120 more actual runs)
The only intervention is the **strategy** temporarily holding12 cash at W7,24 at W8 instead of spending those final two pre-wave payouts. All normal and optional-risk rewards still paid, no rule or production currency removal. Through new W6 spending and battle are identical. Candidate normal/hold same seed, risk and middle adaptive layout; test both final strong and final near-path random.

- Exact first six wave records60/60 equal for each pair group. For every both-final reached pair, hold policy made exactly four fewer draws and retained exactly24 more unspent gold; all previously earned rewards remained the same.
- Strong closed/open: normal and hold wins unchanged26/30 and15/30; no Boss escapes either. Median paired Boss-kill remaining path change from normal→hold −2.657/−1.830 cells, the exact reverse of earlier measured six/eight-wave paired gain.
- Near-path random final: normal→hold wins22→6 (closed),13→8 (open); escaped Boss4→17 (closed),1→6 (open). Strong same-prefix W7 pairs26/15; low-info same-prefix W7 pairs26/15, both final reached25/15. Holding led16 closed and5 open prior wins to fail, zero prior losses converted into wins. Median paired remaining kill-path change among shared kills −2.467/−3.835 cells.

This is a reversible budget-control experiment: no additional combat mechanics, no hidden income change, no account charges. Clearly demonstrates four extra late paid draws materially improve recovery for less-informed final layout, while skilled policy already wins with old budget and sees larger kill margin. **Recommend retaining full +24 growth, not reducing rewards or withholding currency in actual game.** Future boss pacing may be a separate explicit experiment only after player difficulty/segments evidence, because a uniform boss buff could erase precisely the improvement for less-informed players. Strong/weak placement proxies do not establish human distribution.

## Separate optional-risk policy check (30 actual runs)
Because always-open prior risk is not representative of informed player choices, test a simple stated, non-optimal policy: open W3 as before; after it, retain W4 open only if current visible HP≥13, otherwise disable and redeploy for single route. No rule, currency, HP or candidate change. Same seed and adaptive Twin strategy; first3 waves equal30/30 compared to always-open telemetry.

| Strategy | W4 opened/30 | Total prior risk +6 bonuses | Campaign wins | Median end HP |
|---|---:|---:|---:|---:|
| Always open | 30 | 13 | 15 | 1 |
| Health cap at W4 | 18 | 12 | 17 | 3.5 |

Three previously losing seeds 437/442/457 win, one prior winner456 loses. Not a guaranteed optimal threshold; the player can voluntarily decline, not a compulsory rule or automatic suggestion. Supports communicating cumulative shared HP before entering new dual sector and letting players manage risk; no need to alter prior optional-risk rewards. A pure geometric coverage threshold is insufficient (on prior open-risk records, high coverage sometimes correlated with higher leak because damage/range differ).

## Lab decision
Total690 actual runs across initial300, telemetry240, budget hold120 and risk cap30 (some repeated control policies intentionally; no independent human sample). All per-wave reward/loot-RNG/leak attribution assertions and 708 rule checks pass. P09 remains exact baseline SHA, no production merge or publish.

Recommend the 4-sector concept proceed as an **independent content candidate** with full +24 reward growth and existing boss unchanged for initial player evaluation. Evidence: spatial division and reversible routing previously verified, full campaign survives under reasoned per-lane allocation, but there are material cumulative health failures at W5/W6 for always-open risk and low-information placement. Do not automatically choose the long route by geometric coverage, don't guarantee class counters, and don't sell the lab data as game-ready. Before formal release, new Twin Beacons art/UI/two endpoint feedback, route preview and independent actual novice task must demonstrate understanding; collect actual failure-wave/HP/recovery evidence. If necessary, isolate new-sector-only HP scaling separately, not broad difficulty/currency shifts. Existing P09 production stabilization remains separate.

### Reproduce
Candidate Godot path is this insertion directory. Test tests/insertion_rules.gd. Model tests/insertion_matrix.gd command args mode, first=437, count=30, absolute result JSON. Modes insertion (four middle policies), insertion_trace and insertion_late (single adaptive middle with strong/random final), insertion_hoard, insertion_hoard_late, insertion_risk_cap; P09 exact Run.gd copied to independent temp project with same script for baseline, baseline_trace, baseline_late. Use separate XDG cache/data. Raw aggregate and per-run evidence in evidence/*.json and *.log. No paid tooling, no user-player records.
