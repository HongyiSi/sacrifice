extends SceneTree
const Store = preload("res://scripts/ai_checkpoint.gd")
const Rules = preload("res://scripts/rules.gd")
const Session = preload("res://scripts/session.gd")
const Policy = preload("res://scripts/ai_policy.gd")
const Actions = preload("res://scripts/match_actions.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var store := Store.new(); store.path="res://test-results/ai-checkpoint-test"; store.clear()
	var game := Rules.new(); game.presentation_enabled=true; game.start(20261019)
	var details := {"name":"恢复测试","names":["恢复测试","本地 AI"],"ai_seed":123,"ai_state":456,"learned":false}
	check(store.write(game,details,10000),"initial durable write")
	check(not store.read(11799).is_empty(),"resume just before 30 minutes")
	check(store.read(11800).is_empty(),"expire at exactly 30 minutes")
	check(not FileAccess.file_exists(store.path+"-0.json") and not FileAccess.file_exists(store.path+"-1.json"),"expiry deletes both saved slots")
	store.write(game,details,10000)
	var envelope = JSON.parse_string(store.cached); envelope.saved_at=10000
	envelope.payload="AA=="
	check(store.decode(JSON.stringify(envelope),10001).is_empty(),"corruption rejected")
	envelope=JSON.parse_string(store.cached); envelope.saved_at=10000; envelope.rules="different"
	check(store.decode(JSON.stringify(envelope),10001).is_empty(),"incompatible rules rejected")
	store.clear()
	var failing := Store.new(); failing.path="res://test-results/no-checkpoint-parent-"+str(Time.get_ticks_usec())+"/save"
	check(not failing.write(game,details,12000),"unavailable storage reports failure")
	check(failing.last_attempt==12000 and failing.last_saved==0,"failed write still delays the next heartbeat attempt")
	var frames := 0; var decisions := 0
	for seed_value in [13,47,20261019]:
		game=Rules.new(); game.presentation_enabled=true; game.start(seed_value)
		var bot := Policy.new(seed_value)
		for step in range(8000):
			var data := store.capture(game,details); data.saved_at=10000
			var saved := store.decode(JSON.stringify(data),10001)
			check(not saved.is_empty(),"decode seed %d step %d"%[seed_value,step])
			if saved.is_empty(): break
			var recovered = saved.game
			check(store.capture(recovered,details).sha256==data.sha256,"exact state and shared references survive serialization")
			if not game.animation.is_empty():
				game.advance_animation(); recovered.advance_animation(); frames += 1
			elif game.phase=="review": game.advance_round(); recovered.advance_round()
			elif game.phase=="ended": break
			else:
				var team := int(game.request.get("team",0))
				if game.phase=="planning": team=0 if game.plans[0]==null else 1
				var snapshot: Dictionary = game.snapshot(team)
				var action := bot.decide(snapshot,team)
				check(not action.is_empty(),"test bot finds action")
				if action.is_empty(): break
				var error := Actions.apply(game,team,action.kind,action.payload,snapshot.match,snapshot.round,snapshot.revision)
				var again := Actions.apply(recovered,team,action.kind,action.payload,snapshot.match,snapshot.round,snapshot.revision)
				check(error.is_empty() and again.is_empty(),"resumed action accepted")
				decisions += 1
			check(store.capture(game,details).sha256==store.capture(recovered,details).sha256,"next animation/action produces identical authoritative state")
		check(game.phase=="ended","resumable full match finishes")
	var session := Session.new(); session.ai_checkpoint.path=store.path
	root.add_child(session); session.set_process(false)
	for learned in [false,true]:
		session.start_ai("检查",415,learned)
		session.remember_ai_plan([[1],[],[]])
		var original: String = store.capture(session.game,{}).sha256
		# Discard the entire session as a browser crash does, without leave().
		session.free()
		session=Session.new(); session.ai_checkpoint.path=store.path
		root.add_child(session); session.set_process(false)
		check(session.resume_ai(),"new session restores without server")
		check(store.capture(session.game,{}).sha256==original,"resume did not repeat gameplay")
		check(session.ai_learned==learned and session.ai_local_plan.choices==[[1],[],[]],"AI type and unconfirmed choices restored")
		session.leave()
		check(store.read().is_empty() and session.game==null and session.review_game==null,"intentional leave clears checkpoint and game references")
	session.free(); store.clear()
	print("AI_CHECKPOINT_TEST checks=",checks," failures=",failures," animation_steps=",frames," decisions=",decisions)
	quit(1 if failures else 0)
