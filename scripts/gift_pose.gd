extends RefCounted
const Box=preload("res://scripts/gift_box.gd")
const Card=preload("res://scripts/card_widget.gd")
const DEPART=.69
const STAGGER=.44
const FLIGHT=1.30
const PACK=2.95
const TOTAL=4.95
var f
var box
var cards=[]
var recipient=0
var count=0
func setup(effect):
	f=effect;f.z_index=160;recipient=int(f.event.get("gift_target",f.target_ids[0]))
	count=int(f.event.get("card_count",0));box=Box.new();f.add_child(box)
	if f.stage!="travel":return
	var motion=f.event.get("hand_motion",{});var own=f.actor/3==f.mine
	var slots=motion.get("owner_slots",motion.get("slots",[]))
	for n in f.all_nodes(f.board.canvas):
		if n.get_meta("hand_actor",-1)!=f.actor and n.get_meta("enemy_hand_actor",-1)!=f.actor:continue
		var originals=n.get_children().filter(func(c):return c is Card)
		for slot in slots:
			if slot<0 or slot>=originals.size():continue
			var source=originals[slot];var c=f.board._card(f,source.card.duplicate(true),source.death,source.hidden_card)
			c.size=source.size;c.pivot_offset=c.size*.5;c.mouse_filter=Control.MOUSE_FILTER_IGNORE;c.set_process(false)
			c.priority_bonus=source.priority_bonus;c.z_index=1
			cards.append({"node":c,"original":source,"start":f.local_center(source),"scale":source.scale.x})
			f.hidden_nodes.append(source)
func age():return f.t+(PACK if f.stage=="impact" else 0.0)
func state(at):
	var start=Box.dock(f.actor,f.mine);var finish=Box.dock(recipient,f.mine)
	var rise=f.smooth(.0,.53,at)
	var pos=f.bezier(f.source,start,rise,-28)
	var closing=f.smooth(2.55,2.90,at)
	var move=f.smooth(2.98,4.30,at)
	pos=f.bezier(pos,finish,move,-57)
	var opened=1-closing+f.smooth(4.35,4.90,at)
	return {"pos":pos,"opened":opened,"angle":sin(move*TAU)*.055,"side":lerpf(65,Box.SIDE,rise),"alpha":f.smooth(0,.12,at)}
func update():
	var at=age();var s=state(at);box.present(s.pos,s.opened,s.alpha,s.angle,s.side)
	if is_instance_valid(f.source_widget):f.source_widget.motif_alpha=1-f.smooth(0,.12,at);f.source_widget.queue_redraw()
	for i in range(cards.size()):
		var entry=cards[i];var c=entry.node
		var depart=DEPART+i*STAGGER;var v=clampf((at-depart)/FLIGHT,0.,1.)
		entry.original.visible=at<depart;c.visible=at>=depart and v<1
		var mouth=box.mouth()+Vector2((i-(cards.size()-1)*.5)*9,0)
		var outside=mouth+Vector2(-102,-77)
		var above=mouth+Vector2(0,-77)
		var inside=box.position+Vector2((i-(cards.size()-1)*.5)*9,34)
		var point:Vector2
		if v<.48:
			var t=f.smooth(0,.48,v)
			point=entry.start.bezier_interpolate(entry.start+Vector2(-35,-82),outside+Vector2(-10,85),outside,t)
		elif v<.72:
			var t=f.smooth(.48,.72,v)
			point=outside.bezier_interpolate(outside+Vector2(45,-30),above+Vector2(-38,0),above,t)
		else:point=above.lerp(inside,f.smooth(.72,1.,v))
		c.position=point-c.pivot_offset;c.scale=Vector2.ONE*lerpf(entry.scale,.36,f.smooth(.06,.60,v))
		# Stay in FRONT of the solid box until the entire card has cleared its
		# rim from outside. Only the final downward insertion is behind the lip.
		c.z_index=6 if v<.72 else 1
		c.rotation=sin(f.smooth(0,.72,v)*PI)*(-.10 if i%2==0 else .10);c.modulate.a=1
		entry.progress=v;entry.center=point
		c.queue_redraw()
func draw():
	pass
