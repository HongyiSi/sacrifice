extends Node
## Client-only sound, driven by the same displayed events as the animation.
## Lives outside the rebuilt board; dialogs and resizing never replay a cue.
signal cue_played(file: String, offset: float)

var bank: Dictionary = {}
var support_bank: Dictionary = {}
var strike_bank: Dictionary = {}
var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var pending: Array = []
var planning_pending: Dictionary = {}
var seen: Dictionary = {}
var match_key := ""
var event_key := ""
var stage_started := 0
const AmuletTiming=preload("res://scripts/amulet_timing.gd")
const AMULETS=["holy_amulet","attack_amulet","magic_amulet"]
const DEFAULT_LEVEL := 0.5
var level := DEFAULT_LEVEL
var settings_path := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bank = JSON.parse_string(FileAccess.get_file_as_string("res://data/attack_sounds.json"))
	support_bank = JSON.parse_string(FileAccess.get_file_as_string("res://data/support_sounds.json"))
	strike_bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/strike_sync_sounds.json"))
	for sounds in strike_bank.values():
		for path in sounds.values():
			if not streams.has(path):streams[path]=load(path) as AudioStream
	# Tiny, frequent contact sounds should be ready before the first landing.
	for path in support_bank.get("card_movement",{}).values():
		streams[path] = load(path) as AudioStream
	for path in support_bank.get("cards",{}).get("reverse",{}).values():
		if not str(path).is_empty(): streams[path] = load(path) as AudioStream
	for key in AMULETS:
		for path in support_bank.get("cards",{}).get(key,{}).values():
			if not str(path).is_empty(): streams[path] = load(path) as AudioStream
	var folder := "res://local-data" if OS.has_feature("editor") else "user://"
	DirAccess.make_dir_recursive_absolute(folder)
	settings_path = folder.path_join("sound.cfg")
	var config := ConfigFile.new()
	if config.load(settings_path) == OK: level = clampf(float(config.get_value("sound","volume",DEFAULT_LEVEL)),0,1)
	for i in range(12):
		var player := AudioStreamPlayer.new()
		player.name = "CardSound%d" % i
		add_child(player)
		voices.append(player)
	_apply_volume()

func reset() -> void:
	pending.clear()
	planning_pending.clear()
	seen.clear()
	match_key = ""
	event_key = ""
	for player in voices: player.stop()

func _card_key(view: Dictionary, event: Dictionary) -> String:
	var action: Dictionary = event.get("action",{})
	if action.get("death",false): return ""
	var card: Dictionary = view.get("catalog",{}).get(action.get("card",-1),{})
	return str(card.get("key",""))

func cues_for(view: Dictionary) -> Array:
	var event: Dictionary = view.get("animation",{})
	if event.is_empty(): return []
	var kind: String = event.get("kind","")
	var stage: String = event.get("stage","")
	var style: String = event.get("style","")
	if preload("res://scripts/prepared_timing.gd").supports(event):return preload("res://scripts/prepared_timing.gd").cues(event,support_bank)
	var cues: Array = preload("res://scripts/ordinary_audio.gd").cues(event,support_bank)
	cues.append_array(preload("res://scripts/death_audio.gd").cues(event,support_bank))
	if event.get("op","")=="discard_finish":return cues
	if style=="cards_to_heart":return preload("res://scripts/heart_conversion_timing.gd").cues(event)
	var cards: Dictionary = bank.get("cards",{})
	var support: Dictionary = support_bank.get("cards",{})
	var key := _card_key(view,event) if kind == "card_start" else style
	# Shared shimmer is emitted once at the chest, never on reveal/transfer.
	if event.get("gem_polished",false):
		var gem:Dictionary=support.get(style,{})
		if stage=="travel":
			_append(cues,gem.get("shimmer",""),1.02,false,2.)
			if style=="topaz":_append(cues,gem.get("impact",""),1.42,false,2.)
		elif stage=="impact" and style in ["ruby","amber","amethyst"] and event.get("hp_gain",0)>0:
			_append(cues,gem.get("impact",""),0.,false,2.)
		elif stage=="discard" and event.get("consumed",false):
			_append(cues,support_bank.gem_movement.discard,0.,false,2.)
		return cues
	if kind=="draw_cards" and event.has("gem_overlay") and stage=="travel":
		_append(cues,support.get(event.gem_overlay.style,{}).get("impact",""),0.,false,2.)
	if kind=="draw_cards" and stage=="travel":
		for d in event.draws:
			if d.get("source_key","") not in ["sapphire","emerald"]:continue
			for i in range(d.count):
				if d.starts[i]>=0 and not d.returned[i]:
					_append(cues,support_bank.gem_movement.deal,d.starts[i]/1000.0+.12,false,1.24)

	var strike_timing=preload("res://scripts/strike_timing.gd")
	if kind=="strike" and style in strike_timing.SWORDS:
		var sounds:Dictionary=strike_bank[style]
		var travel=float(event.travel_ms)/1000.0
		if stage=="travel":_append(cues,sounds.lift,.025,false)
		for i in range(strike_timing.count(style)):
			var launch=strike_timing.contact(event,i)-strike_timing.flight_lead(style)
			if stage=="travel" and launch<travel:_append(cues,sounds.flight,launch,false)
			elif stage=="impact" and launch>=travel:_append(cues,sounds.flight,launch-travel,false)
			if stage=="impact" and event.get("targets",[]).any(func(h):return not h.get("miss",false) and not h.get("blocked",false)):
				_append(cues,sounds.impact,i*strike_timing.gap(event),false,.82 if strike_timing.count(style)>1 else 1.)
		return cues
	if kind=="shield_block" and event.get("guard_style","")=="defense" and style in strike_timing.SWORDS:
		if stage=="travel":_append(cues,strike_bank[style].flight,maxf(0,float(event.travel_ms)/1000.0-strike_timing.flight_lead(style)),false)
		elif stage=="impact":_append(cues,support_bank.defense_block,0.,false)
		return cues
	# Share the established sword sound family with the new printed blade.
	if key == "final_strike": key = "triple_strike"
	if style == "final_strike": style = "triple_strike"
	if kind == "blade_volley":
		var timing=preload("res://scripts/blade_volley_timing.gd")
		for i in range(event.destinations.size()):
			var launch:int=i*timing.STEP_MS+timing.MORPH_MS
			if launch>=event.timeline_ms and launch<event.timeline_ms+event.slice_ms:
				_append(cues,cards.strike.travel,(launch-event.timeline_ms)/1000.0)
		if not event.hits.is_empty():_append(cues,cards.strike.impact)
		return cues
	# These are effect sounds, not card-intro sounds. Preserve their natural
	# decay across the next animation stage, and let sync_view deduplicate them.
	if kind=="card_effect" and style=="search" and stage=="travel":
		_append(cues,support.search.depart if event.get("op","")=="search_depart" else support.search.travel,0.0,false,2.0)
	if kind=="draw_cards" and stage=="travel":
		for d in event.draws:
			if d.get("source_key","")!="search":continue
			for start in d.starts:
				if start>=0:_append(cues,support.search.draw,float(start)/1000.0,false,2.0)
	# The sieve changes duration with actual rejected-card count. Public slots
	# keep both viewers in sync without exposing the other hand's identities.
	if kind=="card_effect" and style=="gold_panning" and stage=="travel":
		var gold:Dictionary=support.get("gold_panning",{})
		var op:String=event.get("op","")
		if op=="gold_begin":
			_append(cues,gold.get("prepare",""),0.0,false,2.0)
		elif op=="gold_filter":
			var count:int=event.get("hand_motion",{}).get("slots",[]).size()
			_append(cues,gold.get("filter_%d"%count,gold.get("filter","")),0.0,false,2.0)
			for i in range(count):
				var departure:float=(.12+i*.04)*float(event.get("travel_ms",1550))/1000.0
				_append(cues,gold.get("discard",""),departure,false,2.0/sqrt(float(count)))
	if kind=="card_effect" and style=="bloodletting" and event.get("op","")=="lose_hp":
		var blood:Dictionary=support.bloodletting
		if stage=="travel":_append(cues,blood.knife,0.,false,2.)
		elif stage=="impact":
			_append(cues,blood.flourish,.8,false,2.)
			_append(cues,blood.open,1.56,false,2.)
	if kind=="draw_cards" and stage=="travel":
		var last=-1.0
		var blood_cards=false
		for d in event.draws:
			if d.get("source_key","")!="bloodletting":continue
			for i in range(d.count):
				if d.starts[i]<0 or d.returned[i]:continue
				blood_cards=true
				_append(cues,support.bloodletting["deal_%d"%(i%3)],d.starts[i]/1000.0+.07,false,2.)
				last=maxf(last,(d.starts[i]+d.durations[i])/1000.0)
			# Overflow speech can hold the lid open beyond the last accepted card.
			if d.returned.has(true):last=maxf(last,d.speech_start/1000.0+.45)
		if blood_cards:_append(cues,support.bloodletting.close,last+.015,false,2.)
	if kind=="card_effect" and style=="gift" and event.get("op","")=="gift_transfer":
		var gift=support.gift
		if stage=="travel":
			_append(cues,gift.unfold,0.,false,2.)
			for i in range(event.card_count):_append(cues,gift["pack_%d"%(i%2)],.69+i*.44,false,2.)
			_append(cues,gift.close,2.55,false,2.)
		else:
			_append(cues,gift.carry,.03,false,2.)
			_append(cues,gift.open,1.40,false,2.)
	if kind=="draw_cards" and stage=="travel":
		var ordinal=0
		for draw in event.draws:
			if draw.get("source_key","")!="gift":continue
			for i in range(draw.count):
				if draw.starts[i]<0 or draw.returned[i]:continue
				_append(cues,support.gift["unpack_%d"%(ordinal%2)],draw.starts[i]/1000.0,false,2.)
				ordinal+=1
	if kind=="card_effect" and style=="anticipation":
		var sounds:Dictionary=support.get("anticipation",{})
		if stage=="travel":_append(cues,sounds.get("observe",""),0.,false,2.)
		elif stage=="impact" and event.get("succeeded",false):_append(cues,sounds.get("seal",""),0.,false,2.)
	if kind=="card_effect" and style=="warcry" and event.get("op","")=="warcry":
		var sounds:Dictionary=support.get("warcry",{})
		if stage=="travel":_append(cues,sounds.get("travel",""),0.,false,2.)
		elif stage=="impact":_append(cues,sounds.get("impact",""),0.,false,2.)
	# Approved paper/bookmark foley starts only after both priority choices.
	if kind=="card_effect" and style=="ignore" and event.get("op","")=="chosen":
		var sounds:Dictionary=support.get("ignore",{})
		if stage=="travel":_append(cues,sounds.get("travel",""),0.,false,2.)
		elif stage=="impact":_append(cues,sounds.get("impact",""),0.,false,2.)
	# Four real page turns follow the unchanged book animation after selection.
	if kind=="card_effect" and style=="prophecy" and event.get("op","")=="chosen" and stage=="travel":
		_append(cues,support.get("prophecy",{}).get("travel",""),0.,false,2.)
	# The moving bell is damped as its visible sound waves contract.
	if kind=="card_effect" and style=="silence" and event.get("op","")=="silence":
		var sounds:Dictionary=support.get("silence",{})
		if stage=="travel":_append(cues,sounds.get("travel",""),0.,false,2.)
		elif stage=="impact":_append(cues,sounds.get("impact",""),0.,false,2.)
	# Lens lift and sweep; no sound implies any particular hidden card.
	if kind=="card_effect" and style=="peek" and event.get("op","")=="peek":
		var sounds:Dictionary=support.get("peek",{})
		if stage=="travel":_append(cues,sounds.get("travel",""),0.,false,2.)
		elif stage=="impact":_append(cues,sounds.get("impact",""),0.,false,2.)
	if kind=="draw_cards" and stage=="travel":
		for d in event.draws:
			if not d.get("emblem_direct",false):continue
			var sounds:Dictionary=support.get(d.source_key,{})
			for i in range(d.count):
				if d.starts[i]<0 or d.returned[i]:continue
				var variant=str(int(d.get("prop_index",0))%2)
				_append(cues,sounds.get("flight_"+variant,sounds.get("flight","")),d.starts[i]/1000.0,false,2.)
				_append(cues,sounds.get("land_"+variant,sounds.get("land","")),(d.starts[i]+d.durations[i])/1000.0,false,2.)
	if kind == "card_effect":
		if style in ["suppress","late_suppress"] and event.get("op","")=="chosen":
			if stage=="travel":_append(cues,support.get(style,{}).get("travel",""),0.,false,2.)
		elif style == "reverse" and event.get("op","") == "reverse":
			if stage == "travel":
				_append(cues,support.get("reverse",{}).get("travel",""),preload("res://scripts/reverse_timing.gd").ROTATE_START)
			elif stage == "impact" and not event.get("cloth_was_active",false):
				_append(cues,support.get("reverse",{}).get("impact",""))
		elif style == "collect" and event.get("op","") == "collect_launch" and stage == "travel":
			var chest:Dictionary=support.get("collect",{})
			var seconds:float=float(event.get("travel_ms",1700))/1000.0
			var mode:String=event.get("draw_mode","ready")
			_append(cues,chest.get("mechanism",""),seconds*.43,false,2.)
			if mode=="ready":_append(cues,chest.get("open",""),seconds*.78,false,2.)
			elif mode!="blocked":_append(cues,chest.get("peek",""),seconds*.65,false,2.)
		elif style == "gambler" and event.get("op","") == "discard_all" and stage == "travel":
			var roll_start: float = preload("res://scripts/gambler_dice.gd").RISE_END
			_append(cues,support.get("gambler",{}).get("travel",""),float(event.get("travel_ms",2200))*roll_start/1000.0)
		elif stage == "impact" and style == "prophecy" and event.get("op","") == "chosen":
			_append(cues,support.get("prophecy",{}).get("impact",""))
		elif style == "mirror" and stage == "impact":
			_append(cues,support.get("mirror",{}).get("impact",""))
		elif style == "immortal" and event.get("revived",false):
			if stage == "travel": _append(cues,support.get(style,{}).get("travel",""),0,true)
			elif stage == "impact": _append(cues,support.get(style,{}).get("impact",""))
	if kind == "reverse_restore" and stage == "travel":
		_append(cues,support.get("reverse",{}).get("restore",""))
	# The angel form has a short still interval before the body leaves its base.
	if kind == "divinity_awaken" and stage == "travel":
		_append(cues,support.get("divinity",{}).get("travel",""),preload("res://scripts/divinity_pose.gd").LIFT_START)
	# Approved physical amulet: silent lift/return, audible charge and beam,
	# contact ignition, then paper foley only when the rules actually discard it.
	# Separate overlapping stems keep natural releases through stage rebuilds.
	if kind == "shield_block" and event.has("cancelled_style") and style in AMULETS:
		var delay: float = AmuletTiming.CHARGE_SOUND if stage == "travel" else AmuletTiming.DISCARD_SOUND if stage == "discard" else 0.0
		_append(cues,support.get(style,{}).get(stage,""),delay,false,AmuletTiming.SOUND_GAIN)
	if kind == "card_start" and stage == "travel" and support.has(key):
		_append(cues,support[key].rise,0,true)
	elif kind in ["heal","shield"] and support.has(style):
		if stage == "travel":
			_append(cues,support[style].travel,0,true)
		elif stage == "impact":
			var targets: Array = event.get("targets",[])
			# One sound per simultaneous heal, not one per ally. Full health,
			# corpses and Blessing must not announce a successful recovery.
			if (kind == "shield" and not targets.is_empty()) or targets.any(func(t): return int(t.get("after",0)) > int(t.get("before",0)) and not t.get("heal_blocked",false)):
				_append(cues,support[style].impact)
	elif kind == "card_start" and stage == "travel" and cards.has(key):
		_append(cues,cards[key].rise,0,true)
	elif kind in ["strike","shield_block"] and cards.has(style):
		if stage == "travel":
			_append(cues,cards[style].travel,0,true)
		elif stage == "impact":
			# A missed Judgment has no damaging contact. Blocks still have a
			# weapon/shield contact; no deaths or rewards are predicted here.
			var targets: Array = event.get("targets",[])
			if not targets.is_empty() and not targets.all(func(t): return t.get("miss",false)):
				_append(cues,cards[style].impact)
	elif style == "death" and stage == "travel" and cards.has(event.get("source_key","")):
		_append(cues,cards[event.source_key].death,.06)
	elif kind == "draw_cards" and stage == "travel":
		for draw in event.get("draws",[]):
			for i in range(int(draw.get("count",0))):
				if draw.get("returned",[]).size()>i and draw.returned[i]:continue
				var at := float(draw.starts[i])/1000.0 if draw.has("starts") else (float(draw.get("start_ms",0))+i*float(draw.get("step_ms",400)))/1000.0
				var flight := float(draw.durations[i])/1000.0 if draw.has("durations") else float(draw.get("flight_ms",1650))/1000.0
				if not draw.get("emblem_direct",false):_movement_cue(cues,"place",at+flight)
				if draw.get("source_key","") == "bounty":
					_append(cues,bank.rewards.bounty_depart,at)
					_append(cues,bank.rewards.bounty_arrive,at+flight)
	elif kind == "hand_transfer" and stage == "travel" and event.get("accepted",false):
		# Use the flight's local clock, not the arrival of the next server state.
		_movement_cue(cues,"place",float(event.travel_ms)/1000.0)
	elif kind == "hand_place" and stage == "travel" and int(event.get("card_count",0)) > 0:
		_movement_cue(cues,"place")
	elif kind == "pawn_speech" and stage == "travel" and int(event.get("placed_count",0)) > 0:
		_movement_cue(cues,"place")
	# This tag is emitted only when a player actually consumes Defense. Amulets
	# and Blessing have their own effects and must not borrow its sound.
	if kind == "shield_block" and stage == "impact" and event.get("guard_style","") == "defense":
		_append(cues,support_bank.defense_block)
	return cues

func _append(cues: Array, file: String, delay: float = 0, cut_with_stage: bool = false, gain: float = 1.0) -> void:
	if not file.is_empty(): cues.append({"file":file,"delay":delay,"cut_with_stage":cut_with_stage,"gain":gain})

func _movement_cue(cues: Array, action: String, delay: float = 0) -> void:
	var file: String = support_bank.get("card_movement",{}).get(action,"")
	if not file.is_empty():
		cues.append({"file":file,"delay":delay,"cut_with_stage":false,"category":"card_movement"})

func plan_changed(actor: int, before: Array, after: Array, started: int) -> void:
	# Local choices are private. Rebuilt widgets share this clock; an interrupted
	# flight replaces its own cue instead of sounding at the abandoned endpoint.
	var due: int = started + preload("res://scripts/planning_flight.gd").DURATION_MS
	for item in planning_pending.values():
		if item.actor == actor: item.due = due
	for card in before + after:
		if before.has(card) == after.has(card): continue
		var cues: Array = []
		_movement_cue(cues,"play" if after.has(card) else "place")
		if not cues.is_empty():
			planning_pending["%d/%d" % [actor,card]] = {"actor":actor,"due":due,"cue":cues[0]}

func sync_view(view: Dictionary, started: int) -> void:
	if view.is_empty():
		reset()
		return
	var next_match := str(view.get("match",-1))
	if next_match != match_key:
		reset()
		match_key = next_match
	if view.get("phase","") != "planning": planning_pending.clear()
	var event: Dictionary = view.get("animation",{})
	var key := "%s/%s" % [event.get("id",-1),event.get("stage","")]
	if key == event_key: return
	var transfer_landing: bool = event.get("kind","") == "hand_transfer" and event.get("stage","") == "impact" and event.get("accepted",false)
	var travel_key := "%s/travel" % event.get("id",-1)
	var missed_transfer: bool = transfer_landing and not seen.has(travel_key)
	if transfer_landing and event_key == travel_key:
		# A state change can arrive before this frame's audio update. The impact
		# view puts the card at its destination now; finish its pending contact
		# once instead of losing it when replacing the travel queue.
		var elapsed := maxf(0,(Time.get_ticks_msec()-stage_started)/1000.0)
		for cue in pending:
			if cue.get("category","") == "card_movement":
				_play(cue,maxf(0,elapsed-float(cue.delay)))
	if event.get("kind","")=="strike" and event.get("stage","")=="impact" and event.get("style","") in preload("res://scripts/strike_timing.gd").SWORDS and event_key==travel_key:
		var elapsed=maxf(float(event.get("travel_ms",0))/1000.0,(Time.get_ticks_msec()-stage_started)/1000.0)
		for cue in pending:_play(cue,maxf(0,elapsed-float(cue.delay)))
	event_key = key
	pending.clear()
	for player in voices:
		if player.get_meta("cut_with_stage",false): player.stop()
	if event.is_empty() or seen.has(key): return
	seen[key] = true
	# Bounded memory for long matches; serial event IDs only move forward.
	if seen.size() > 512: seen.erase(seen.keys()[0])
	stage_started = started
	pending = cues_for(view)
	# A client first joining at the impact still gets the visible contact.
	if missed_transfer: _movement_cue(pending,"place")
	_process(0)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	for key in planning_pending.keys():
		var item: Dictionary = planning_pending[key]
		if now < int(item.due): continue
		planning_pending.erase(key)
		_play(item.cue,(now-int(item.due))/1000.0)
	if pending.is_empty(): return
	var elapsed := maxf(0,(Time.get_ticks_msec()-stage_started)/1000.0)
	for i in range(pending.size()-1,-1,-1):
		var cue: Dictionary = pending[i]
		if elapsed < float(cue.delay): continue
		pending.remove_at(i)
		_play(cue,elapsed-float(cue.delay))

func _play(cue: Dictionary, offset: float) -> void:
	var path: String = cue.file
	if not streams.has(path): streams[path] = load(path) as AudioStream
	var stream: AudioStream = streams[path]
	if stream == null or offset >= stream.get_length(): return
	var available: Array[AudioStreamPlayer] = voices.filter(func(p): return not p.playing)
	var player: AudioStreamPlayer = available[0] if not available.is_empty() else voices[0]
	player.stop()
	player.stream = stream
	player.set_meta("cut_with_stage",cue.cut_with_stage)
	player.set_meta("gain",float(cue.get("gain",1.0)))
	player.volume_db = linear_to_db(level*float(cue.get("gain",1.0))) if level > 0 else -80.0
	player.play(offset)
	cue_played.emit(path,offset)

func _apply_volume() -> void:
	for player in voices: player.volume_db = linear_to_db(level*float(player.get_meta("gain",1.0))) if level > 0 else -80.0

func set_level(value: float) -> void:
	level = clampf(value,0,1)
	_apply_volume()
	var config := ConfigFile.new()
	config.set_value("sound","volume",level)
	config.save(settings_path)
