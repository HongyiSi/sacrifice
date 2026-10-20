extends SceneTree
const G=preload("res://tests/gambler_scenarios.gd")
const A=preload("res://tests/amulet_scenarios.gd")
const Session=preload("res://scripts/session.gd")
const H=preload("res://tests/helpers.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("V0192_FAIL "+label)
func _initialize()->void:_run.call_deferred()
func hold_boundary(g)->void:
	var client=Session.new();root.add_child(client);client.set_process(false)
	var before:Dictionary=g.snapshot(1)
	var ms:int=H.Rules.StrikeStyles.duration(before.animation)
	client._receive_view(before)
	g.advance_animation();var after:Dictionary=g.snapshot(1)
	client._receive_view(after)
	client.received_animation_started=Time.get_ticks_msec()-ms+100
	client._drain_received_views()
	check(client.state.animation==before.animation,"queued result waits for full extended duration")
	client.received_animation_started=Time.get_ticks_msec()-ms-1;client._drain_received_views()
	check(client.state.revision==after.revision,"next snapshot appears at the extended boundary")
	client.leave();client.queue_free()
func _run()->void:
	for actor in [0,3]:
		for retained in [false,true]:
			for empty in [false,true]:
				var g=G.setup(actor,19200+checks,retained,empty)
				check(G.seek(g),"gambler reaches dice event")
				var old:Array=g.characters[actor].hand.duplicate()
				var keep:Array=old.filter(func(id):return not g._can_discard_hand_card(g.characters[actor],id))
				check(g.animation.travel_ms==2200,"approved dice duration")
				check(g.animation.card_count==(0 if empty else 3),"discard count excludes every retained card")
				check(g.snapshot(0).animation==g.snapshot(1).animation,"dice metadata is public and identical")
				check(g.snapshot(1-actor/3).characters[actor].hand.is_empty(),"opponent hand remains private")
				hold_boundary(g)
				check(g.characters[actor].hand==keep,"discard happens only after die settles")
				check(g.animation.stage=="impact","discard has its own outcome stage")
				check(G.drain(g),"gambler completes")
				check(g.characters[actor].hand.size()==8 and keep.all(func(id):return g.characters[actor].hand.has(id)),"draw fills to limit while retaining locked cards")
	for key in A.Burn.KEYS:
		var g=A.setup(key,0,19300+checks);check(A.seek(g),"amulet event")
		check(g.animation.travel_ms==2100,"approved lift, charge and beam duration")
		check(g.animation.impact_ms==2880,"approved burn and return duration")
		check(not g.animation.has("amulet_duration_scale"),"native timing never receives legacy scaling")
		var left:Dictionary=g.snapshot(0).animation;var right:Dictionary=g.snapshot(1).animation
		left.erase("owner_slot");right.erase("owner_slot")
		check(left==right,"shared amulet timing; sorted hand slot remains private")
		hold_boundary(g);hold_boundary(g)
		check(A.drain(g) and g.characters.all(func(c):return c.hp==8),"slow cancel preserves game outcome")
	print("V0192_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
