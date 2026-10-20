extends Control
const Layout=preload("res://scripts/board_layout.gd")
const Card=preload("res://scripts/card_widget.gd")
const Symbols=preload("res://scripts/art_symbols.gd")
const Timing=preload("res://scripts/blade_volley_timing.gd")
const TIP=-PI/2
const Art=preload("res://scripts/cinema/atlas.gd")
const Strokes=preload("res://scripts/art_ui/effect_strokes.gd")
const INK="995461"
const GLOW=Color("ed9bad")
var event:Dictionary={}
var clock_started:=-1
var elapsed:=0.0
var tick:=0.0
var actor:=0
var mine:=0
var friendly:=true
var preparing:=false
var source_hand:Dictionary={}
var slots:Array=[]
var cards:Array=[]
var hand:Control
var count_label:Label
var count_text:=""
var destinations:Array=[]
var sprites:Dictionary={}
var brush:RefCounted

func find_meta(node:Node,key:String,value):
	if node.has_meta(key) and node.get_meta(key)==value:return node
	for child in node.get_children():
		var found=find_meta(child,key,value)
		if found!=null:return found
	return null

func initialize(board,started:int,preview:bool=false)->void:
	preparing=preview;mine=board.mine;clock_started=started
	event=board.view.animation if not preparing else {"style":"cards_to_blades","color":"ed9bad","hits":[]}
	var action:Dictionary=board.view.active_action
	actor=action.actor;friendly=actor/3==mine
	source_hand=action.blade_source if preparing else event.source_hand
	var known:bool=source_hand.has("owner_hand")
	slots=source_hand.owner_slots if known and friendly else source_hand.slots
	var faces:Array=source_hand.get("owner_hand",[]).duplicate()
	if known and not friendly:
		# Omniscience exposes faces, but the opponent's row keeps insertion order.
		faces.resize(source_hand.count);faces.fill(0)
		for i in range(slots.size()):faces[slots[i]]=source_hand.owner_hand[source_hand.owner_slots[i]]
		var kept:Array=board.view.characters[actor].hand.duplicate()
		for i in range(faces.size()):
			if faces[i]==0:faces[i]=kept.pop_front()
	destinations=action.get("blade_targets",[]) if preparing else event.destinations
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	size=Vector2(1440,960);mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=80
	hand=find_meta(board.canvas,"hand_actor" if friendly else "enemy_hand_actor",actor)
	if hand!=null:hand.hide()
	for i in range(source_hand.count):
		var c=Card.new()
		c.card=board.view.catalog[faces[i]].duplicate(true) if known else {}
		c.hidden_card=not known;c.priority_bonus=board.view.characters[actor].priority_bonus
		c.disabled=true;c.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(c);c.size=Layout.CARD_SIZE;c.scale=Vector2.ONE*Layout.hand_scale(friendly)
		c.position=Layout.hand_position(actor,i,friendly);c.set_process(false);cards.append(c)
	count_label=find_meta(board.canvas,"hand_count_actor",actor)
	if count_label!=null:count_text=count_label.text
	for node in board.canvas.get_children():
		if node.has_meta("knight_id"):
			var sprite=node.get_child(0)
			sprites[node.get_meta("knight_id")]={"node":sprite,"position":sprite.position,"color":sprite.modulate}
	brush=preload("res://scripts/strike_effects.gd").new(self)
	_process(0)

func source_at(index:int)->Vector2:
	return Layout.hand_position(actor,slots[index],friendly)+Layout.CARD_SIZE*Layout.hand_scale(friendly)/2
func target_at(index:int)->Vector2:
	var target:int=destinations[index]
	return Layout.pawn_center(target,target/3==mine)
func blade_position(index:int,age:float)->Vector2:
	var from:=source_at(index)
	var raised:=from+Vector2(0,-24)
	if age<Timing.MORPH_MS:return from.lerp(raised,smoothstep(0,Timing.MORPH_MS,age))
	var u:=clampf((age-Timing.MORPH_MS)/Timing.FLIGHT_MS,0,1)
	return raised.lerp(target_at(index),u)+Vector2(0,-sin(u*PI)*32)

func _process(delta:float)->void:
	if clock_started>=0:elapsed=(Time.get_ticks_msec()-clock_started)/1000.0
	else:elapsed+=delta
	if cards.is_empty():return
	tick=-1 if preparing else event.timeline_ms+minf(elapsed*1000,event.slice_ms)
	var departed:=0
	var survivors:=0
	var reflow:=0.0 if preparing else smoothstep((slots.size()-1)*Timing.STEP_MS+Timing.MORPH_MS,(slots.size()-1)*Timing.STEP_MS+Timing.MORPH_MS+280,tick)
	for i in range(cards.size()):
		var c:Control=cards[i]
		var blade:int=slots.find(i)
		if blade<0:
			c.position=Layout.hand_position(actor,i,friendly).lerp(Layout.hand_position(actor,survivors,friendly),reflow)
			survivors+=1;continue
		var age:float=tick-blade*Timing.STEP_MS
		c.visible=age<Timing.MORPH_MS
		c.modulate.a=1-smoothstep(0,Timing.MORPH_MS,age)
		c.position=Layout.hand_position(actor,i,friendly)+Vector2(0,-24*smoothstep(0,Timing.MORPH_MS,age))
		if age>=Timing.MORPH_MS:departed+=1
	if count_label!=null:count_label.text="手牌 %d/%d"%[source_hand.count-departed,Layout.SLOTS]
	_reset_sprites()
	for index in range(event.hits.size()):
		var hit:Dictionary=event.hits[index]
		var age:float=(tick-Timing.arrival(index))/Timing.TAIL_MS
		if age<0 or age>1 or hit.amount==0 or not sprites.has(hit.id):continue
		var saved:Dictionary=sprites[hit.id]
		saved.node.position=saved.position+Vector2(sin(age*18)*4*(1-age),0)
		saved.node.modulate=saved.color.lerp(Color(1,.66,.61),.5*(1-age))
	queue_redraw()

func _draw()->void:
	if cards.is_empty():return
	if preparing:
		var counts:Dictionary={}
		for target in destinations:counts[target]=int(counts.get(target,0))+1
		for target in counts:
			var at:=Layout.pawn_center(target,target/3==mine)+Vector2(50,-30)
			draw_circle(at,15,Color("f1e3c8"));draw_arc(at,15,0,TAU,32,GLOW,2,true)
			draw_string(get_theme_font("font"),at+Vector2(-8,6),str(counts[target]),HORIZONTAL_ALIGNMENT_CENTER,16,18,Color(INK))
		return
	for i in range(slots.size()):
		var age:float=tick-i*Timing.STEP_MS
		if age<0 or age>=Timing.MORPH_MS+Timing.FLIGHT_MS:continue
		var point:=blade_position(i,age)
		var angle:float=(target_at(i)-(source_at(i)+Vector2(0,-24))).angle()-TIP
		angle=lerp_angle(0,angle,smoothstep(0,Timing.MORPH_MS,age))
		var alpha:=smoothstep(0,Timing.MORPH_MS,age)
		if age>=Timing.MORPH_MS:
			var points=PackedVector2Array()
			for j in range(33):points.append(blade_position(i,maxf(Timing.MORPH_MS,age-(32-j)*3)))
			Strokes.ribbon(self,points,12,GLOW,.8)
		var side=lerpf(46*Layout.hand_scale(friendly),91,alpha)
		Art.draw_prop(self,"triple_strike",point,side,angle,alpha)

	for i in range(event.hits.size()):
		var t:float=(tick-Timing.arrival(i))/Timing.TAIL_MS
		if t<0 or t>=1:continue
		var hit:Dictionary=event.hits[i]
		var at:=target_at(i)
		Strokes.slash(self,at,-.65,83,(tick-Timing.arrival(i))/1000.0,GLOW)
		var label:="-%d"%hit.amount if not hit.pain else "苦肉"
		if hit.revived:label+=" · 复活"
		var baseline:=at+Vector2(-24,-67-14*t)
		draw_string_outline(get_theme_font("font"),baseline,label,HORIZONTAL_ALIGNMENT_LEFT,-1,22,3,Color("493c2a")*Color(1,1,1,1-t))
		draw_string(get_theme_font("font"),baseline,label,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("fff1d5")*Color(1,1,1,1-t))

func _reset_sprites()->void:
	for saved in sprites.values():
		if is_instance_valid(saved.node):saved.node.position=saved.position;saved.node.modulate=saved.color
func _exit_tree()->void:
	if is_instance_valid(hand):hand.show()
	if is_instance_valid(count_label):count_label.text=count_text
	_reset_sprites()
