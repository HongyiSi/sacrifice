extends "res://scripts/effect_animation.gd"
## The reaction uses the actual hand card; only the accepted amulet is exposed.
const Layout=preload("res://scripts/board_layout.gd")
const Card=preload("res://scripts/card_widget.gd")
const DISCARD=Vector2(1280,533)
var friendly:=true
var slot:=0
var actor:=0
var ghost:Control
var original_card:Dictionary={}
var original_hidden:=false
var hand_source:Control
var reflow:Array=[]
var count_label:Label
var count_text:=""
var remaining_count:=0

func find_meta(node:Node,key:String,value):
	if node.has_meta(key) and node.get_meta(key)==value:return node
	for child in node.get_children():
		var found=find_meta(child,key,value)
		if found!=null:return found
	return null

func prepare_hand(board)->void:
	actor=event.action.actor;friendly=actor/3==mine
	slot=int(event.owner_slot if friendly else event.hand_index)
	var fan=find_meta(board.canvas,"hand_actor" if friendly else "enemy_hand_actor",actor)
	if event.stage!="discard":
		if friendly:hand_source=find_meta(board.canvas,"card_id",event.action.card)
		elif fan!=null:
			var cards:Array=fan.get_children().filter(func(c):return c is Card)
			if slot>=0 and slot<cards.size():hand_source=cards[slot]
		if hand_source!=null:
			original_card=hand_source.card;original_hidden=hand_source.hidden_card
			hand_source.card=board.view.catalog[event.action.card].duplicate(true)
			hand_source.hidden_card=false;hand_source.queue_redraw()
			source_widget=hand_source
		return
	# The rules remove the amulet only after its complete burn/return effect.
	# Preserve the old gap while it visibly leaves for the discard pile.
	ghost=Card.new();ghost.card=board.view.catalog[event.action.card].duplicate(true)
	ghost.disabled=true;ghost.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ghost.priority_bonus=board.view.characters[actor].priority_bonus
	add_child(ghost);ghost.size=Layout.CARD_SIZE;ghost.set_process(false)
	source_widget=ghost
	if fan!=null:
		var index:=0
		for card in fan.get_children():
			if not card is Card:continue
			if index>=slot:reflow.append({"node":card,"after":card.position,"before":Layout.hand_slot(index+1,friendly)})
			index+=1
	count_label=find_meta(board.canvas,"hand_count_actor",actor)
	if count_label!=null:count_text=count_label.text
	remaining_count=board.view.characters[actor].hand_count

func _ready()->void:
	if event.stage=="discard":
		mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=20
	else:super._ready()

func _process(delta:float)->void:
	if event.stage!="discard":
		super._process(delta);return
	if clock_started>=0:elapsed=(Time.get_ticks_msec()-clock_started)/1000.0
	else:elapsed+=delta
	var t:=clampf(elapsed/(StrikeStyles.duration(event)/1000.0),0,1)
	var fly:=smoothstep(.08,1,t)
	var start:=Layout.hand_position(actor,slot,friendly)+Layout.CARD_SIZE*Layout.hand_scale(friendly)/2
	var at:=start.lerp(DISCARD,fly)+Vector2(0,-sin(fly*PI)*42)
	if is_instance_valid(ghost):
		ghost.scale=Vector2.ONE*lerpf(Layout.hand_scale(friendly),.42,fly)
		ghost.position=at-Layout.CARD_SIZE*ghost.scale/2
		ghost.modulate.a=1-smoothstep(.88,1,t)
	for item in reflow:
		if is_instance_valid(item.node):item.node.position=item.before.lerp(item.after,smoothstep(.45,.95,t))
	if is_instance_valid(count_label):count_label.text="手牌 %d/%d"%[remaining_count+(1 if t<.9 else 0),Layout.SLOTS]

func _draw()->void:
	if event.stage!="discard":super._draw()

func _exit_tree()->void:
	super._exit_tree()
	if is_instance_valid(hand_source):
		hand_source.card=original_card;hand_source.hidden_card=original_hidden;hand_source.queue_redraw()
	for item in reflow:
		if is_instance_valid(item.node):item.node.position=item.after
	if is_instance_valid(count_label):count_label.text=count_text
