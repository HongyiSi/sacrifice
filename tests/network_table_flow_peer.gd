extends "res://tests/network_v0203_peer.gd"
const MATCH_ID=208000
var observed:={}
var done:=false
var request_stamp:=""

func _run()->void:
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
	main.music.level=0;main.music._apply_volume();main.attack_audio.level=0;main.attack_audio._apply_volume()
	main.session.changed.connect(_changed)
	main.session.problem.connect(func(message):errors.append(message))
	began=Time.get_ticks_msec()
	if role=="host":main.session.host_room("界面房主",25228)
	else:main.session.join_room("界面访客","127.0.0.1",25228)

func _setup()->void:
	# Observe a real connection's game-start and initial planning announcements.
	await create_timer(6).timeout
	var g=H.fixture(8);g.match_id=MATCH_ID
	g.presentation_enabled=true;g.stage_presentation_enabled=true;g.resolution_presentation_enabled=true
	for actor in [0,3]:H.give(g,actor,"defense")
	main.session.game=g;main.session._broadcast()

func _changed()->void:
	var s:Dictionary=main.session.state
	if s.is_empty() or done:return
	if role=="host" and not prepared:prepared=true;_setup.call_deferred()
	if s.match==MATCH_ID and not running:running=true;_exercise.call_deferred()

func _exercise()->void:
	await frames()
	var s:Dictionary=main.session.state
	var card:int=s.characters[main.session.team*3].hand[0]
	meta(main,"card_id",card).pressed.emit();await create_timer(.4).timeout
	var staged=meta(main,"staged_card_id",card)
	check(staged!=null and not staged.hidden_card and staged.self_modulate==Color.WHITE,"network owner stages a bright face")
	check(main.session.state.queue.is_empty() and main.session.state.characters[(1-main.session.team)*3].hand.is_empty(),"local planning stays private")
	meta(main,"planning_lock_button",true).pressed.emit()

func _process(_delta:float)->bool:
	if began and Time.get_ticks_msec()-began>60000:push_error("NETWORK_TABLE_FLOW_TIMEOUT");quit(2)
	if main==null or done or main.session.state.is_empty():return false
	var s:Dictionary=main.session.state
	var event:Dictionary=s.animation
	if event.get("kind","")=="phase_change" and event.get("announce",false):
		var cue=meta(main,"center_phase_title",event.turn_stage)
		if cue!=null and cue.age>.15 and cue.age<1.1:
			observed[event.turn_stage]=cue.tint==meta(main,"phase_title",true).get_theme_color("font_color")
	if s.match!=MATCH_ID:return false
	var mine:int=main.session.team
	for a in s.queue:
		var own:bool=a.actor/3==mine
		if event.get("kind","")=="phase_change" and event.get("turn_stage","")=="resolution":
			if own:
				var flip=meta(main,"card_conceal_action",a.id)
				if flip!=null and not flip.initial_hidden and not flip.final_hidden and flip.final_tint==flip.UNREVEALED_TINT:observed.conceal=true
			var card=meta(main,"played_action_id",a.id)
			if card!=null and card.visible:
				if own and not card.hidden_card and card.self_modulate==preload("res://scripts/card_reveal.gd").UNREVEALED_TINT:observed.own_dim=true
				if not own and card.hidden_card:observed.enemy_back=true
			if not own and a.card!=0:errors.append("unrevealed opponent card leaked")
		if event.get("kind","")=="card_reveal":
			var flip=meta(main,"card_reveal_action",a.id)
			if flip!=null and flip.initial_hidden==not own and not flip.final_hidden:observed["own_reveal" if own else "enemy_reveal"]=true
	if s.phase=="review":
		observed.empty_death_skipped=not observed.get("death",false)
		done=true;_finish.call_deferred()
	if s.phase=="targeting" and s.input.get("team",-1)==mine:
		var stamp:="%s/%s"%[s.match,s.revision]
		if stamp!=request_stamp:
			request_stamp=stamp;main.session.act("target",[s.active_action.actor])
	return false

func _finish()->void:
	for flag in ["start","planning","resolution","empty_death_skipped","conceal","own_dim","enemy_back","own_reveal","enemy_reveal"]:
		check(observed.get(flag,false),"both peers render "+flag)
	var ok:bool=failures==0 and errors.is_empty()
	var f:=FileAccess.open("res://test-results/network-table-flow-"+role+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"ok":ok,"checks":checks,"observed":observed,"errors":errors},"\t"));f.close()
	print("NETWORK_TABLE_FLOW_RESULT role=%s checks=%d ok=%s"%[role,checks,ok])
	await create_timer(2).timeout
	main.session.leave();main.queue_free();await frames();quit(0 if ok else 1)
