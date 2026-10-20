extends Control
const Layout=preload("res://scripts/board_layout.gd")
const Card=preload("res://scripts/card_widget.gd")
const Speech=preload("res://scripts/pawn_speech.gd")
const Art=preload("res://scripts/cinema/atlas.gd")
const Back=preload("res://scripts/art_ui/back_design.gd")
const Chest=preload("res://scripts/draw_pile.gd")
# Lift just above the inner trim before crossing the front wall's depth plane.
# This is part of the existing departure, not an extra beat in the deal.
const RIM_CLEAR_T=.018
const RIM_LIFT=Vector2(0,-4)
const DECK=preload("res://scripts/board_layout.gd").DECK_CENTER
const BLUE=Color("355f89")
const RED=Color("a95138")
const EDGE=Color("b69763")
var board
var event:Dictionary={}
var mine:=0
var clock_started:=-1
var elapsed:=0.0
var tick:=0.0
var rows:Dictionary={}
var flights:Array=[]
var notices:Dictionary={}
var paths:Dictionary={}
var header_count:Label
var pile:Control
var restored:Array=[]
var layer_backups:Array=[]
var first_step:=true
var speeches:Dictionary={}
var pile_changes:Array=[]
var chest_first:=INF
var chest_last:=-1.0
var chest_preopened:=false
var gift_boxes={}
var gift_source
var curse_pose
var hook_pose
var chest_departure:Control
class ChestDeparture extends Control:
	var flight_animation
	func _draw()->void:
		flight_animation.draw_chest_departures(self,true)
const GiftBox=preload("res://scripts/gift_box.gd")
func find_meta(n:Node,key:String,value):
	if n.has_meta(key) and n.get_meta(key)==value:return n
	for ch in n.get_children():
		var found=find_meta(ch,key,value)
		if found!=null:return found
	return null
func initialize(table,started:int)->void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	board=table;mine=board.mine;event=board.view.animation;clock_started=started
	size=Vector2(1440,960);mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=80
	pile=find_meta(board.canvas,"draw_pile",true)
	chest_departure=ChestDeparture.new();chest_departure.flight_animation=self
	chest_departure.mouse_filter=Control.MOUSE_FILTER_IGNORE
	chest_departure.z_index=Chest.DEPARTURE_Z-z_index
	add_child(chest_departure)
	for n in board.canvas.get_children():
		if n is Label and n.text.begins_with("牌库 "):header_count=n
		if n.has_meta("knight_id") and int(n.get_meta("knight_id"))/3!=mine:
			layer_backups.append({"node":n,"z":n.z_index});n.z_index=60
	for d in event.draws:
		var id:int=d.target
		if rows.has(id):continue
		var friendly:bool=id/3==mine
		var source=find_meta(board.canvas,"hand_actor" if friendly else "enemy_hand_actor",id)
		if source==null:continue
		var cards:Array=[]
		for node in source.get_children():
			if not node is Card:continue
			var c=board._card(self,node.card.duplicate(true),node.death,node.hidden_card)
			c.priority_bonus=node.priority_bonus
			c.self_modulate=node.self_modulate
			c.mouse_filter=Control.MOUSE_FILTER_IGNORE if c.card.is_empty() else Control.MOUSE_FILTER_STOP
			c.focus_mode=Control.FOCUS_NONE;c.size=node.size;c.scale=node.scale;c.pivot_offset=Vector2(38,54)
			c.set_meta("inspect_key","draw_%d_%d"%[id,int(c.card.get("id",0))])
			# Animation copies only support hover. Playing resumes on the actual
			# hand after the deal, and must never open the legacy click preview.
			c.set_meta("hand_slot",node.get_meta("hand_slot",-1))
			if preload("res://scripts/defile_mark.gd").is_marked(c,board.view.characters[id].get("defiled_slots",[])):
				var mark=preload("res://scripts/defile_mark.gd").new()
				c.add_child(mark);mark.configure(-1)
			c.position=(node.global_position-board.canvas.global_position)/board.canvas.scale-c.pivot_offset*(Vector2.ONE-c.scale)
			c.set_process(false);cards.append(c)
		source.hide();restored.append(source)
		var name:Label=find_meta(board.canvas,"hand_count_actor",id)
		rows[id]={"cards":cards,"before":d.before_count,"count":d.before_count,"label":name,"friendly":friendly,"order":[]}
	var offsets:Dictionary={}
	var prop_offsets:Dictionary={}
	var prop_totals:Dictionary={}
	for d in event.draws:
		if d.get("placement",false):
			var batch:String=str(d.target)+"/"+d.source_key
			prop_totals[batch]=int(prop_totals.get(batch,0))+d.count
	for d in event.draws:
		if not rows.has(d.target):continue
		var r:Dictionary=rows[d.target]
		if d.get("origin",{}).get("kind","")=="gift_box" and not gift_boxes.has(d.target):
			var box=GiftBox.new();add_child(box);gift_boxes[d.target]=box
			gift_source=board._active_widget()
		if not d.has("origin"):
			chest_first=minf(chest_first,float(d.start_ms)/1000.0)
			chest_preopened=chest_preopened or d.get("source_key","") in ["collect","bloodletting","spare_supplies"]
			for i in range(d.count):
				if d.starts[i]>=0:chest_last=maxf(chest_last,(d.starts[i]+d.durations[i])/1000.0)
			if d.returned.has(true):chest_last=maxf(chest_last,d.speech_start/1000.0+.45)
		for i in range(d.count):
			var returned:bool=d.get("returned",[]).size()>i and d.returned[i]
			var node=null
			if returned:
				if not speeches.has(d.target):
					var speech=Speech.new();add_child(speech)
					speech.configure(d.target,"我的手牌满了！",Layout.pawn_rect(d.target,d.target/3==mine),BLUE if d.target/3==mine else RED)
					speeches[d.target]={"node":speech,"first":INF,"last":-1.0}
				var speech_start:float=d.speech_start/1000.0
				speeches[d.target].first=minf(speeches[d.target].first,speech_start)
				speeches[d.target].last=maxf(speeches[d.target].last,speech_start+d.speech_ms/1000.0)
				continue
			elif d.has("ids"):
				for c in r.cards:
					if c.card.get("id",-1)==d.ids[i]:node=c;break
			else:
				var index:int=r.before+int(offsets.get(d.target,0))
				if index<r.cards.size():node=r.cards[index]
			if not returned:offsets[d.target]=int(offsets.get(d.target,0))+1
			if node==null:continue
			node.set_meta("incoming",true)
			node.hidden_card=true
			var start:float=d.starts[i]/1000.0
			var duration:float=d.durations[i]/1000.0
			var origin: Vector2 = DECK
			if d.has("origin"):
				var own: bool = int(d.origin.actor)/3 == mine
				if d.origin.kind=="gift_box":origin=GiftBox.dock(d.target,mine)+Vector2(0,34)
				elif d.origin.kind == "hand":
					var slot: int = d.origin.get("owner_slot",d.origin.slot) if own else d.origin.slot
					origin = Layout.hand_position(d.origin.actor,slot,own)+Layout.CARD_SIZE*Layout.hand_scale(own)/2
				else:
					var active = board._active_widget()
					origin = board.canvas.get_global_transform().affine_inverse()*(active.get_global_transform()*active.emblem_center()) if active!=null else Layout.pawn_center(d.origin.actor,own)
			var placement:bool=d.get("placement",false) and d.get("source_key","")!="search"
			var prop_key:String={"obstruct":"boulder","poisoning":"poison","gift":"gift_closed","search":"search","plunder":"plunder"}.get(d.get("source_key",""),"") if placement else ""
			if placement and d.get("origin",{}).get("kind","")=="emblem":
				var batch:String=str(d.target)+"/"+d.source_key
				origin+=Vector2((int(prop_offsets.get(batch,0))-(prop_totals[batch]-1)*.5)*53,-35)
				prop_offsets[batch]=int(prop_offsets.get(batch,0))+1
			flights.append({"id":d.target,"node":node,"started":start,"duration":duration,"origin":origin,"custom_origin":d.has("origin"),"gift":d.get("origin",{}).get("kind","")=="gift_box","placement":placement,"direct":d.get("emblem_direct",false),"prop_index":int(d.get("prop_index",0)),"source_key":d.get("source_key",""),"prop_key":prop_key,"pile_after":d.pile_steps[i],"landed":false,"picked":false,"returned":false})
			pile_changes.append({"time":start+duration*.13,"delta":d.pile_steps[i]-(d.pile_steps[i-1] if i>0 else d.pile_before)})
		if d.returned.has(true):
			var accepted:int=d.count-d.returned.count(true)
			var shown_pile:int=d.pile_steps[accepted-1] if accepted>0 else d.pile_before
			pile_changes.append({"time":d.speech_start/1000.0,"delta":d.pile_after-shown_pile})
	if event.draws.any(func(d):return d.get("emblem_direct",false)):
		curse_pose=preload("res://scripts/curse_placement.gd").new();curse_pose.setup(self)
	if event.draws.any(func(d):return d.get("hook_return",false)):
		hook_pose=preload("res://scripts/plunder_return.gd").new();hook_pose.setup(self)
	for speech in speeches.values():speech.node.duration=speech.last-speech.first
	_process(0)
func _process(delta:float)->void:
	if clock_started>=0:elapsed=(Time.get_ticks_msec()-clock_started)/1000.0
	tick=elapsed
	if event.stage=="impact":tick=event.travel_ms/1000.0
	var pile_value:int=event.pile_before
	for change in pile_changes:
		if tick>=change.time:pile_value+=change.delta
	var pulse:=0.0
	notices.clear()
	for r in rows.values():r.order=[];r.count=r.before
	for f in flights:
		var age:float=tick-f.started
		f.landed=age>=f.duration
		f.picked=age>=f.duration*.13
		f.node.set_meta("flying",not f.landed)
		f.node.visible=age>=0
		if not f.custom_origin and age>=0 and age<f.duration*.22:pulse=maxf(pulse,sin(age/(f.duration*.22)*PI))
		if f.landed:
			rows[f.id].count+=1
			notices[f.id]={"time":f.started+f.duration}
	for id in rows:
		var r:Dictionary=rows[id]
		for c in r.cards:
			if not c.get_meta("incoming",false) or c.visible:r.order.append(c)
		for i in range(r.order.size()):
			var c:Control=r.order[i]
			var final_scale:Vector2=Vector2.ONE*Layout.hand_scale(r.friendly)
			var goal:Vector2=Layout.hand_position(id,i,r.friendly)-c.pivot_offset*(Vector2.ONE-final_scale)
			c.set_meta("goal",goal);c.z_index=40+i if c.get_meta("flying",false) else 5+i
			if not c.get_meta("flying",false):
				c.modulate.a=1
				c.rotation=0;c.scale=final_scale;c.position=goal if first_step or delta==0 else c.position.lerp(goal,1-exp(-delta*19))
				c.hidden_card=c.card.is_empty();c.queue_redraw()
		if r.label!=null:r.label.text="手牌 %d/%d"%[r.count,board.view.hand_limit]
	for f in flights:
		var c:Control=f.node
		if not c.visible or f.landed:continue
		var t:float=clampf((tick-f.started)/f.duration,0,1)
		var final_scale:float=Layout.hand_scale(rows[f.id].friendly)
		if f.gift:
			var end:Vector2=c.get_meta("goal")+c.pivot_offset
			var scale_now=lerpf(.36,.65,smoothstep(0,.3,t)) if t<.3 else lerpf(.65,final_scale,smoothstep(.3,1,t))
			c.position=flight_path(f,t,end)-c.pivot_offset;c.scale=Vector2.ONE*scale_now
			c.rotation=-.09*sin(t*PI);c.modulate.a=1;c.z_index=1 if t<.30 else 40
			c.hidden_card=c.card.is_empty();c.queue_redraw();continue
		if f.placement:
			var end:Vector2=c.get_meta("goal")+c.pivot_offset
			c.position=placement_position(f,t,end)-c.pivot_offset
			c.scale=Vector2.ONE*final_scale*lerpf(.88,1.0,smoothstep(.78,1,t));c.rotation=0
			c.hidden_card=c.card.is_empty();c.modulate.a=smoothstep(.78,.98,t);c.queue_redraw()
			continue
		var sz:float=lerpf(.82,1.03,sin(minf(t/.6,1)*PI*.5)) if t<.6 else lerpf(1.03,final_scale,smoothstep(.6,.84,t))
		if not f.custom_origin:
			# A full-sized projected back peels from the fitted stack first.
			sz*=lerpf(.84,1.0,smoothstep(0,.22,t))
			c.modulate.a=0 if t<.22 else 1
			# Once unfolded, the card remains outside the front wall. The first
			# projected portion uses the same depth in ChestDeparture below.
			c.z_index=Chest.DEPARTURE_Z-z_index+rows[f.id].order.find(c)
		var flip:=1.0;c.hidden_card=true
		if not c.card.is_empty() and t>.85:
			var u:float=clampf((t-.85)/.14,0,1);flip=maxf(.04,absf(cos(u*PI)));c.hidden_card=u<.5
		c.position=flight_path(f,t,c.get_meta("goal")+c.pivot_offset)-c.pivot_offset;c.scale=Vector2(sz*flip,sz);c.rotation=sin(t*PI)*(-.105 if rows[f.id].friendly else .10)
		c.queue_redraw()
	for id in gift_boxes:
		var arrival=0.0
		for flight in flights:
			if flight.id==id:arrival=maxf(arrival,flight.started+flight.duration)
		var age=tick+(elapsed if event.stage=="impact" else 0.)
		gift_boxes[id].present(GiftBox.dock(id,mine),1.,1-smoothstep(arrival+.16,arrival+.5,age))
	if is_instance_valid(gift_source):gift_source.motif_alpha=0.;gift_source.queue_redraw()
	if pile!=null:
		pile.pulse=pulse;pile.set_count(pile_value)
		var chest_tick:float=tick+(elapsed if event.stage=="impact" else 0.0)
		var opened:float=1.0 if chest_preopened else smoothstep(chest_first,chest_first+.22,chest_tick) if is_finite(chest_first) else 0.0
		pile.present(opened*(1.0-smoothstep(chest_last+.015,chest_last+.32,chest_tick)))
	for speech in speeches.values():speech.node.present(tick-speech.first)
	if header_count!=null:header_count.text="牌库 %d  ·  弃牌 %d"%[pile_value,board.view.discard_count]
	if curse_pose!=null:curse_pose.update()
	if hook_pose!=null:hook_pose.update()
	first_step=false;queue_redraw();chest_departure.queue_redraw()
func _exit_tree()->void:
	if hook_pose!=null:hook_pose.restore()
	if curse_pose!=null:curse_pose.restore()
	if is_instance_valid(gift_source):gift_source.motif_alpha=1.;gift_source.queue_redraw()
	for n in restored:
		if is_instance_valid(n):n.show()
	for item in layer_backups:
		if is_instance_valid(item.node):item.node.z_index=item.z
	for id in rows:
		if is_instance_valid(rows[id].label):rows[id].label.text="手牌 %d/%d"%[board.view.characters[id].hand_count,board.view.hand_limit]
	if is_instance_valid(pile):pile.pulse=0;pile.present(0);pile.set_count(board.view.deck_count)
func flight_path(f:Dictionary,t:float,end:Vector2)->Vector2:
	if f.gift:
		var lift=f.origin+Vector2(0,-132)
		if t<.30:return f.origin.lerp(lift,smoothstep(0,.30,t))
		var part=smoothstep(.30,1,t)
		return lift.lerp(end,part)+Vector2(0,-sin(part*PI)*46)
	if not f.custom_origin:return path(f.id,t,end)
	var u:float=smoothstep(0,1,t)
	return f.origin.lerp(end,u)+Vector2(0,-sin(u*PI)*75)
func placement_position(f:Dictionary,t:float,end:Vector2)->Vector2:
	return flight_path(f,clampf(t/.78,0,1),end)
func path(id:int,t:float,end:Vector2)->Vector2:
	var lift:=Layout.DECK_EXIT
	# Clear the lip before gliding outward. Keep the original exit, flight
	# duration and the entire route beyond it.
	if t<RIM_CLEAR_T:return DECK+RIM_LIFT*smoothstep(0,RIM_CLEAR_T,t)
	if t<.13:return (DECK+RIM_LIFT).lerp(lift,smoothstep(RIM_CLEAR_T,.13,t))
	var gutter:float=188+(id%3)*390
	var friendly:bool=id/3==mine
	if not friendly:gutter=Layout.hand_origin(id,false).x-12
	var key:String=str(id)+str(end)
	if not paths.has(key):
		var curve:=Curve2D.new();curve.bake_interval=4
		var direction:float=1 if friendly else -1
		curve.add_point(lift,Vector2.ZERO,Vector2(65,15*direction))
		curve.add_point(Vector2(gutter,500 if friendly else 330),Vector2(0,-75*direction),Vector2(0,90*direction))
		curve.add_point(Vector2(gutter,end.y-(30 if friendly else 35)*direction),Vector2(0,-60*direction),Vector2(0,60*direction))
		curve.add_point(end,Vector2(-clampf((end.x-gutter)*.45,8,100),0),Vector2.ZERO)
		paths[key]=curve
	var curve:Curve2D=paths[key]
	return curve.sample_baked(curve.get_baked_length()*smoothstep(.13,1,t),true)
func chest_card_corners(f:Dictionary,t:float)->PackedVector2Array:
	var corners:PackedVector2Array=pile.top_card_corners()
	var center=Vector2.ZERO
	for p in corners:center+=p/4.0
	var at:Vector2=flight_path(f,t,f.node.get_meta("goal")+f.node.pivot_offset)
	var transform:Transform2D=f.node.get_transform()
	var rectangle=[Vector2(1,0),Vector2(75,0),Vector2(75,104),Vector2(1,104)]
	for i in range(4):
		corners[i]=(at+corners[i]-center).lerp(transform*rectangle[i],smoothstep(RIM_CLEAR_T,.22,t))
	return corners
func draw_chest_departures(canvas:CanvasItem,outside:bool)->void:
	if not is_instance_valid(pile):return
	for f in flights:
		if f.custom_origin or f.returned or f.landed or tick<f.started:continue
		var t:float=clampf((tick-f.started)/f.duration,0,1)
		if t>=.22 or (t>=RIM_CLEAR_T)!=outside:continue
		pile.textured_quad(canvas,Back.texture("back"),chest_card_corners(f,t))
func _draw()->void:
	draw_chest_departures(self,false)
	for f in flights:
		if f.get("direct",false) or f.source_key=="plunder":continue
		if f.placement:
			if f.landed:continue
			var t:float=clampf((tick-f.started)/f.duration,0,1)
			var final_center:Vector2=f.node.get_meta("goal",f.origin-f.node.pivot_offset)+f.node.pivot_offset
			var at:Vector2=placement_position(f,t,final_center) if tick>=f.started else f.origin
			var reveal:float=smoothstep(.78,.98,t)
			var side:float=lerpf(70,60*Layout.hand_scale(rows[f.id].friendly),smoothstep(.35,.78,t))
			Art.draw_prop(self,f.prop_key,at,side*(1-.15*reveal),sin(t*PI)*.22,1-reveal)
			if t>.05 and t<.78:
				for j in range(6,0,-1):
					draw_line(placement_position(f,maxf(0,t-j*.012),final_center),placement_position(f,maxf(0,t-(j-1)*.012),final_center),Color("b69763")*Color(1,1,1,(1-j/7.0)*.23),2,true)
			continue
		if f.returned or f.landed or tick<f.started:continue
		var t:float=clampf((tick-f.started)/f.duration,0,1)
		var final_center:Vector2=f.node.get_meta("goal")+f.node.pivot_offset
		if t>.15 and t<.93:
			for j in range(7,0,-1):
				var a:Vector2=flight_path(f,maxf(.13,t-j*.01),final_center)
				var b:Vector2=flight_path(f,maxf(.13,t-(j-1)*.01),final_center)
				draw_line(a,b,Color("d8b87c")*Color(1,1,1,(1-j/8.0)*.30),2.2,true)
	for id in notices:
		var age:float=tick-notices[id].time
		if age>1.0:continue
		var alpha:float=(1-smoothstep(.42,1.0,age))
		var tint:Color=BLUE if id/3==mine else RED
		var at:Vector2=Layout.hand_origin(id,id/3==mine)+Vector2(10,-8)
		draw_string(get_theme_font("font"),at+Vector2(0,-age*9),"+1",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(tint,alpha))
		for c in rows[id].cards:
			if c.get_meta("flying",false):continue
			# Only the most recently landed card receives the brief rim accent.
			if not flights.is_empty() and flights.any(func(f):return f.node==c and f.landed and absf(f.started+f.duration-(tick-age))<.025):
				var rect:=Rect2(c.position+c.pivot_offset*(Vector2.ONE-c.scale),c.size*c.scale)
				draw_rect(rect.grow(3),Color(tint,alpha*.65),false,2.0,true)
