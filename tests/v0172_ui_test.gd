extends SceneTree
const H=preload("res://tests/helpers.gd")
const Launch=preload("res://scripts/card_launch_effect.gd")
const Styles=preload("res://scripts/strike_styles.gd")
var main
var checks:=0
var failures:=0
var serial:=1720
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("V0172_UI_FAIL "+label)
func _initialize()->void:_run.call_deferred()
func frames()->void:
	for _i in range(4):await process_frame
func nodes(node:Node)->Array:
	var result:Array=[node]
	for child in node.get_children():result.append_array(nodes(child))
	return result
func meta(node:Node,key:String,value):
	if node.has_meta(key) and node.get_meta(key)==value:return node
	for child in node.get_children():
		var found=meta(child,key,value)
		if found!=null:return found
	return null
func show_game(g,team:int=0)->void:
	main.session.team=team;main.session.state=g.snapshot(team);main.session.state.names=["本地动画测试","对手"]
	main.session.changed.emit()
	await frames()
func pose(g,t:float):
	var fx=meta(main,"effect_animation",g.animation.id)
	check(fx!=null,"effect exists")
	if fx==null:return null
	var source=main.board._active_widget()
	if source!=null:
		source.resolution_started=Time.get_ticks_msec()-1000;source._process(0);source.set_process(false)
	fx.clock_started=-1;fx.set_process(false)
	fx.elapsed=t*Styles.duration(fx.event)/1000.0;fx._process(0)
	await RenderingServer.frame_post_draw
	return fx
func shot(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v0172-"+name+".png")
func fixture(key:String,actor:int=0):
	var g=H.fixture(8);serial+=1;g.match_id=serial;g.presentation_enabled=true
	for id in range(6):
		for k in ["strike","heal","defense"]:H.give(g,id,k)
	H.give_death(g,0,"resurrection");H.give_death(g,1,"legacy");H.give_death(g,2,"pain")
	if key=="heal":g.characters[actor].hp=3
	H.begin(g,{actor:H.give(g,actor,key)},false)
	if g.phase=="targeting":g.target(actor/3,actor if key=="defense" else (actor+3)%6)
	return g
func clear_card(card:Control)->void:
	for id in range(6):
		for key in ["knight_id","pawn_title","health_actor"]:
			var subject=meta(main,key,id)
			check(not card.get_global_rect().intersects(subject.get_global_rect()),"lift leaves %s %d clear"%[key,id])
func _run()->void:
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);await create_timer(.3).timeout
	for key in ["strike","double_strike","triple_strike","heal","defense"]:
		var g=fixture(key)
		check(Launch.supports(g.animation),"correct card-origin family "+key)
		for team in [0,1]:
			await show_game(g,team)
			var fx=await pose(g,.10)
			var card=main.board._active_widget()
			check(fx.launch_effect!=null and fx.z_index>card.z_index,"effect paints above card")
			check(fx.mouse_filter==Control.MOUSE_FILTER_IGNORE,"effects cannot intercept target clicks")
			check(is_zero_approx(card.motif_alpha),"single emblem detached from real card")
			var expected:Vector2=fx.get_global_transform().affine_inverse()*(card.get_global_transform()*card.emblem_center())
			check(fx.source.distance_to(expected)<2,"effect starts at actual transformed emblem")
			clear_card(card)
			if key in ["strike","double_strike","triple_strike"]:
				var launch=fx.launch_effect
				var n:int=launch.count_blades()
				check(n==({"strike":1,"double_strike":2,"triple_strike":3}[key]),"distinct blade count")
				check(absi(g.animation.travel_ms-roundi(1100/1.44))<=1,"flight runs another 20 percent faster than 0.17.2")
				var target:Vector2=fx._knight(g.animation.targets[0].id)
				for i in range(n):
					check(is_zero_approx(launch.blade_angle(target,.15,i,n)),"rise before any aiming")
					var held:Vector2=launch.flight_position(target,.30,i,n)
					check(held.is_equal_approx(launch.flight_position(target,.46,i,n)),"blade stays raised while aiming")
					var direction:Vector2=(launch.flight_position(target,1,i,n)-held).normalized()
					var facing:Vector2=Vector2.from_angle(launch.blade_angle(target,Launch.AIM_END,i,n)+Launch.TIP_ANGLE)
					check(facing.dot(direction)>.9999,"tip points at target before departure")
					check(launch.flight_position(target,.8,i,n).distance_to(held)>25,"flies only after aiming")
				if key=="double_strike" and team==0:
					for sample in [.2,.45,.75]:
						await pose(g,sample);await shot("double-%d"%roundi(sample*100))
			if key=="heal" and team==0:await pose(g,.72);await shot("heal-flight")
			check(g.characters[0].hp==(3 if key=="heal" else 8),"visual cannot apply HP early")
		await show_game(g)
		g.advance_animation();await show_game(g)
		var fx=await pose(g,.2)
		if key in ["strike","double_strike","triple_strike"]:
			var amount:int={"strike":1,"double_strike":2,"triple_strike":3}[key]
			check(g.characters[3].hp==8-amount,"one authoritative damage event")
			check(fx.sprites[3].node.position!=fx.sprites[3].position,"pawn provides secondary recoil")
		elif key=="heal":
			check(g.characters[0].hp==5,"heal only changes HP on arrival")
			var rect:Rect2=fx.feedback_rect(fx._knight(0),"+2  生命")
			for obstacle in fx.feedback_obstacles:check(not rect.intersects(obstacle),"healing result text unobstructed")
		elif key=="defense":
			check(g.characters[0].shield==1 and meta(main,"status_actor",0)!=null,"defense persists after impact")
		await shot(key+"-impact")
		await pose(g,.9)
		check(is_equal_approx(main.board._active_widget().motif_alpha,1.0),"card motif restored after effect")
		g.advance_animation();await show_game(g)
		check(meta(main,"effect_animation",g.animation.get("id",-1))==null,"completed overlay removed")
		var returns:Array=nodes(main).filter(func(n):return n is Button and n.get("returning")==true)
		check(not returns.is_empty(),"real card returns rather than duplicated copy")
		await create_timer(.27).timeout
		for card in returns:check(card.position.is_equal_approx(card.resolution_origin),"card settles back into played row")
	# All six slots, reduced window, and self-targeting use actual UI coordinates.
	root.size=Vector2i(960,640);await frames()
	for actor in range(6):
		var g=fixture("double_strike",actor)
		await show_game(g,actor%2);await pose(g,.5);clear_card(main.board._active_widget())
		if actor==5:await shot("guest-small")
	root.size=Vector2i(1200,800);await frames()
	# A real defense response keeps the aura until the cancel event consumes it.
	var g=H.fixture(8);g.match_id=1800;g.presentation_enabled=true
	H.begin(g,{0:H.give(g,0,"defense"),3:H.give(g,3,"double_strike")})
	g.advance_animation();g.advance_animation();await show_game(g)
	check(meta(main,"status_actor",0)!=null,"shield stays while choosing next attack")
	g.target(1,0);g.defend(0,true);await show_game(g)
	var fx=await pose(g,.65)
	check(fx.launch_effect.count_blades()==2,"defense intercepts the attacking card's two blades")
	g.advance_animation();await show_game(g);await pose(g,.2);await shot("shield-block")
	check(g.characters[0].hp==8 and g.characters[0].shield==0,"block consumes shield, HP unchanged")
	g.advance_animation();await show_game(g)
	check(meta(main,"status_actor",0)==null,"consumed shield leaves no lingering aura")
	# Refresh and resizing must not restart the weapon sequence.
	g=fixture("strike");await show_game(g);await create_timer(.15).timeout
	fx=meta(main,"effect_animation",g.animation.id);var elapsed:float=fx.elapsed
	main._schedule_render();await frames()
	check(meta(main,"effect_animation",g.animation.id).elapsed>=elapsed,"refresh preserves animation time")
	main.session.leave();await frames()
	check(main.resolution_focus.is_empty() and main.resolution_returns.is_empty(),"leaving clears motion state")
	print("V0172_UI_RESULT checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
