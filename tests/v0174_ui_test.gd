extends SceneTree
const H=preload("res://tests/helpers.gd")
const Launch=preload("res://scripts/signature_strike_launch.gd")
const Rewards=preload("res://scripts/attack_rewards.gd")
const Styles=preload("res://scripts/strike_styles.gd")
var main
var checks:=0
var failures:=0
var serial:=1740
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("V0174_UI_FAIL "+label)
func _initialize()->void:_run.call_deferred()
func frames()->void:
	for _i in range(3):await process_frame
func meta(node:Node,key:String,value):
	if node.has_meta(key) and node.get_meta(key)==value:return node
	for child in node.get_children():
		var found=meta(child,key,value)
		if found!=null:return found
	return null
func finish_fx(g)->void:
	for _i in range(100):
		if g.animation.is_empty():return
		g.advance_animation()
func fixture(key:String,actor:int=0):
	var g=H.fixture(8);serial+=1;g.match_id=serial;g.presentation_enabled=true
	for id in range(6):
		for k in ["strike","heal","defense"]:H.give(g,id,k)
	H.give_death(g,0,"resurrection");H.give_death(g,1,"legacy");H.give_death(g,2,"pain")
	var victim:int=(actor+1)%3+(3 if actor<3 else 0)
	if key in ["bounty","glory"]:g.characters[victim].hp=1
	var chosen:Dictionary={actor:H.give(g,actor,key)}
	if key=="godslayer":chosen[victim]=H.give(g,victim,"heal")
	H.begin(g,chosen,false)
	if key=="godslayer":finish_fx(g)
	if g.phase=="targeting":check(g.target(actor/3,victim)=="","legal chosen target")
	return g
func show_game(g,team:int=0)->void:
	main.session.team=team;main.session.state=g.snapshot(team);main.session.state.names=["本地动画测试","对手"]
	main.session.changed.emit();await frames()
func pose(g,t:float):
	var fx=meta(main,"effect_animation",g.animation.id)
	check(fx!=null,"effect layer exists")
	if fx==null:return null
	var card=main.board._active_widget()
	if card!=null:card.resolution_started=Time.get_ticks_msec()-1000;card._process(0);card.set_process(false)
	fx.clock_started=-1;fx.set_process(false);fx.elapsed=t*Styles.duration(fx.event)/1000.0;fx._process(0)
	await RenderingServer.frame_post_draw
	return fx
func shot(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v0174-"+name+".png")
func clear_card(card:Control)->void:
	check(card!=null,"actual active card remains on board")
	if card==null:return
	for id in range(6):
		for tag in ["knight_id","pawn_title","health_actor"]:
			var item=meta(main,tag,id)
			check(not card.get_global_rect().intersects(item.get_global_rect()),"raised card avoids %s %d"%[tag,id])
func _run()->void:
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	for key in ["godslayer","bounty","area_strike","glory"]:
		for actor in range(6):
			var g=fixture(key,actor)
			for viewer in [0,1]:
				await show_game(g,viewer)
				var fx=await pose(g,.45)
				check(fx.launch_effect!=null and fx.strike_effect!=null,"approved motif and weapon both present")
				check(fx.mouse_filter==Control.MOUSE_FILTER_IGNORE,"overlay never intercepts choice")
				var card=main.board._active_widget();clear_card(card)
				check(fx.z_index>card.z_index and card.motif_alpha==0,"one flying motif above card")
				var expected:Vector2=fx.get_global_transform().affine_inverse()*(card.get_global_transform()*card.emblem_center())
				check(fx.source.distance_to(expected)<2,"weapon starts at real displayed card")
				var count:int=g.animation.targets.size() if key=="area_strike" else 1
				for j in range(g.animation.targets.size()):
					var at:Vector2=fx._knight(g.animation.targets[j].id)
					var i:int=j if key=="area_strike" else 0
					var raised:Vector2=fx.launch_effect.flight_position(at,.3,i,count)
					check(raised.is_equal_approx(fx.launch_effect.flight_position(at,.45,i,count)),"hold weapon while aiming")
					var dir:Vector2=(fx.launch_effect.flight_position(at,1,i,count)-raised).normalized()
					check(Vector2.from_angle(fx.launch_effect.blade_angle(at,.48,i,count)+Launch.TIP_ANGLE).dot(dir)>.999,"blade tip faces its own target")
				if actor==0 and viewer==0:await pose(g,.8);await shot(key+"-travel")
			g.advance_animation()
			for viewer in [0,1]:
				await show_game(g,viewer);var fx=await pose(g,.18)
				if actor==0 and viewer==0:await shot(key+"-impact")
				await pose(g,.95);check(main.board._active_widget().motif_alpha==1,"card restores original symbol after hit")
			if key in ["bounty","glory"]:
				for _i in range(40):
					if Rewards.supports(g.animation):break
					g.advance_animation()
				check(Rewards.supports(g.animation),"reward continues after death effect")
				for viewer in [0,1]:
					await show_game(g,viewer);var fx=await pose(g,.6)
					check(fx.attack_reward!=null and fx.launch_effect==null,"reward never launches another damaging sword")
					var dest:Vector2=fx.attack_reward.destination()
					if key=="bounty":check(dest.y==(846 if actor/3==viewer else 156),"reward cards enter correct visible hand row")
					else:check(dest.x==(1012 if actor/3==viewer else 429),"badge flies to recipient team's counter")
					for t in [0.0,.2,.5,.8,1.0]:
						var p:Vector2=fx.attack_reward.reward_position(t,0)
						check(Rect2(100,20,1240,885).has_point(p),"reward path stays on board")
					if actor==5:await shot(key+"-opponent-reward-"+str(viewer))
				g.advance_animation()
				for viewer in [0,1]:
					await show_game(g,viewer);var fx=await pose(g,.15)
					check("+2" in fx.attack_reward.outcome() if key=="bounty" else "+1" in fx.attack_reward.outcome(),"actual reward label")
					if actor==0 and viewer==0:await shot(key+"-reward-impact")
	# New weapons remain recognizable when intercepted; no impact slash leaks through.
	for key in ["godslayer","bounty","glory"]:
		var g=H.fixture(8);serial+=1;g.match_id=serial;g.presentation_enabled=true
		H.begin(g,{0:H.give(g,0,key),4:H.give(g,4,"defense")});finish_fx(g);g.target(0,4);g.defend(1,true)
		await show_game(g);var fx=await pose(g,.8)
		check(fx.launch_effect!=null,"defense intercepts the same weapon");g.advance_animation();await show_game(g);await pose(g,.2);await shot(key+"-blocked")
		check(g.characters[4].hp==8,"blocked weapon did not damage target")
	# Window scaling and fewer targets share the same board coordinates.
	root.size=Vector2i(960,640);await frames()
	var g=H.fixture(8);serial+=1;g.match_id=serial;g.presentation_enabled=true;g.characters[5].hp=0
	H.begin(g,{0:H.give(g,0,"area_strike")});await show_game(g,1);var fx=await pose(g,.8)
	check(fx.event.targets.size()==2,"two living targets receive two weapons");clear_card(main.board._active_widget());await shot("area-two-small")
	main.session.leave();await frames();check(main.resolution_focus.is_empty(),"leaving resets card animation")
	print("V0174_UI_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
