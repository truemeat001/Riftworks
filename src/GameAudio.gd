extends Node
## Presentation-only original sound controller; no game/model reference or RNG.
## Coordinates accepted by play_event are logical grid cell coordinates, not pixels.

const AUDIO_PATH="res://assets/audio/runtime/"
const INVALID_POS=Vector2(-1,-1)
const BASE_DB={"Master":-4.0,"SFX":-2.0,"UI":-2.0,"Combat":-4.0,"Alert":-1.0,"Ambience":-4.0,"Music":-4.0}
const BUS_PARENT={"SFX":"Master","UI":"SFX","Combat":"SFX","Alert":"SFX","Ambience":"Master","Music":"Master"}
const LIMITS={"loot":4,"UI":2,"Combat":6,"Alert":2}
const VARIANTS={"chest_charge":1,"chest_open":3,"loot_crew":1,"loot_relic":1,"loot_upgrade":1,"loot_arrive":1,"ui_press":1,"ui_reject":1,"deploy":3,"recall":1,"merge":1,"sell":1,"wave_start":1,"hit_pulse":3,"hit_frost":3,"hit_burst":3,"kill":3,"conductive":3,"shatter":3,"danger":1,"leak":1,"wave_clear":1,"victory":1,"defeat":1}
const COMBAT_IDS=["hit_pulse","hit_frost","hit_burst","kill","conductive","shatter"]
const ALERT_IDS=["wave_start","danger","leak"]
const LOOT_IDS=["chest_charge","chest_open","loot_crew","loot_relic","loot_upgrade","loot_arrive"]
# Per-event amplitude trims keep overlapping bursts below master headroom.
const EVENT_GAIN={"chest_charge":-3.0,"chest_open":-5.0,"loot_crew":-4.0,"loot_relic":-3.0,"loot_upgrade":-3.0,"loot_arrive":-1.0,"ui_press":-4.0,"ui_reject":-3.0,"deploy":-3.0,"recall":-2.0,"merge":-4.0,"sell":-3.0,"wave_start":-3.0,"hit_pulse":-6.0,"hit_frost":-5.0,"hit_burst":-6.0,"kill":-5.0,"conductive":-8.0,"shatter":-7.0,"danger":-2.0,"leak":-2.0,"wave_clear":-4.0,"victory":-3.0,"defeat":-3.0}
const COMBAT_GAP={"hit_pulse":0.07,"hit_frost":0.09,"hit_burst":0.10,"kill":0.09,"conductive":0.15,"shatter":0.15}
const LOOT_THRESHOLDS=[0.32,0.34,1.22]
var unlocked:bool=false
var battle_active:bool=false
var battle_paused:bool=false
var danger_active:bool=false
var volumes:Dictionary={}
var muted:bool=false
var _streams:Dictionary={}
var _voices:Array=[]
var _music:AudioStreamPlayer
var _sea:AudioStreamPlayer
var _battle_bed:AudioStreamPlayer
var _clock:float=0.0
var _duck:float=0.0
var _mix:float=0.0
var _serial:int=0
var _variant_next:Dictionary={}
var _last_combat:Dictionary={}
var _last_danger:float=-1000.0
var _loot_active:bool=false
var _loot_age:float=0.0
var _loot_result:String=""
var _loot_next:int=0
var _event_log:Array=[]
var _dropped:int=0

func _ready()->void:
	# Do not play anything in ready: browser audio starts from a user gesture only.
	for bus_name in BASE_DB:
		volumes[bus_name]=1.0
		var i=AudioServer.get_bus_index(bus_name)
		if i<0:
			AudioServer.add_bus()
			i=AudioServer.bus_count-1
			AudioServer.set_bus_name(i,bus_name)
		if BUS_PARENT.has(bus_name):
			AudioServer.set_bus_send(i,BUS_PARENT[bus_name])
	# Explicitly restate sends after all buses exist (bus order remains Master, SFX etc.).
	for bus_name in BUS_PARENT:
		AudioServer.set_bus_send(AudioServer.get_bus_index(bus_name),BUS_PARENT[bus_name])
	for bus_name in volumes:_apply_volume(str(bus_name))
	_apply_volume("Master")
	for event_id in VARIANTS:
		var files:Array=[]
		for n in range(1,int(VARIANTS[event_id])+1):
			var p="%ssfx_%s_%02d.wav"%[AUDIO_PATH,event_id,n]
			var s=load(p) as AudioStreamWAV
			if s!=null:files.append(s)
		_streams[event_id]=files
	_sea=_make_loop("ambience_sea_loop.wav")
	_battle_bed=_make_loop("ambience_battle_loop.wav")
	_set_beds()

func _make_loop(file:String)->AudioStreamPlayer:
	var p=AudioStreamPlayer.new()
	p.bus="Ambience"
	p.stream=load(AUDIO_PATH+file)
	if p.stream is AudioStreamWAV:
		# Imported PCM16 stereo = 4 bytes per frame; actual frame count is tested.
		p.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		p.stream.loop_begin=0
		p.stream.loop_end=roundi(p.stream.get_length()*p.stream.mix_rate)
	p.volume_db=-80.0
	add_child(p)
	return p

func unlock()->void:
	if unlocked:return
	unlocked=true
	if _sea!=null and _sea.stream!=null:_sea.play()
	if _battle_bed!=null and _battle_bed.stream!=null:_battle_bed.play()

func set_muted(value:bool)->void:
	muted=value
	var i=AudioServer.get_bus_index("Master")
	if i>=0:_apply_volume("Master")

func is_muted()->bool:return muted

func set_volume(bus:String,linear:float)->void:
	if not BASE_DB.has(bus):return
	volumes[bus]=clampf(linear,0.0,1.0)
	_apply_volume(bus)

func get_volume(bus:String)->float:return float(volumes.get(bus,1.0))

func _apply_volume(bus:String)->void:
	var i=AudioServer.get_bus_index(bus)
	if i<0:return
	var trim:float=BASE_DB[bus]
	if bus=="Combat" or bus=="Music":trim+=_duck
	AudioServer.set_bus_volume_db(i,trim+linear_to_db(maxf(get_volume(bus),0.0001)))
	# Master mute is separate from fader. Other faders at exact zero cannot leak.
	if bus!="Master":AudioServer.set_bus_mute(i,get_volume(bus)<=0.0)
	else:AudioServer.set_bus_mute(i,muted or get_volume(bus)<=0.0)

func _set_beds()->void:
	if _sea!=null:_sea.volume_db=linear_to_db(maxf(0.0001,lerpf(0.66,0.27,_mix)))
	if _battle_bed!=null:_battle_bed.volume_db=linear_to_db(maxf(0.0001,_mix*0.55))

func _group(id:String)->String:
	if id in LOOT_IDS:return "loot"
	if id in COMBAT_IDS:return "Combat"
	if id in ALERT_IDS:return "Alert"
	return "UI"

func _purge_voices()->void:
	for i in range(_voices.size()-1,-1,-1):
		var p:Node=_voices[i].player
		if not is_instance_valid(p) or not p.playing:
			if is_instance_valid(p):p.queue_free()
			_voices.remove_at(i)

func _stop_groups(groups:Array)->void:
	for i in range(_voices.size()-1,-1,-1):
		if _voices[i].group in groups:
			var p:Node=_voices[i].player
			if is_instance_valid(p):p.stop();p.queue_free()
			_voices.remove_at(i)

func _stop_event(id:String)->void:
	for i in range(_voices.size()-1,-1,-1):
		if _voices[i].id==id:
			var p:Node=_voices[i].player
			if is_instance_valid(p):p.stop();p.queue_free()
			_voices.remove_at(i)

func _set_group_pause(groups:Array,flag:bool)->void:
	for v in _voices:
		if v.group in groups and is_instance_valid(v.player):v.player.stream_paused=flag

func _record(event_id:String,group:String,variant:int,pos:Vector2)->void:
	_serial+=1
	_event_log.append({"serial":_serial,"id":event_id,"group":group,"variant":variant,"pos":pos,"time":_clock,"loot_age":_loot_age if group=="loot" else -1.0})
	if _event_log.size()>256:_event_log.pop_front()

func event_history()->Array:return _event_log.duplicate(true)

func voice_counts()->Dictionary:
	_purge_voices()
	var counts={"loot":0,"UI":0,"Combat":0,"Alert":0,"Ambience":0}
	for v in _voices:counts[v.group]+=1
	if _sea!=null and _sea.playing:counts.Ambience+=1
	if _battle_bed!=null and _battle_bed.playing:counts.Ambience+=1
	return counts

func dropped_events()->int:return _dropped

func play_event(id:String,pos:Vector2=INVALID_POS,variant_hint:int=0)->bool:
	if not unlocked or not VARIANTS.has(id):return false
	var group:String=_group(id)
	if group=="Combat" and (not battle_active or battle_paused):return false
	if group=="Alert" and battle_paused:return false
	if group=="Combat" and _clock-float(_last_combat.get(id,-1000.0))<float(COMBAT_GAP[id]):
		_dropped+=1;return false
	var sources:Array=_streams.get(id,[])
	if sources.is_empty():return false
	_purge_voices()
	var same:Array=[]
	for i in range(_voices.size()):
		if _voices[i].group==group:same.append(i)
	if same.size()>=int(LIMITS[group]):
		# Combat overload drops new decoration; UI/loot/alert replaces the oldest tail.
		if group=="Combat":_dropped+=1;return false
		var idx:int=same[0]
		var old:Node=_voices[idx].player
		if is_instance_valid(old):old.stop();old.queue_free()
		_voices.remove_at(idx)
	if group=="Combat":_last_combat[id]=_clock
	var variant:int=variant_hint-1 if variant_hint>0 else int(_variant_next.get(id,0))
	variant=posmod(variant,sources.size())
	_variant_next[id]=variant+1
	var voice:Node
	if pos.x>=0.0 and pos.y>=0.0 and (group=="Combat" or group=="Alert"):
		var p=AudioStreamPlayer2D.new()
		# Logical position matches the actual battlefield; default viewport listener provides panning.
		p.position=Vector2(52.0+(clampf(pos.x,0,11)+0.5)*76,60.0+(clampf(pos.y,0,7)+0.5)*76)
		p.max_distance=1680.0
		p.attenuation=0.5
		p.panning_strength=0.85
		voice=p
	else:voice=AudioStreamPlayer.new()
	voice.stream=sources[variant]
	voice.bus="UI" if group=="loot" else group
	voice.volume_db=float(EVENT_GAIN.get(id,-4.0))
	add_child(voice)
	voice.play()
	_voices.append({"id":id,"group":group,"player":voice})
	_record(id,group,variant+1,pos)
	return true

func start_loot(result:Dictionary)->void:
	skip_loot()
	if result.is_empty() or not result.get("ok",true):return
	var kind:String=result.get("kind","")
	if kind=="tower":_loot_result="loot_crew"
	elif kind=="core":_loot_result="loot_upgrade" if int(result.get("rank",1))>=2 else "loot_relic"
	else:return
	if not unlocked:return
	_loot_active=true
	_loot_age=0.0
	_loot_next=0
	play_event("chest_charge")

func advance_loot(age:float)->void:
	if not _loot_active:return
	var previous=_loot_age
	_loot_age=maxf(age,previous)
	# A suspended/backgrounded tab must not dump a queue of stale cues on return.
	if _loot_age-previous>0.55:
		skip_loot()
		return
	while _loot_next<LOOT_THRESHOLDS.size() and _loot_age>=float(LOOT_THRESHOLDS[_loot_next]):
		match _loot_next:
			0:play_event("chest_open")
			1:play_event(_loot_result)
			2:play_event("loot_arrive")
		_loot_next+=1
	if _loot_age>=1.35:_loot_active=false

func skip_loot()->void:
	_loot_active=false
	_loot_next=0
	_loot_age=0.0
	_loot_result=""
	_stop_groups(["loot"])

func set_battle_active(active:bool)->void:
	if battle_active==active:return
	battle_active=active
	if active:
		_last_combat.clear()
		_last_danger=-1000.0
	else:
		battle_paused=false
		set_danger(false)
		_stop_groups(["Combat","Alert"])

func set_battle_paused(flag:bool)->void:
	battle_paused=flag and battle_active
	_set_group_pause(["Combat","Alert"],battle_paused)
	# Keep environment running; battle bed fades toward quiet during pause.

func set_danger(active:bool,pos:Vector2=Vector2(11,4))->void:
	var valid=active and battle_active
	if valid==danger_active:return
	danger_active=valid
	if valid and not battle_paused and _clock-_last_danger>=2.2:
		_last_danger=_clock
		play_event("danger",pos)
	elif not valid:_stop_event("danger")

func reset_scene()->void:
	skip_loot()
	battle_active=false
	battle_paused=false
	danger_active=false
	_last_danger=-1000.0
	_last_combat.clear()
	_stop_groups(["Combat","Alert","UI"])
	_mix=0.0
	_duck=0.0
	_apply_volume("Combat")
	_apply_volume("Music")
	_set_beds()

func _process(delta:float)->void:
	_clock+=maxf(delta,0.0)
	_purge_voices()
	var target:float=-4.0 if danger_active and not battle_paused else 0.0
	var sec:float=0.15 if target<_duck else 0.5
	var old=_duck
	_duck=move_toward(_duck,target,4.0*maxf(delta,0.0)/sec)
	if not is_equal_approx(old,_duck):_apply_volume("Combat");_apply_volume("Music")
	_mix=move_toward(_mix,1.0 if battle_active and not battle_paused else 0.0,maxf(delta,0.0)/0.45)
	_set_beds()
