extends "res://tests/v0203_ui_test.gd"
const Props=preload("res://scripts/persistent_death_props.gd")
const ArtCases=preload("res://tests/art_scenarios.gd")
func all_nodes(n):
	var result=[n]
	for child in n.get_children():result.append_array(all_nodes(child))
	return result
func activate(g,key,actor,target):
	var card=H.give_death(g,actor,key);g.death_revealed.append(card)
	if key!="immortal":g._activate({"actor":actor,"card":card,"death":true},target)
	return card
func visible(key,id):
	if key=="pain":return meta(main,"persistent_pain",id)!=null
	if key=="divinity":return meta(main,"divinity_actor",id)!=null
	var node=meta(main,"persistent_death_props",id)
	return node!=null and node.keys.has(key)
func assert_layout(g,viewer):
	var all=all_nodes(main)
	var view=g.snapshot(viewer)
	for c in view.characters:
		var nodes=all.filter(func(n):return n.get_meta("persistent_death_props",-1)==c.id)
		var expected=Props.visible_keys(c,view.get("animation",{})).any(func(k):return k in Props.KEYS)
		check(nodes.size()==(2 if expected else 0),"exactly two draw layers, no duplicate rebuild")
		var target=meta(main,"knight_id",c.id)
		check(target.get_child(0) is TextureRect,"combat still finds original sprite at child zero")
		for n in nodes:
			check(n.mouse_filter==Control.MOUSE_FILTER_IGNORE,"ornaments never intercept target selection")
			check(n.show_behind_parent==n.back,"correct foreground/background split")
			for key in n.keys:
				if key not in Props.KEYS:continue
				var p=Props.world_pose(main.board,c.id,key,n.keys)
				var health=Layout.pawn_rect(c.id,c.id/3==viewer).position.y+129
				check(p.at.y+p.side*.5<health+1,"motif avoids health: %s pawn %d view %d bottom %.2f health %.2f"%[key,c.id,viewer,p.at.y+p.side*.5,health])
func _run():
	root.size=Vector2i(1440,960)
	main=load("res://scenes/main.tscn").instantiate()
	main.get_node("Session").set_script(preload("res://tests/ui_local_session.gd"))
	root.add_child(main);await create_timer(.3).timeout
	main.session.set_process(false);main.music.set_level(0);main.attack_audio.level=0
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/deathrattles.json"))
	var ongoing=catalog.filter(func(c):return c.type=="持续性").map(func(c):return c.key)
	check(ongoing.size()==Props.ALL_KEYS.size() and ongoing.all(func(k):return k in Props.ALL_KEYS),"all persistent death cards covered")
	for key in ongoing:
		for actor in [0,1,2,3,4,5]:
			var g=H.fixture(7);serial+=1;g.match_id=serial
			activate(g,key,actor,actor)
			if key in ["pain","ghost"]:g.characters[actor].hp=0
			for viewer in [0,1]:
				await show_game(g,viewer)
				for id in range(6):
					var expected=id==actor or (key in ["greed","privilege"] and id/3==actor/3)
					check(visible(key,id)==expected,"public effect visible on correct pawns in both perspectives")
				assert_layout(g,viewer)
			g.phase="review";g.presentation_enabled=false;g.advance_round()
			await show_game(g,0)
			check(visible(key,actor),"persistent effect survives round transition")
			g._strip_deaths(actor);await show_game(g,0)
			for id in range(6):check(visible(key,id)==(key=="immortal" and id==actor),"source loss clears marks, immortal obeys non-discardable rule")
	# Public visibility: owning a concealed card is not enough to reveal its motif.
	var hidden=H.fixture(7);serial+=1;hidden.match_id=serial
	H.give_death(hidden,0,"immortal")
	for viewer in [0,1]:
		await show_game(hidden,viewer);check(not visible("immortal",0),"unrevealed immortal stays private")
	hidden.death_revealed.append(120);hidden.characters[1].hp=0;hidden.characters[2].hp=0
	await show_game(hidden,1)
	var dormant=meta(main,"persistent_death_props",0)
	check(dormant!=null and dormant.statuses.immortal.dormant,"unavailable resurrection retains dormant public phoenix")
	# Simultaneous effects and repeated UI reconstruction, both views.
	var mixed=H.fixture(7);serial+=1;mixed.match_id=serial
	for key in ongoing:activate(mixed,key,0,0)
	for viewer in [0,1]:
		for rebuild in range(3):
			await show_game(mixed,viewer);assert_layout(mixed,viewer)
			for key in ongoing:check(visible(key,0),"all nine effects retained together across rebuilds")
	# Real activation events: handoff never depends on an effect having been seen before.
	for key in Props.KEYS:
		serial+=1;var pair=ArtCases.setup(key,serial);var g=pair[0];var ctx=pair[1]
		for step in range(100):
			if g.animation.is_empty() and g.phase in ["review","planning","ended"]:break
			var e=g.animation
			if Props.is_arrival(e) or (e.get("style","")=="immortal" and e.get("kind","")=="card_effect"):
				for viewer in [0,1]:
					await show_game(g,viewer);assert_layout(g,viewer)
					for node in all_nodes(main):
						if not node.has_meta("persistent_death_props"):continue
						node.clock_started=-1;node.set_process(false)
						for u in [.0,.65,.86,1.0]:
							node.present(u*Styles.duration(e)/1000.)
							for k in node.keys:check(node.weight(k)>=0 and node.weight(k)<=1,"handoff opacity stays valid")
			var err=ArtCases.step(g,ctx);check(err.is_empty(),"real rules scenario resolves: "+err)
	# Compare actual rendered bronze-rim pixels at two different lift heights.
	# The feet move; the visible pedestal front must remain pixel-identical.
	for actor in range(6):
		var g=H.fixture(7);serial+=1;g.match_id=serial
		activate(g,"divinity",actor,actor)
		await show_game(g,int(actor/3))
		var d=meta(main,"divinity_actor",actor);d.set_process(false)
		var factor=d.texture_rect.size.x/d.texture.get_width()
		var r:Rect2=d.base_bounds
		var p=d.get_global_transform()*(d.texture_rect.position+(r.position+Vector2(r.size.x*.25,r.size.y*.83))*factor)
		var area=Rect2i(Vector2i(p),Vector2i(r.size*Vector2(.5,.12)*factor))
		d.pose(1.7,.7);await RenderingServer.frame_post_draw
		var before=root.get_texture().get_image().get_region(area).get_data()
		d.pose(3.6,1.);await RenderingServer.frame_post_draw
		var after=root.get_texture().get_image().get_region(area).get_data()
		check(before==after,"rendered pedestal rim stays completely stationary: pawn "+str(actor))
	print("PERSISTENT_DEATH_CHECKS_OK checks=",checks," failures=",failures)
	main.queue_free();await frames();quit(1 if failures else 0)
