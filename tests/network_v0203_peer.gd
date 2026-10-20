extends SceneTree
const H=preload("res://tests/helpers.gd")
var main
var role:="host"
var prepared:=false
var running:=false
var checks:=0
var failures:=0
var errors:Array=[]
var began:=0

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("NETWORK_V0203_FAIL "+label)

func meta(node:Node,key:String,value):
	if node.has_meta(key) and node.get_meta(key)==value:return node
	for child in node.get_children():
		var found=meta(child,key,value)
		if found!=null:return found
	return null

func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):role=arg.trim_prefix("--role=")
	_run.call_deferred()

func _run()->void:
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
	main.music.set_level(0);main.attack_audio.level=0
	main.session.changed.connect(_changed)
	main.session.problem.connect(func(message):errors.append(message))
	began=Time.get_ticks_msec()
	if role=="host":main.session.host_room("点击房主",25203)
	else:main.session.join_room("点击访客","127.0.0.1",25203)

func _setup()->void:
	var g=H.fixture(8);g.match_id=203000
	for actor in [0,3]:
		for key in ["strike","heal","defense"]:H.give(g,actor,key)
	main.session.game=g;main.session._broadcast()

func _changed()->void:
	var s:Dictionary=main.session.state
	if s.is_empty():return
	if role=="host" and not prepared:
		prepared=true;_setup.call_deferred();return
	if s.match==203000 and not running:
		running=true;_exercise.call_deferred()

func frames()->void:
	for _i in range(3):await process_frame

func _exercise()->void:
	await frames()
	var before:Dictionary=main.session.state.duplicate(true)
	var actor:int=main.session.team*3
	var ids:Array=before.characters[actor].hand
	meta(main,"card_id",ids[0]).pressed.emit();await frames()
	check(meta(main,"planning_flight_card",ids[0])!=null,"local play flight exists")
	await create_timer(.4).timeout
	meta(main,"card_id",ids[1]).pressed.emit();await frames()
	check(main._selected_cards(actor)==[ids[1]],"replacement selects only new card")
	check(meta(main,"planning_flight_card",ids[0])!=null and meta(main,"planning_flight_card",ids[1])!=null,"replace animates both directions locally")
	await create_timer(.4).timeout
	meta(main,"staged_card_id",ids[1]).pressed.emit();await frames()
	check(main._selected_cards(actor).is_empty() and meta(main,"planning_flight_card",ids[1])!=null,"local withdrawal flies back")
	await create_timer(.4).timeout
	meta(main,"card_id",ids[2]).pressed.emit();await frames()
	await create_timer(.4).timeout
	check(main.session.state==before,"no server snapshot or revision changes from local edits")
	check(main.session.state.ready==[false,false] and main.session.state.queue.is_empty(),"opponent receives no staged selections")
	check(main.board._plan_widgets(main.board.canvas,3-actor).is_empty(),"no opponent planning flight is displayed")
	check(main.session.state.characters[3-actor].hand.is_empty(),"opponent card identities remain private")
	if role=="host":check(main.session.game.plans==[null,null],"host game receives no plan before lock")
	var ok:bool=failures==0 and errors.is_empty()
	var result:Dictionary={"role":role,"ok":ok,"checks":checks,"failures":failures,"errors":errors}
	var file=FileAccess.open("res://test-results/network-v0203-"+role+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result));file.close()
	print("NETWORK_V0203_RESULT role=%s checks=%d ok=%s"%[role,checks,ok])
	# Keep both peers connected until both complete their local observations.
	await create_timer(2).timeout
	main.session.leave();main.queue_free();await frames();quit(0 if ok else 1)

func _process(_delta:float)->bool:
	if began and Time.get_ticks_msec()-began>20000:push_error("NETWORK_V0203_TIMEOUT");quit(2)
	return false
