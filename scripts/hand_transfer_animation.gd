extends Control
## One public resolving card becomes one hand card, on the shared animation clock.
const Layout=preload("res://scripts/board_layout.gd")
const Card=preload("res://scripts/card_widget.gd")
const Styles=preload("res://scripts/strike_styles.gd")
const Art=preload("res://scripts/cinema/atlas.gd")
var event:Dictionary={}
var clock_started:=-1
var elapsed:=0.0
var flying:Control
var incoming:Control
var source_card:Control
var source:=Vector2.ZERO
var destination:=Vector2.ZERO
var source_scale:=Vector2(1.1616,1.1616)
var final_scale:=Vector2.ONE
var friendly:=true
var known:=true
var accepted:=true
var reflow:Array=[]
var count_label:Label
var count_text:=""
var face:Dictionary={}
var hand_face:Dictionary={}
var hand_bonus:=0
var speech:Control

func find_meta(node:Node,key:String,value):
	if node.has_meta(key) and node.get_meta(key)==value:return node
	for child in node.get_children():
		var found=find_meta(child,key,value)
		if found!=null:return found
	return null

func initialize(board,started:int)->void:
	event=board.view.animation;clock_started=started
	size=Vector2(1440,960);mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=80
	var target:int=event.recipient
	accepted=event.get("accepted",true)
	friendly=target/3==board.mine;known=friendly or board.view.omniscient
	final_scale=Vector2.ONE*Layout.hand_scale(friendly)
	var slot:int=event.get("owner_slot",event.hand_index) if known else event.hand_index
	destination=Layout.hand_position(target,slot,friendly)+Layout.CARD_SIZE*final_scale/2
	if not accepted:destination=Layout.hand_origin(target,friendly)+Vector2(Layout.hand_size(friendly).x/2,Layout.hand_size(friendly).y+30 if not friendly else -35)
	source_card=board._active_widget()
	if source_card!=null:
		face=source_card.card.duplicate(true)
		source=board._board_rect(source_card).get_center()
		source_scale=source_card.scale
		var focus:Dictionary=board.ui.resolution_focus
		if not focus.is_empty():
			source_scale=focus.scale;source=focus.destination+Layout.CARD_SIZE*source_scale/2
		source_card.hide()
		if is_instance_valid(source_card.status_label):source_card.status_label.hide()
	else:
		face=board.view.active_card.duplicate(true)
		source=Vector2(Layout.column_x(event.action.actor)+160,435 if event.action.actor/3==board.mine else 365)
	var fan=find_meta(board.canvas,"hand_actor" if friendly else "enemy_hand_actor",target)
	if fan!=null and accepted:
		var cards:Array=fan.get_children().filter(func(c):return c is Card)
		var before_index:=0
		for index in range(cards.size()):
			var card:Control=cards[index]
			var is_incoming:bool=card.card.get("id",-1)==event.get("incoming_card",-2) if known else index==event.hand_index
			if is_incoming:
				incoming=card;card.hide()
				hand_face=card.card.duplicate(true);hand_bonus=card.priority_bonus
			else:
				reflow.append({"node":card,"before":Layout.hand_slot(before_index,friendly),"after":card.position})
				before_index+=1
	flying=Card.new();flying.card=face;flying.death=event.action.get("death",false)
	flying.disabled=true;flying.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(flying);flying.size=Layout.CARD_SIZE;flying.pivot_offset=Layout.CARD_SIZE/2;flying.set_process(false)
	count_label=find_meta(board.canvas,"hand_count_actor",target)
	if count_label!=null:count_text=count_label.text
	if not accepted:
		speech=preload("res://scripts/pawn_speech.gd").new();add_child(speech)
		var speaker:int=event.action.actor
		var own:bool=speaker/3==board.mine
		speech.configure(speaker,"它的手牌满了！" if speaker!=target else "我的手牌满了！",Layout.pawn_rect(speaker,own),Color("355f89" if own else "a95138"),1.9)
	_process(0)

func progress()->float:
	return 1.0 if event.stage=="impact" else clampf(elapsed/(Styles.duration(event)/1000.0),0,1)

func position_at(t:float)->Vector2:
	var eased:=smoothstep(0,.78,t)
	return source.lerp(destination,eased)+Vector2(0,-sin(eased*PI)*58)

func _process(delta:float)->void:
	if clock_started>=0:elapsed=(Time.get_ticks_msec()-clock_started)/1000.0
	else:elapsed+=delta
	if flying==null:return
	if not accepted:
		flying.hide();flying.modulate.a=0
		speech.present(elapsed if event.stage=="travel" else 1.9)
		if is_instance_valid(count_label):count_label.text="手牌 %d/%d"%[event.before_count,Layout.SLOTS]
		return
	var t:=progress()
	flying.hidden_card=not known and t>=.78
	flying.modulate.a=smoothstep(.78,.98,t)
	flying.scale=final_scale*lerpf(.88,1.0,smoothstep(.78,1,t))
	flying.position=position_at(t)-flying.pivot_offset
	flying.rotation=0
	flying.card=hand_face if known else face
	flying.death=false
	flying.priority_bonus=hand_bonus
	flying.queue_redraw()
	for item in reflow:
		if is_instance_valid(item.node):item.node.position=item.before.lerp(item.after,smoothstep(.35,.96,t))
	if is_instance_valid(count_label):count_label.text="手牌 %d/%d"%[event.before_count+(1 if accepted and t>=1 else 0),Layout.SLOTS]
	queue_redraw()

func _draw()->void:
	if flying==null:return
	if not accepted:return
	var t:=progress()
	var reveal:=smoothstep(.78,.98,t)
	Art.draw_prop(self,str(face.get("key",event.get("style",""))),position_at(t),lerpf(88,60*final_scale.x,smoothstep(.2,.78,t))*(1-.15*reveal),sin(t*PI)*.22,1-reveal)
	if t>.04 and t<.78:
		for i in range(6,0,-1):
			draw_line(position_at(maxf(0,t-i*.014)),position_at(maxf(0,t-(i-1)*.014)),Color("d8b87c")*Color(1,1,1,(1-i/7.0)*.24),2,true)
	if accepted and event.stage=="impact":
		var alpha:=1-clampf(elapsed/(event.impact_ms/1000.0),0,1)
		draw_rect(Rect2(destination-Layout.CARD_SIZE*final_scale/2,Layout.CARD_SIZE*final_scale).grow(3),Color("d8b87c")*Color(1,1,1,alpha*.7),false,2,true)

func _exit_tree()->void:
	if is_instance_valid(incoming):incoming.show()
	for item in reflow:
		if is_instance_valid(item.node):item.node.position=item.after
	if is_instance_valid(count_label):count_label.text=count_text
