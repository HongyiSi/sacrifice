extends SceneTree
const H = preload("res://tests/helpers.gd")
const Cases = preload("res://tests/v011_scenarios.gd")
const Music = preload("res://scripts/music.gd")
var checks := 0
var failures := 0
var played: Array = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1;push_error("ARRIVAL_ENDGAME_FAIL "+label)
func _initialize() -> void: _run.call_deferred()
func incoming(g) -> void:
	var pending: Dictionary = g._pending_hand_arrivals()
	for viewer in [0,1]:
		var snap: Dictionary = g.snapshot(viewer)
		for target in pending:
			var accepted: Array = g.characters[target].hand.filter(func(id):return pending[target].has(id))
			check(snap.characters[target].hand_count==g.characters[target].hand.size()-accepted.size(),"pending gain keeps preceding hand count")
			check(accepted.all(func(id):return not snap.characters[target].hand.has(id)),"no premature hand card on either viewer")
			if target/3!=viewer:check(snap.characters[target].hand.is_empty(),"opponent identities remain hidden")
func _run() -> void:
	var covered: Dictionary = {}
	for key in ["gift","poisoning","obstruct","search","sapphire","ruby","amethyst","topaz","emerald","amber","curse","heart","legacy"]:
		var g = Cases.setup(key,key in ["curse","heart","legacy"],true)
		for i in range(350):
			if g.animation.is_empty() and g.phase in ["review","planning","ended"]:break
			incoming(g)
			if g.animation.get("kind","") in ["draw_cards","hand_transfer"]:
				covered[key]=true
				# The active flight has the actual cards so its renderer can own
				# their visibility until local arrival, without altering rules.
				if g.animation.kind=="draw_cards":
					for d in g.animation.draws:
						var s: Dictionary = g.snapshot(d.target/3)
						for id in d.ids:
							if id!=0:check(s.characters[d.target].hand.has(id),"active flight receives actual card data")
			check(Cases.step(g).is_empty(),"resolution advances "+key)
		check(g.animation.is_empty(),"transfer resolves completely "+key)
	check(covered.size()==13,"all placement families covered")
	# Fully rejected and partially accepted generations must never invent cards.
	for slots in [0,1,2]:
		var g=H.fixture();g.presentation_enabled=true;g.phase="resolution"
		var id:int=H.give(g,0,"obstruct");var a:Dictionary=g._add_action(0,id);a.status="active"
		for i in range(8-slots):g.characters[3].hand.append(g.deck.pop_back())
		g._push([g._job("obstruct",a,{"target":3})]);g._pump();g.advance_animation()
		incoming(g)
		check(g.snapshot(1).characters[3].hand_count==8-slots,"capacity preserved before generation flight")
		check(g.characters[3].hand.size()==8,"authoritative hand already settled")
	# A queued whole-card move also stays absent during its parent's impact.
	var g=H.fixture();g.presentation_enabled=true
	var id:int=H.give(g,0,"ruby");g.characters[0].hand.erase(id)
	var a:Dictionary=g._add_action(0,id);a.status="active"
	g._transfer_gem(a,3);incoming(g)
	check(g.snapshot(1).characters[3].hand_count==0 and g.characters[3].hand==[id],"queued whole card has no early appearance")
	var music=Music.new();root.add_child(music)
	music.settings_path="res://test-results/arrival-endgame-music.cfg";music.level=.5
	music.result_played.connect(func(kind):played.append(kind))
	for viewer in [0,1]:
		for winner in [0,1]:
			music.sync_view({"match":500+viewer*2+winner,"phase":"planning","winner":-1},viewer)
			await create_timer(.75).timeout
			check(music.player.playing,"battle music before result")
			var view:Dictionary={"match":500+viewer*2+winner,"phase":"animating","winner":winner}
			var count:int=played.size();music.sync_view(view,viewer)
			check(played.size()==count,"winning effect finishes before result music")
			view.phase="ended";music.sync_view(view,viewer)
			var outcome:String="victory" if viewer==winner else "defeat"
			check(played[-1]==outcome and music.result_player.stream==music.result_streams[outcome],"viewer-specific result track")
			check(not music.player.playing and music.result_player.playing,"result replaces background music immediately")
			check(music.result_player.stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"result does not loop")
			music.sync_view(view,viewer);view.confirmed=[true,false];music.sync_view(view,viewer)
			check(played.size()==count+1,"redraw and rematch confirmation never replay result")
			music.set_level(0);check(music.result_player.volume_db<=-79,"result follows music mute")
			music.set_level(.5);check(is_equal_approx(music.result_player.volume_db,linear_to_db(.5)),"result follows music volume")
	# Completion stays quiet, then a rematch starts the battle track normally.
	await create_timer(music.result_player.stream.get_length()+.4).timeout
	check(not music.result_player.playing and not music.player.playing,"result finishes once without battle music resuming")
	var count:int=played.size();music.sync_view({"match":800,"phase":"ended","winner":-1},0)
	check(played.size()==count and not music.result_player.playing,"draw plays neither winner nor loser track")
	music.sync_view({},0);await create_timer(.75).timeout
	check(music.context==0 and music.player.playing,"leaving restores lobby music")
	music.sync_view({"match":801,"phase":"planning","winner":-1},0);await create_timer(.75).timeout
	check(music.context==1 and music.player.playing,"new match restores battle music")
	check(is_equal_approx(music.result_streams.victory.get_length(),3.54224489795918),"full original victory clip")
	check(is_equal_approx(music.result_streams.defeat.get_length(),4.00179138321995),"full original defeat clip")
	music.queue_free()
	print("ARRIVAL_ENDGAME_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
