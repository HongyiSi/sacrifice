extends RefCounted
## Stationary printed heart: physical card approach, collected hearts, one-point arrivals.
const T=preload("res://scripts/heart_conversion_timing.gd")
const Card=preload("res://scripts/card_widget.gd")
const Frame=preload("res://scripts/art_ui/frame_design.gd")
var f
var cards=[]
var count=0
var health
var filled_before=0
var gain=0
var heart_side=56.0
var front
var last_display=-1
const WARM=Color("efb7a5")
const PEARL=Color("fff0cd")
const GREEN=Color("a3d6ac")
class Foreground extends "res://scripts/cinema/cinema.gd":
	var pose
	func _draw():pose.draw_front(self)
	func _process(_delta):pass
	func _exit_tree():pass
func setup():
	count=T.count(f.event)
	if is_instance_valid(f.source_widget):
		var c=f.source_widget
		var w=c.size.x;var body=Rect2(w/76.,0,w-w/38.,c.size.y-4*w/76.)
		var r=Frame.scaled(Frame.layout(Frame.style).art,body)
		var tex=f.Art.texture("heart");var d=tex.get_size()
		heart_side=maxf(d.x,d.y)*minf(r.size.x/d.x,r.size.y/d.y)*c.scale.x
	for n in f.all_nodes(f.board.canvas):
		if n.get_meta("health_actor",-1)==f.actor:health=n
	if f.kind=="card_effect" and f.stage=="travel":
		var motion=f.event.get("hand_motion",{});var own=f.actor/3==f.mine
		var slots=motion.get("owner_slots",motion.get("slots",[])) if own else motion.get("slots",[])
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
	if f.kind=="heal":
		filled_before=int(f.event.targets[0].before);gain=int(f.event.targets[0].after)-filled_before
	front=Foreground.new();front.pose=self;front.size=Vector2(1440,960);front.mouse_filter=Control.MOUSE_FILTER_IGNORE;front.z_index=3;f.add_child(front)
func storage(i):
	# Gather beside the printed artwork; keep both priority and name readable.
	var rows=ceili(count/2.0)
	return f.source+Vector2((-1 if i%2==0 else 1)*57,(floori(i/2.0)-(rows-1)*.5)*22)
func packet_position(i,age):
	var v=clampf((age-T.leave(i))/T.OUT_FLIGHT,0.,1.)
	var p=storage(i);var goal=f.pawn(f.actor)+Vector2(10,17)
	var bend=Vector2(45 if goal.x>=p.x else -45,-34)
	return p.bezier_interpolate(p+bend,goal+Vector2(-14,-58),goal,f.smooth(0,1,v))
func update():
	if is_instance_valid(f.source_widget):
		# Exactly the original art, centre and size; the motif never leaves the card.
		f.source_widget.motif_alpha=1.;f.source_widget.queue_redraw()
	for i in range(cards.size()):
		var e=cards[i];var c=e.node
		var depart=T.DEPART+i*T.STEP;var v=clampf((f.t-depart)/T.IN_FLIGHT,0.,1.)
		e.original.visible=f.t<depart;c.visible=f.t>=depart and v<1.
		var p=e.start.bezier_interpolate(e.start+Vector2((i%2*2-1)*22,-90),f.source+Vector2(-40,60),f.source,f.smooth(0,1,v))
		var s=lerpf(e.scale,.10,f.smooth(.30,1,v))
		c.position=p-c.pivot_offset;c.scale=Vector2.ONE*s;c.rotation=sin(v*PI)*(.12 if i%2==0 else -.12)
		c.modulate.a=1-f.smooth(.72,1,v);c.queue_redraw()
		e.progress=v;e.center=p
	if f.kind=="heal":
		var restored=0
		if f.stage=="impact":
			for i in range(mini(gain,count)):
				if f.t>=T.arrive(i):restored+=1
		set_health(filled_before+restored)
		if restored>0:f.react(f.actor,f.t-T.arrive(restored-1),.36,true)
	front.queue_redraw()
func set_health(value):
	last_display=value
	if not is_instance_valid(health):return
	var index=0
	for n in health.get_children():
		if n is TextureRect and n.material is ShaderMaterial:
			n.material.set_shader_parameter("filled",index<value)
			var elapsed=f.t-T.arrive(index-filled_before)
			var pulse=sin(clampf(elapsed/.32,0,1)*PI) if index>=filled_before and index<value and f.stage=="impact" else 0.
			n.pivot_offset=n.size*.5;n.scale=Vector2.ONE*(1+.20*pulse);index+=1
		elif n is Label:n.text="生命 %d / %d"%[value,f.board.view.characters[f.actor].max_hp]
func draw():
	# The faint moving reflection stays on the cloth, underneath the paper.
	for e in cards:
		if e.node.visible:
			f.shadow(e.center+Vector2(0,26-15*e.progress),26*(1-e.progress),.11*(1-e.progress))
func dust(canvas,p,age,seed,strength=1.):
	if age<0 or age>.64:return
	for j in range(13):
		var theta=j*2.399+seed*.77;var speed=13+float((j*7)%17)
		var at=p+Vector2.from_angle(theta)*(5+speed*age)+Vector2(0,-16*age*age)
		var a=pow(1-age/.64,2)*strength
		canvas.glow(at,4.+float(j%3),a*.35,PEARL)
		canvas.draw_circle(at,.65+float(j%3)*.26,Color(PEARL,a*.8),true,-1,true)
func draw_front(canvas):
	# Draw above moving paper so the card passes into, not over, the printed heart.
	f.Art.draw_prop(canvas,"heart",f.source,heart_side,0,1.)
	for i in range(count):
		var birth=f.t-T.enter(i) if f.kind=="card_effect" and f.stage=="travel" else 10.0
		if birth<0:continue
		var spread=f.smooth(.02,T.MORPH,birth)
		var pos=f.source.lerp(storage(i),spread)
		var size_now=lerpf(7.,18.,spread)
		var opacity=f.smooth(0,.10,birth)
		if f.kind=="heal" and f.stage=="impact":
			var age=f.t-T.leave(i);var v=clampf(age/T.OUT_FLIGHT,0.,1.)
			pos=packet_position(i,f.t)
			var tail=PackedVector2Array()
			if age>0 and v<1:
				for j in range(14):tail.append(packet_position(i,maxf(T.leave(i),f.t-.13+j*.01)))
				canvas.ribbon(tail,3.3,.40,PEARL)
				canvas.glow(pos,21,.20,WARM)
			opacity=1-f.smooth(.88,1,v)
			size_now=18.+3*sin(v*PI)
			var hit=f.t-T.arrive(i)
			if i<gain and hit>=0 and hit<.64:
				var goal=f.pawn(f.actor)+Vector2(10,17)
				canvas.glow(goal,65,(1-f.smooth(0,.6,hit))*.30,GREEN)
				dust(canvas,goal,hit,i,.62)
				canvas.label_at(f.pawn(f.actor)+Vector2(61,-18-hit*35),"+1",Color("e3f8ce"),1-f.smooth(.27,.6,hit),22)
				if is_instance_valid(health):
					var step=minf(23,185./maxi(1,f.board.view.characters[f.actor].max_hp))
					var target=health.position+Vector2(step*(filled_before+i)+step*.5,10)
					canvas.glow(target,21,.28*(1-f.smooth(.10,.48,hit)),GREEN)
			elif i>=gain and hit>=0 and hit<.4:dust(canvas,f.pawn(f.actor)+Vector2(10,17),hit,i,.28)
		# The existing painted health jewel gives small hearts a real shaded surface.
		var tex=preload("res://assets/art_ui/chrome/heart.png")
		canvas.draw_set_transform(pos,.08*sin(i+f.t*2),Vector2.ONE)
		canvas.draw_texture_rect(tex,Rect2(-Vector2.ONE*size_now*.5,Vector2.ONE*size_now),false,Color(1,1,1,opacity))
		canvas.draw_set_transform(Vector2.ZERO)
		if f.kind=="card_effect" and f.stage=="travel":dust(canvas,f.source,birth,i,.62)
	# Small warm illumination only, never a replacement mask over the artwork.
	var light=0.
	if f.kind=="card_effect" and f.stage=="travel":
		for i in range(count):light+=exp(-pow((f.t-T.enter(i))/.14,2))
	if light>.001:canvas.glow(f.source,heart_side*.78,minf(.24,light*.20),WARM)
