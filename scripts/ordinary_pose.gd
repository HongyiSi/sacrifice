extends RefCounted
const Art=preload("res://scripts/cinema/atlas.gd")
const Layout=preload("res://scripts/board_layout.gd")
const Card=preload("res://scripts/card_widget.gd")
var f
var moving=[]
var chest
static func dock(id,mine,key):
	var own=id/3==mine
	var p=Layout.hand_origin(id,own)+Vector2(275,-76) if own else Layout.hand_origin(id,own)+Vector2(60,181)
	if key=="elegy":p=Layout.pawn_center(id,own)+Vector2(116,-97)
	return p
static func staged_at(index):return Vector2(1028+(index%4)*62,444-floori(index/4.)*100)
func setup():
	for n in f.all_nodes(f.board.canvas):
		if n.get_meta("draw_chest",false):chest=n
	if f.op=="elegy_pack":
		var motion=f.event.hand_motion
		var own=f.actor/3==f.mine
		var slots=motion.get("owner_slots",motion.slots) if own else motion.slots
		var ids=motion.get("owner_cards",[])
		for i in range(slots.size()):
			var key=f.board.view.catalog.get(ids[i],{}).get("key","") if own and i<ids.size() else ""
			moving.append({"from":f.hand_slot(f.actor,slots[i]),"face":key})
		for n in f.all_nodes(f.board.canvas):
			if n.get_meta("hand_actor",-1)==f.actor or n.get_meta("enemy_hand_actor",-1)==f.actor:
				for c in n.get_children():
					if c is Card and c.get_meta("hand_slot",-1) in slots:c.hide();f.hidden_nodes.append(c)
	if f.key=="defile" and f.op=="defile_seal":
		var motion=f.event.hand_motion
		var own=motion.actor/3==f.mine
		var slots=motion.get("owner_slots",motion.slots) if own else motion.slots
		for n in f.all_nodes(f.board.canvas):
			if n.get_meta("hand_actor",-1)==motion.actor or n.get_meta("enemy_hand_actor",-1)==motion.actor:
				for c in n.get_children():
					if c is Card and c.get_meta("hand_slot",-1) in slots:
						var m=preload("res://scripts/defile_mark.gd").new();c.add_child(m);m.configure(f.clock_started)
						m.set_process(false);moving.append({"mark":m})
func update():
	if f.op=="discard_finish":return
	if f.key=="defile" and f.op=="defile_seal":
		for m in moving:m.mark.present(f.elapsed-.25 if f.stage=="travel" else 5.)
	if f.key=="spare_supplies" and is_instance_valid(chest):
		chest.present(smoothstep(1.08,1.48,f.elapsed) if f.stage=="travel" else 1.)
	if f.stage=="impact" and f.key=="spare_food":
		f.react(f.actor,f.elapsed,.65,true)
	if f.stage=="impact" and f.key=="feign":f.react(f.actor,f.elapsed,.5)
	if is_instance_valid(f.source_widget):f.source_widget.motif_alpha=0.;f.source_widget.queue_redraw()
func draw():
	if f.op=="discard_finish":return
	match f.key:
		"defile","plunder":choice_prop()
		"elegy":box()
		"feign":mask()
		"spare_food","spare_supplies":reserve()
func choice_prop():
	var end=dock(f.target_ids[0],f.mine,f.key)
	var fly=f.smooth(0.,1.02,f.elapsed) if f.stage=="travel" and f.op in ["defile","plunder"] else 1.
	var pos=f.bezier(f.source,end,fly,-48)
	var side=lerpf(50.,102.,fly)
	f.shadow(pos+Vector2(1,49),35,.15*fly)
	f.prop(f.key,pos,side,-.14*sin(fly*PI),1.)
	if f.op=="defile_seal":
		# The bottle and pen stay anchored. Only the textured ink strokes advance.
		var m=f.event.hand_motion;var own=m.actor/3==f.mine
		var slots=m.get("owner_slots",m.slots) if own else m.slots
		if slots.is_empty():return
		var target=f.hand_slot(m.actor,slots[0])
		var glow=sin(clampf(f.elapsed/1.1,0,1)*PI)*.13 if f.stage=="travel" else 0.
		f.glow(target,58*Layout.hand_scale(own),glow,Color("9866ba"))
func box():
	var rest=dock(f.actor,f.mine,"elegy")
	var p=rest;var side=142.;var angle=0.
	if f.op=="elegy_cost":
		var v=f.smooth(0.,.96,f.elapsed) if f.stage=="travel" else 1.
		p=f.bezier(f.source,rest,v,-42);side=lerpf(51.,142.,v)
	if f.op=="draw_death" and f.stage=="travel":
		var shake=sin(f.elapsed*27)*sin(f.elapsed*PI/.92) if f.elapsed<.92 else 0.
		p+=Vector2(shake*2.7,absf(shake)*-1.1);angle=shake*.025
	var a=1.
	if f.op=="draw_death":a=1-f.smooth(1.86,2.18,f.elapsed) if f.stage=="travel" else 0.
	f.shadow(p+Vector2(0,59),51,.14*a)
	f.prop("elegy",p,side,angle,a)
	if f.op=="elegy_pack":
		for i in range(moving.size()):
			var age=f.elapsed-i*.36 if f.stage=="travel" else 5.
			var approach=f.smooth(.04,.74,age)
			var above=rest+Vector2(-6,-95)
			var down=f.smooth(.74,1.30,age)
			var q=f.bezier(moving[i].from,above,approach,-45).lerp(rest+Vector2(-6,13),down)
			var sz=lerpf(1.45,.14,down)
			f.little_card(q,-.12*sin(approach*PI)*(1-down),sz,1-f.smooth(1.1,1.30,age),moving[i].face)
		front(p,side,a)
	elif f.op=="draw_death" and f.stage=="travel" and f.elapsed>.80 and f.event.get("card_count",0)>0:
		var v=f.smooth(.86,2.1,f.elapsed)
		var dest=death_landing()
		var q=f.bezier(rest+Vector2(-3,-13),dest,v,-72)
		f.little_card(q,.10*sin(v*PI),lerpf(.30,2. if f.actor/3==f.mine else 1.,f.smooth(0,.72,v)),1.,"",true)
		if v<.20:front(p,side,a)
func death_landing():
	var own=f.actor/3==f.mine
	var count=f.board.view.characters[f.actor].get("death_slots",[]).size()
	var index=int(f.event.get("death_slot",count))
	var factor=1. if own else .5
	var positions=f.board._fan_positions(index+1,132. if own else 120.,76*factor)
	return Layout.death_origin(f.actor,own)+Vector2(positions[index]+38*factor,54*factor)
func front(p,side,a):
	# Reuse painted foreground pixels to occlude cards crossing the box's open rim.
	var tex=Art.texture("elegy");var dims=tex.get_size();var sz=dims*(side/maxf(dims.x,dims.y))
	var shape=[Vector2(.035,.55),Vector2(.66,.67),Vector2(.68,.96),Vector2(.04,.78)]
	var pts=PackedVector2Array();var uv=PackedVector2Array()
	for q in shape:pts.append(p+(q-Vector2(.5,.5))*sz);uv.append((tex.region.position+q*tex.region.size)/tex.atlas.get_size())
	f.draw_polygon(pts,PackedColorArray([Color(1,1,1,a)]),uv,tex.atlas)
func mask():
	var v=f.smooth(.05,1.05,f.elapsed) if f.stage=="travel" else 1.
	var end=f.pawn(f.actor)+Vector2(7,-22)
	var p=f.bezier(f.source,end,v,-38)
	var a=1. if f.stage=="travel" else 1-f.smooth(.12,.5,f.elapsed)
	f.prop("feign",p,lerpf(51,70,v),-.1*sin(v*PI),a)
	if f.stage=="impact":
		f.label_at(end+Vector2(61,-10),"-2",Color("dda1b1"),1-f.smooth(.25,.52,f.elapsed),23)
		f.glow(end,66,.11*a,Color("946aba"))
func reserve():
	var row=f.event.get("discard_pose",{})
	var index=0
	for i in range(f.board.view.get("staged_discards",[]).size()):
		if f.board.view.staged_discards[i].card==row.get("card",-1):index=i;break
	var start=staged_at(index)
	var end=f.pawn(f.actor)+Vector2(7,0) if f.key=="spare_food" else Layout.DECK_LOCK+Vector2(35,-3)
	var length=1.05 if f.key=="spare_food" else 1.12
	var v=f.smooth(0.,length,f.elapsed) if f.stage=="travel" else 1.
	var a=1-f.smooth(.84,1.,v)
	var pos=f.bezier(start,end,v,-54)
	f.prop(f.key,pos,lerpf(42,78,sin(v*PI)),.12*sin(v*PI),a)
	if f.key=="spare_food" and f.stage=="impact":
		var h=preload("res://scripts/cinema/healing.gd").new();h.f=f
		h.healing_wrap(f.pawn(f.actor),.35+f.u*.65,1-f.smooth(.55,1,f.u),0)
