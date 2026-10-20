extends "res://tests/v0174_ui_test.gd"
const Transfers=preload("res://tests/hand_transfer_scenarios.gd")
const Layout=preload("res://scripts/board_layout.gd")
func freeze(fx,t:float)->void:
	fx.clock_started=-1;fx.set_process(false);fx.elapsed=t*Styles.duration(fx.event)/1000.0;fx._process(0)
func capture(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/hand-transfer-"+name+".png")
func _run()->void:
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	main.music.set_level(0);main.attack_audio.level=0;main.session.set_process(false)
	for key in Transfers.KEYS:
		for target in range(6):
			var actor:int=0 if target%2==0 else 3
			serial+=1;var g=Transfers.setup(key,actor,target,serial)
			check(g.phase in ["targeting","death_targeting"],"real card reaches target choice "+key)
			var action:Dictionary=g.input_action
			check(g.target(actor/3,target)=="","chosen recipient allowed "+key)
			check(Transfers.seek(g),"transfer follows resolution "+key)
			if g.animation.get("kind","")!="hand_transfer":continue
			var received:int=g.animation.incoming_card
			check(g.characters[target].hand.count(received)==1,"one physical card enters hand")
			check(not g.discard.has(received) and not g.death_discard.has(received),"transferred card is not discarded")
			var e:Dictionary=g.animation.duplicate(true)
			for viewer in [0,1]:
				var own:bool=target/3==viewer
				var state:Dictionary=g.snapshot(viewer)
				check(state.animation.has("incoming_card")==own and state.animation.has("owner_slot")==own,"private sorted slot stays with recipient")
				check(state.characters.filter(func(c):return c.team!=viewer).all(func(c):return c.hand.is_empty()),"other hands stay private")
				await show_game(g,viewer)
				var fx=meta(main,"hand_transfer_animation",e.id)
				check(fx!=null,"both views render transfer")
				if fx==null:continue
				freeze(fx,0)
				check(not fx.source_card.visible and not fx.source_card.status_label.visible,"settlement card and caption detach together")
				check(fx.incoming!=null and not fx.incoming.visible,"incoming has no duplicate in hand")
				check(not fx.flying.hidden_card,"public resolving face starts visible")
				var start:Vector2=fx.source
				var slot:int=e.owner_slot if own else e.hand_index
				var goal:Vector2=Layout.hand_position(target,slot,own)+Layout.CARD_SIZE*Layout.hand_scale(own)/2
				for t in [0.0,.5,1.0]:
					freeze(fx,t)
					check(Rect2(90,85,1260,840).has_point(fx.flying.position+fx.flying.pivot_offset),"flight stays on table")
					if t==.5:check(fx.flying.position.distance_to(start-fx.flying.pivot_offset)>10,"whole card moves from resolution")
				check((fx.flying.position+fx.flying.pivot_offset).distance_to(goal)<.01,"lands at actual hand slot")
				check(fx.flying.hidden_card==not own,"enemy card turns to back at arrival")
				check(fx.event.before_count+1==3,"visible count changes at landing")
				if key=="ruby" and target==4:
					freeze(fx,.48);await capture("ruby-flight-view-%d"%viewer)
					var saved_start:int=main.effect_started
					main.effect_started=Time.get_ticks_msec()-550
					root.size=Vector2i(960,640);main._schedule_render();await frames()
					fx=meta(main,"hand_transfer_animation",e.id)
					check(fx.elapsed>.45,"resize continues animation clock")
					check(fx.source.distance_to(start)<.01 and fx.destination.distance_to(goal)<.01,"resize preserves board coordinates")
					freeze(fx,.5);await capture("small-view-%d"%viewer)
					root.size=Vector2i(1440,960);main._schedule_render();await frames()
					main.effect_started=saved_start
			g.advance_animation()
			check(g.animation.kind=="hand_transfer" and g.animation.stage=="impact","landing hold precedes next rule job")
			await show_game(g,target/3)
			var landed=meta(main,"hand_transfer_animation",e.id);freeze(landed,.5)
			check(not landed.flying.death and not landed.flying.hidden_card,"received card uses hand appearance")
			g.advance_animation()
			await show_game(g,0)
			check(meta(main,"inspect_key","played_%d_%s_%d"%[actor,str(action.get("death",false)),action.id])==null,"transferred card leaves settlement permanently")
			check(g.characters[target].hand.has(received),"card remains owned after animation")
	# Two real cards resolve consecutively into the same hand.
	var chain=H.fixture(8);chain.match_id=220500;chain.presentation_enabled=true;chain.resolution_presentation_enabled=true
	H.give(chain,4,"strike");H.give(chain,4,"heal")
	H.begin(chain,{0:H.give(chain,0,"ruby"),1:H.give(chain,1,"sapphire")},false)
	var transfers:=0
	var departed:Array=[]
	for _i in range(80):
		if chain.animation.get("kind","")=="hand_transfer" and chain.animation.stage=="travel":
			transfers+=1
			for viewer in [0,1]:
				await show_game(chain,viewer)
				for a in departed:check(meta(main,"inspect_key","played_%d_false_%d"%[a.actor,a.id])==null,"earlier transfer never returns during next card")
				var fx=meta(main,"hand_transfer_animation",chain.animation.id);freeze(fx,1)
				check(fx.event.before_count+1==2+transfers,"consecutive landing increments the same recipient")
			departed.append(chain.animation.action.duplicate())
		if chain.phase in ["review","ended"]:break
		if chain.phase=="targeting":chain.target(chain.request.team,4)
		else:Transfers.S.step(chain)
	check(transfers==2 and chain.characters[4].hand.size()==4,"both transferred cards survive consecutive resolution")
	# Current placement rules discard the incoming card when the hand is full.
	var full=Transfers.setup("ruby",0,4,220501)
	for key in ["collect","defense","warcry","double_strike","triple_strike","quick_strike"]:H.give(full,4,key)
	full.target(0,4);check(Transfers.seek(full),"full-hand transfer still flies")
	check(full.characters[4].hand.size()==8 and full.request.is_empty() and not full.animation.accepted,"full hand rejects incoming without replacing existing cards")
	var rejected:int=full.animation.incoming_card
	check(full.discard.has(rejected),"rejected physical card enters discard once")
	await show_game(full,0)
	var refused=meta(main,"hand_transfer_animation",full.animation.id);freeze(refused,.8)
	check(refused.incoming==null and not refused.source_card.visible,"rejected card leaves settlement without a phantom hand card")
	await capture("full-hand-discard")
	freeze(refused,1)
	check(refused.flying.modulate.a==0 and refused.event.before_count==8,"discard arrival fades and preserves hand count")
	full.advance_animation();full.advance_animation()
	check(full.request.get("type","")!="hand_limit" and full.characters[4].hand.size()==8,"full-hand transfer adds no discard picker")
	# A copied gem creates exactly one new physical card, without moving the source.
	var copy=H.fixture(8);copy.presentation_enabled=true
	var original:int=H.give(copy,0,"sapphire")
	var virtual:Dictionary=copy._add_action(3,original,true);virtual.status="active"
	copy._transfer_gem(virtual,5);copy._pump()
	check(copy.animation.kind=="hand_transfer" and copy.animation.incoming_card!=original,"copied card flies as new instance")
	check(copy.characters[0].hand.has(original) and copy.characters[5].hand.size()==1,"copy leaves original with original owner")
	check(not copy.snapshot(0).animation.has("incoming_card"),"copy instance is not disclosed to other side")
	var skipped=Transfers.setup("ruby",0,1,220502)
	skipped.skip_effect(0)
	check(skipped.visual_queue.is_empty() and skipped.animation.get("kind","")!="hand_transfer","skipped effect creates no transfer")
	print("HAND_TRANSFER_UI_RESULT checks=%d failures=%d"%[checks,failures])
	main.session.leave();main.queue_free();await frames();quit(0 if failures==0 else 1)
