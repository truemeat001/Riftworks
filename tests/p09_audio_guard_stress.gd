extends "res://tests/p08_audio_stress.gd"
## P08 shipped mixer pressure fixture plus rare guard cue at most 4/s.
## Controller stress only; actual model binding independently checked in p09_audio_guard_tests.
func dense(seconds:float)->void:
 var duration:int=roundi(seconds*1000.0);var begin:int=Time.get_ticks_msec();var next_tick:int=0
 while Time.get_ticks_msec()-begin<duration:
  var elapsed:int=Time.get_ticks_msec()-begin
  while next_tick*25<=elapsed:
   for i in range(ATTACKS.size()):controller.play_event(ATTACKS[i],Vector2(float((i+next_tick)%12),float(i%8)),1+(next_tick%3))
   if next_tick%12==0:controller.play_event("hit_intercept",Vector2(9,4),1+(next_tick%3))
   next_tick+=1
  await process_frame;pull()
  var counts:Dictionary=controller.voice_counts()
  for group in counts:bus_peaks[group]=maxi(int(bus_peaks.get(group,0)),int(counts[group]))
  OS.delay_msec(4)
