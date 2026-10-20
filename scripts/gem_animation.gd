extends Control
## Native public event adapter for the approved six-gem visual.
const Layout=preload("res://scripts/board_layout.gd")
const Card=preload("res://scripts/card_widget.gd")
const Timing=preload("res://scripts/gem_timing.gd")
const Styles=preload("res://scripts/strike_styles.gd")
var board
var event:Dictionary={}
var clock_event:Dictionary={}
var clock_started:=-1
var elapsed:=0.0
var source_card:Control
var source:=Vector2.ZERO
var source_side:=46.0
var source_rect:=Rect2()
var original_motif:=1.0
var actor:=0
var slot:=0
var friendly:=true
var visual
var ghost:Control
var reflow:Array=[]
var count_label:Label
var count_text:=""
var hand_count:=0
func find_meta(node:Node,key:String,value):
	if node.has_meta(key) and node.get_meta(key)==value:return node
	for child in node.get_children():
		var found=find_meta(child,key,value)
		if found!=null:return found
	return null
func initialize(table,started:int)->void:
	board=table;clock_event=board.view.animation;event=clock_event.get("gem_overlay",clock_event)
	clock_started=started;actor=event.action.actor;friendly=actor/3==board.mine
	size=Vector2(1440,960);mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=85
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if event.kind=="gem_trigger":
		slot=int(event.get("owner_slot",0) if friendly else event.get("hand_index",0))
		source_side=46*Layout.hand_scale(friendly)
		source_rect=Rect2(Layout.hand_position(actor,slot,friendly),Layout.CARD_SIZE*Layout.hand_scale(friendly))
		source=source_rect.position+Vector2(38,48)*Layout.hand_scale(friendly)
		var fan=find_meta(board.canvas,"hand_actor" if friendly else "enemy_hand_actor",actor)
		if event.stage=="discard" and event.get("consumed",false):
			if fan!=null:
				var index:=0
				for card in fan.get_children():
					if not card is Card:continue
					if index>=slot:reflow.append({"node":card,"after":card.position,"before":Layout.hand_slot(index+1,friendly)})
					index+=1
			ghost=Card.new();ghost.card=board.view.catalog[event.get("gem_card",event.action.card)].duplicate(true)
			ghost.hidden_card=not friendly and not board.view.omniscient;ghost.priority_bonus=board.view.characters[actor].priority_bonus
			ghost.disabled=true;ghost.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(ghost)
			ghost.size=Layout.CARD_SIZE;ghost.set_process(false)
			count_label=find_meta(board.canvas,"hand_count_actor",actor)
			if count_label!=null:count_text=count_label.text
			hand_count=board.view.characters[actor].hand_count
		else:
			# During draw the original fan is hidden; follow its actual animated
			# replacement so the gem returns to the correct reflowed card.
			var draw=find_meta(board.canvas,"draw_animation",clock_event.id)
			if draw!=null and draw.rows.has(actor):
				var cards:Array=draw.rows[actor].cards
				if friendly:
					for card in cards:
						if card.card.get("id",-1)==event.get("gem_card",-2):source_card=card;break
				else:
					var old_cards=cards.filter(func(c):return not c.get_meta("incoming",false))
					if slot<old_cards.size():source_card=old_cards[slot]
			elif friendly:source_card=find_meta(board.canvas,"card_id",event.get("gem_card",-2))
			elif fan!=null:
				var cards=fan.get_children().filter(func(c):return c is Card)
				if slot<cards.size():source_card=cards[slot]
	else:
		source_card=board._active_widget()
		source=Layout.pawn_center(actor,friendly)+Vector2(65,-20)
	if is_instance_valid(source_card):original_motif=source_card.motif_alpha;_locate_source()
	if ghost==null:
		visual=preload("res://scripts/gem_visual.gd").new();add_child(visual)
		visual.configure(board,event.style,actor,source,source_side)
		visual.hp_gain=event.get("hp_gain",0)
	_process(0)
func _locate_source()->void:
	var tr:Transform2D=get_global_transform().affine_inverse()*source_card.get_global_transform()
	source=tr*source_card.emblem_center()
	source_side=tr.basis_xform(Vector2(minf(source_card.size.x-25,46),0)).length()
func _process(delta:float)->void:
	if clock_started>=0:elapsed=maxf(0,(Time.get_ticks_msec()-clock_started)/1000.0)
	else:elapsed+=delta
	if is_instance_valid(visual):
		var age=Timing.age(clock_event,elapsed)
		if is_instance_valid(source_card):
			_locate_source();visual.initial_source=source;visual.source_side=source_side
			source_card.motif_alpha=0.0 if age>=.22 and age<visual.return_end else original_motif
			source_card.queue_redraw()
		visual.present(age)
	if is_instance_valid(ghost):
		var u=clampf(elapsed/(Styles.duration(event)/1000.0),0.,1.)
		var fly=smoothstep(.12,1.,u)
		var at=source_rect.get_center().lerp(Vector2(1280,533),fly)+Vector2(0,-sin(fly*PI)*42)
		ghost.scale=Vector2.ONE*lerpf(Layout.hand_scale(friendly),.42,fly)
		ghost.position=at-Layout.CARD_SIZE*ghost.scale/2
		ghost.modulate.a=1-smoothstep(.88,1,u)
		for item in reflow:
			if is_instance_valid(item.node):item.node.position=item.before.lerp(item.after,smoothstep(.60,1,u))
		if count_label!=null:count_label.text="手牌 %d/%d"%[hand_count+(1 if u<.9 else 0),Layout.SLOTS]
func _exit_tree()->void:
	if is_instance_valid(source_card):source_card.motif_alpha=original_motif;source_card.queue_redraw()
	for item in reflow:
		if is_instance_valid(item.node):item.node.position=item.after
	if is_instance_valid(count_label):count_label.text=count_text
