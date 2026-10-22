extends RefCounted
const Chrome=preload("res://scripts/art_ui/ui_chrome.gd")
const Layout = preload("res://scripts/board_layout.gd")
const Card = preload("res://scripts/card_widget.gd")
const Symbols = preload("res://scripts/art_symbols.gd")
const StatusAnimation = preload("res://scripts/status_animation.gd")
const CardReveal = preload("res://scripts/card_reveal.gd")
const PlanningFlight = preload("res://scripts/planning_flight.gd")
const PAPER := Color("f1e3c8")
const INK := Color("3e332c")
const SOFT := Color("806c53")
const BLUE := Color("355f89")
const RED := Color("a95138")
const EDGE := Color("ac8c5c")
const DEAD_HAND_TINT := Color(0.55,0.55,0.55,1.0)
const BASE := Vector2(1440,960)
static var textures: Dictionary = {}
var ui
var canvas: Control
var view: Dictionary
var mine: int
var card_hover: Control

func _init(controller) -> void:
	ui = controller

static func texture(name: String) -> Texture2D:
	if textures.has(name): return textures[name]
	var path := "res://assets/art/" + name + ".png"
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path): return null
	# Prefer imported textures for exports; raw PNG fallback supports an older
	# local import cache without requiring the user to open the editor first.
	var full: Texture2D
	if ResourceLoader.exists(path): full = load(path)
	if full == null: full = ImageTexture.create_from_image(Image.load_from_file(path))
	if name == "table": textures[name] = full
	else:
		var img := full.get_image()
		var atlas := AtlasTexture.new()
		atlas.atlas = full
		if img.is_compressed():img.decompress()
		atlas.region = img.get_used_rect()
		textures[name] = atlas
	return textures[name]

func build(parent: Control) -> void:
	view = ui.session.state
	mine = ui.session.team
	var deity_times:Dictionary=ui.get_meta("divinity_times",{})
	var deity_keys:Array=[]
	for c in view.characters:
		if c.ongoing_effects.any(func(s):return s.key=="divinity" and not s.dormant):
			var key:="%d/%d"%[view.match,c.id];deity_keys.append(key)
			if not deity_times.has(key):deity_times[key]=Time.get_ticks_msec()
	for key in deity_times.keys():
		if not deity_keys.has(key):deity_times.erase(key)
	ui.set_meta("divinity_times",deity_times)
	canvas = Control.new()
	canvas.size = BASE
	canvas.scale = ui.size / BASE
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(canvas)
	_header()
	var pile = preload("res://scripts/draw_pile.gd").new()
	pile.count = view.deck_count
	_place(pile,canvas,Layout.DECK_RECT)
	for slot in range(3):
		_character((1-mine)*3+slot,slot,false)
		_character(mine*3+slot,slot,true)
	_resolution_animation()
	_action_bar()
	if view.phase == "selecting" and view.input.team == mine and view.input.type not in ["inspect"]:
		_selection_overlay()
	elif view.phase == "selecting" and view.input.team == mine and view.input.type == "inspect":
		_inspection()
	_early_end_button()
	_hand_preview()
	_planning_flights()
	_effect_animation()
	preload("res://scripts/defense_guard.gd").install(self)
	if view.phase=="selecting" and view.input.get("type","")=="search":
		canvas.add_child(preload("res://scripts/search_compass_wait.gd").new())
	preload("res://scripts/ordinary_install.gd").install(self)
	_phase_announcement()
	_restore_card_hover()

func _place(node: Control, parent: Node, rect: Rect2) -> Control:
	parent.add_child(node)
	node.position = rect.position; node.size = rect.size
	return node

func _text(parent: Node, value: String, rect: Rect2, size_px: int = 18, color: Color = INK, centered: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size",size_px)
	label.add_theme_color_override("font_color",color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_place(label,parent,rect)
	return label

func _input_heading(parent: Node, rect: Rect2, size_px: int = 20, override_text: String = "") -> RichTextLabel:
	var heading := RichTextLabel.new()
	heading.bbcode_enabled = true
	heading.scroll_active = false
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_font_size_override("normal_font_size",size_px)
	heading.add_theme_color_override("default_color",INK)
	var description: String = view.input.description if override_text.is_empty() else override_text
	var target: int = view.input.get("target",-1)
	if target >= 0:
		var c: Dictionary = view.characters[target]
		var own: bool = c.team == mine
		var name_with_team: String = ("我方 · " if own else "敌方 · ")+c.name
		description = description.replace(c.name,"[color=#%s]%s[/color]" % [(BLUE if own else RED).to_html(false),name_with_team])
		heading.set_meta("target_team",int(c.team))
		heading.set_meta("target_name",name_with_team)
		heading.set_meta("target_color",BLUE if own else RED)
	heading.text = description
	heading.set_meta("input_heading",true)
	_place(heading,parent,rect)
	return heading

func _box(rect: Rect2, fill: Color = PAPER, border: Color = EDGE, parent: Node = null) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = ui._box(fill,border,8,0)
	style.shadow_color = Color(0.2,0.13,0.08,0.16)
	style.shadow_size = 3; style.shadow_offset = Vector2(1,3)
	panel.add_theme_stylebox_override("panel",Chrome.panel_style())
	_place(panel,canvas if parent == null else parent,rect)
	return panel

func _button(parent: Node, value: String, rect: Rect2, callback: Callable, disabled: bool = false, primary: bool = false) -> Button:
	var b: Button = ui._button(parent,value,callback,disabled,primary)
	_small_button(b)
	b.custom_minimum_size = Vector2.ZERO
	b.position = rect.position; b.size = rect.size
	b.add_theme_font_size_override("font_size",16)
	return b

func _small_button(b: Button) -> void:
	for state in ["normal","disabled","hover","pressed","focus"]:
		var style: StyleBox = b.get_theme_stylebox(state).duplicate()
		style.content_margin_left = 8; style.content_margin_right = 8
		style.content_margin_top = 2; style.content_margin_bottom = 2
		b.add_theme_stylebox_override(state,style)

func _header() -> void:
	Chrome.header(self)

func _character(id: int, slot: int, friendly: bool) -> void:
	var c: Dictionary = view.characters[id]
	var x := 157.0 + slot*390.0
	var pawn_rect := Layout.pawn_rect(id,friendly)
	var y := pawn_rect.position.y
	var color := BLUE if friendly else RED
	var actor: bool = view.active_action.get("actor",-1) == id
	var legal: bool = view.phase in ["targeting","death_targeting"] and view.input.team == mine and view.input.options.has(id) and not ui.submitting
	var title: String = c.name
	if c.hp == 0: title += " · 阵亡"
	elif actor: title += " · 行动中"
	elif view.phase == "planning" and view.ready[c.team]: title += " · 已锁定"
	Chrome.nameplate(self,title,Rect2(pawn_rect.get_center().x-95,pawn_rect.position.y-29,190,25),friendly,id)
	if not friendly: _enemy_hand(id,x)
	var target := Button.new()
	target.disabled = not legal
	target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if legal else Control.CURSOR_ARROW
	for state in ["normal","disabled","hover","pressed","focus"]:
		var style := StyleBoxEmpty.new()
		target.add_theme_stylebox_override(state,style)
	_place(target,canvas,pawn_rect)
	target.set_meta("target_character_id",id)
	target.set_meta("knight_id",id)
	target.pressed.connect(func(): ui._choose_target(id,int(view.revision)))
	# Team identity is stable; only layout and ally/enemy labels follow the viewer.
	var names: Array = ["blue_sword","blue_shield","blue_mage"] if c.team == 0 else ["red_spear","red_axe","red_archer"]
	var sprite := TextureRect.new()
	sprite.texture = texture(names[slot])
	sprite.set_meta("pawn_art",names[slot])
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_place(sprite,target,Rect2(3,0,pawn_rect.size.x-6,125))
	if c.hp == 0: sprite.modulate = Color(0.57,0.59,0.67,0.6)
	if c.ongoing_effects.any(func(s):return s.key=="divinity" and not s.dormant):
		var deity=preload("res://scripts/divinity_pose.gd").new()
		target.add_child(deity);deity.size=pawn_rect.size;deity.set_meta("divinity_actor",id)
		deity.configure(sprite,c.team == 1,names[slot],ui.get_meta("divinity_times")["%d/%d"%[view.match,id]])
	preload("res://scripts/pain_rose.gd").install(self,c,target,sprite)
	preload("res://scripts/persistent_death_props.gd").install(self,c,target,sprite)
	if legal:
		var outline = preload("res://scripts/target_outline.gd").new()
		target.add_child(outline)
		outline.set_meta("target_outline",id)
		outline.initialize(target,sprite)
	Chrome.health_and_status(self,c,pawn_rect,friendly)
	var descriptions: Array = []
	for status in c.get("ongoing_effects",[]): descriptions.append(StatusAnimation.description(status))
	target.tooltip_text="\n".join(descriptions)

	_deaths(id,x,friendly)
	_played(id,x,friendly)
	if friendly: _hand(id,x)

func _fan_positions(count: int, width: float, card_width: float) -> Array:
	var result: Array = []
	if count <= 0: return result
	var step := minf(card_width+7.0,(width-card_width)/maxi(1,count-1))
	var start := (width-card_width-step*(count-1))/2.0
	for i in range(count): result.append(start+i*step)
	return result

func _hand_slots(id: int, friendly: bool) -> void:
	var slots = preload("res://scripts/hand_slots.gd").new()
	slots.friendly = friendly
	slots.set_meta("hand_slots_actor",id)
	_place(slots,canvas,Rect2(Layout.hand_origin(id,friendly),Layout.hand_size(friendly)))

func _enemy_hand(id: int, x: float) -> void:
	var c: Dictionary = view.characters[id]
	var count: int = c.hand_count
	_hand_slots(id,false)
	var fan := Control.new()
	fan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fan.set_meta("enemy_hand_actor",id)
	_place(fan,canvas,Rect2(Layout.hand_origin(id,false),Layout.hand_size(false)))
	for i in range(count):
		var visible: bool = view.omniscient and i < c.hand.size()
		var info: Dictionary = view.catalog[c.hand[i]] if visible else {}
		var card = _card(fan,info,false,not visible)
		if c.hp <= 0: card.self_modulate = DEAD_HAND_TINT
		card.scale = Vector2.ONE*Layout.hand_scale(false)
		card.position = Layout.hand_slot(i,false)
		card.set_meta("hand_slot",i)
		card.priority_bonus = c.priority_bonus
		card.disabled = not visible
		if visible:
			card.set_meta("inspect_key","enemy_%d_%d" % [id,info.id])

func _deaths(id: int, x: float, friendly: bool) -> void:
	var c: Dictionary = view.characters[id]
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_meta("death_fan_actor",id)
	# Spread into the available side lane, keeping the existing card scale.
	var width := 132.0 if friendly else 120.0
	_place(holder,canvas,Rect2(Layout.death_origin(id,friendly),Vector2(width,108 if friendly else 54)))
	var factor := 1.0 if friendly else 0.5
	var slots: Array = c.get("death_slots",[])
	var positions := _fan_positions(slots.size(),width,76*factor)
	for i in range(slots.size()):
		var known: bool = int(slots[i].card)>0
		var info: Dictionary = view.death_catalog[slots[i].card] if known else {}
		var card = _card(holder,info,true,not known)
		card.scale = Vector2(factor,factor)
		card.position = Vector2(positions[i],0)
		card.priority_bonus = c.priority_bonus
		card.disabled = not known
		if slots[i].triggered:
			card.action_status="triggered"
			card.set_meta("triggered_death_id",int(slots[i].card))
		if known:
			card.set_meta("inspect_key","death_%d_%d" % [id,info.id])
			if not slots[i].triggered: card.set_meta("death_card_id",int(slots[i].card))
	if friendly:
		if slots.is_empty(): _text(holder,"—",Rect2(0,20,width,52),24,SOFT,true)

func _hand(id: int, x: float) -> void:
	var c: Dictionary = view.characters[id]
	var planned: Array = ui._selected_cards(id) if view.phase == "planning" else []
	var ids: Array = c.hand.filter(func(card_id): return not planned.has(card_id))
	ids.sort_custom(func(a,b):
		var ca: Dictionary = view.catalog[a]; var cb: Dictionary = view.catalog[b]
		return ca.main > cb.main if ca.main != cb.main else ca.secondary > cb.secondary)
	_hand_slots(id,true)
	var fan := Control.new()
	fan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fan.set_meta("hand_actor",id)
	_place(fan,canvas,Rect2(Layout.hand_origin(id,true),Layout.hand_size(true)))
	for i in range(ids.size()):
		var card_id: int = ids[i]
		var b = _card(fan,view.catalog[card_id])
		if c.hp <= 0: b.self_modulate = DEAD_HAND_TINT
		b.position = Layout.hand_slot(i,true)
		b.priority_bonus = c.priority_bonus
		b.set_meta("card_id",card_id)
		b.set_meta("hand_owner",id)
		b.set_meta("exposed_width",76.0)
		b.set_meta("hand_slot",mini(i,Layout.SLOTS-1))
		# Hover always explains the card, even when locked or unplayable.
		b.pressed.connect(func(): ui._click_hand(id,card_id,int(view.revision)))
	

func _played(id: int, x: float, friendly: bool) -> void:
	var events: Array = []
	var staged: bool = view.phase == "planning"
	if staged and friendly:
		for card_id in ui._selected_cards(id):
			events.append({"card":card_id,"actor":id,"id":-card_id,"status":"staged","revealed":false})
	elif not staged:
		for action in view.queue:
			if action.get("hand_response",false): continue
			if _hand_transferred(action): continue
			if action.actor == id: events.append(action)
		for action in view.death_queue:
			if _hand_transferred(action): continue
			if action.actor == id:
				if action.status == "done" and view.characters[id].get("death_slots",[]).any(func(slot):return slot.triggered and slot.card==action.card): continue
				# A retained death card lives beside its pawn except while resolving.
				if action.status in ["done","returned","pending"] and view.characters[id].deathrattles.has(action.card): continue
				events.append(action)
	# Stable table positions survive the host's priority/reveal sorting.
	if not staged: events.sort_custom(func(a,b): return a.id < b.id)
	var y := Layout.FRIENDLY_PLAYED_Y if friendly else 298.0
	var factor := Layout.PLAYED_SCALE
	var zone := Control.new()
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.set_meta("played_actor",id)
	_place(zone,canvas,Rect2(x,y,344,105))
	if events.is_empty(): return
	var positions := _fan_positions(events.size(),324,76*factor)
	for i in range(events.size()):
		var action: Dictionary = events[i]
		var is_death: bool = action.get("death",false)
		var known: bool = is_death or action.get("revealed",false) or action.get("inspected",false) or friendly
		var info: Dictionary = (view.death_catalog[action.card] if is_death else view.catalog[action.card]) if known and action.card != 0 else {}
		if not info.is_empty() and info.key == "final_strike" and action.has("damage"):
			# Virtual copies can share the physical card ID but have fresh damage.
			info = preload("res://scripts/card_state.gd").final_strike_info(info,int(action.damage))
		var card_bonus: int = view.characters[id].priority_bonus
		if not info.is_empty() and action.get("main",-1) >= 0:
			info = info.duplicate(true)
			card_bonus = 0
			if is_death: info.priority = action.main
			else:
				info.main = action.main
				info.secondary = action.secondary
		var can_choose: bool = not staged and not is_death and view.phase == "choosing" and view.input.type == "card" and view.input.team == mine and view.input.options.has(action.id) and not ui.submitting
		var b = _card(zone,info,is_death,info.is_empty())
		b.scale = Vector2.ONE*factor
		b.position = Vector2(10+positions[i],0)
		b.action_status = action.status
		_suppression_attachment(b,action)
		_anticipation_attachment(b,action)
		_shade_unrevealed(b,action,friendly,is_death,staged)
		# Keep the table slot for the burn animation, but never redraw a card
		# consumed by an amulet. Ordinary defense/blessing blocks keep their card.
		if action.get("burned_by_amulet","") != "":
			b.modulate.a = 0.0
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.targetable = can_choose
		b.selected = action.status == "active"
		b.set_meta("played_action_id",int(action.id))
		b.set_meta("played_owner",id)
		b.set_meta("played_death",is_death)
		b.set_meta("played_revealed",action.get("revealed",false))
		b.set_meta("inspect_key","played_%d_%s_%d" % [id,str(is_death),action.id])
		b.set_meta("exposed_width",(positions[i+1]-positions[i])/factor if i+1 < events.size() else 76.0)
		if can_choose: b.set_meta("target_action_id",int(action.id))
		if staged: b.set_meta("staged_card_id",int(action.card))
		if not info.is_empty():
			b.priority_bonus = card_bonus
		var status: String = {"staged":"待确认","active":"结算中","done":"已结算","cancelled":"已取消","blocked":"已抵消","suppressed":"被压制","skipped":"未翻开","removed":"已移除","expired":"未发动","declined":"已跳过","returned":"已收回"}.get(action.status,"已翻开" if action.get("revealed",false) else "未翻开")
		if staged and view.ready[mine]: status = "已确认"
		if can_choose: status = "点击选择"
		b.status_label = _text(zone,status,Rect2(positions[i]+2,108*factor,70,16),11,Color("906020") if can_choose else SOFT,true)
		if can_choose:
			b.pressed.connect(func(): ui._send_choice("choose",action.id,int(view.revision)))
		elif staged:
			b.pressed.connect(func(): ui._return_planned(id,action.card,int(view.revision)))
		elif info.is_empty():
			b.disabled = true
		if not staged and not is_death:
			_reveal_card(b,action,friendly)
			_conceal_card(b,action,friendly)

func _anticipation_attachment(card: Control, action: Dictionary) -> void:
	if not preload("res://scripts/anticipation_mark.gd").applies(view,action):return
	var e:Dictionary=view.get("animation",{})
	var applying:bool=e.get("style","")=="anticipation" and e.get("stage","")=="impact" and e.get("succeeded",false) and int(e.action.actor)/3!=int(action.actor)/3
	var started:int=-1
	if applying:
		var stamp="%d/%d/%s"%[view.match,e.id,e.stage]
		if ui.effect_key!=stamp:ui.effect_key=stamp;ui.effect_started=Time.get_ticks_msec()
		started=ui.effect_started
	var mark=preload("res://scripts/anticipation_mark.gd").new()
	card.add_child(mark);mark.configure(started)

func _suppression_attachment(card: Control, action: Dictionary) -> void:
	if action.get("death",false) or action.get("revealed",false): return
	var e:Dictionary=view.get("animation",{})
	var applying:bool=e.get("style","") in ["suppress","late_suppress"] and e.get("op","")=="chosen" and e.get("target_action",-999)==action.id
	var key:String=e.style if applying else str(action.get("suppression_key",""))
	if key.is_empty(): return
	var started:int=-1
	if applying:
		var stamp="%d/%d/%s"%[view.match,e.id,e.stage]
		if ui.effect_key!=stamp:ui.effect_key=stamp;ui.effect_started=Time.get_ticks_msec()
		started=ui.effect_started
	var seal=preload("res://scripts/suppression_seal.gd").new()
	card.add_child(seal);seal.configure(key,e if applying else {},started)

func _hand_transferred(action: Dictionary) -> bool:
	if not action.get("hand_transferred",false): return false
	var event: Dictionary = view.get("animation",{})
	# Keep an invisible source anchor only while this card is actually flying.
	return not (event.get("kind","") == "hand_transfer" and event.action.id == action.id and event.action.get("death",false) == action.get("death",false))

func _reveal_card(card: Control, action: Dictionary, friendly: bool) -> void:
	var event: Dictionary = view.get("animation",{})
	if event.get("kind","") != "card_reveal" or not event.actions.has(action.id): return
	var key := "%d/%d/reveal/%d" % [view.match,view.round,event.id]
	if not ui.reveal_times.has(key):
		var stamp: String = ui.session._animation_stamp(view)
		ui.reveal_times[key] = ui.session.received_animation_started if ui.session.received_animation_key == stamp else Time.get_ticks_msec()
	var started: int = ui.reveal_times[key]
	if Time.get_ticks_msec()-started >= CardReveal.DURATION*1000: return
	var reveal = CardReveal.new()
	card.get_parent().add_child(reveal)
	reveal.initialize(card,friendly,not friendly,started)

func _phase_clock(event: Dictionary) -> int:
	var key := "%d/%d/phase/%d" % [view.match,view.round,event.id]
	if not ui.reveal_times.has(key):
		var stamp: String = ui.session._animation_stamp(view)
		ui.reveal_times[key] = ui.session.received_animation_started if ui.session.received_animation_key == stamp else Time.get_ticks_msec()
		if event.get("turn_stage","") == "start":
			ui.reveal_times[key] = ui.session.begin_start_announcement(view)
	return ui.reveal_times[key]

func _conceal_card(card: Control, action: Dictionary, friendly: bool) -> void:
	var event: Dictionary = view.get("animation",{})
	if not friendly or event.get("kind","") != "phase_change" or event.stage != "travel" or not event.get("conceal_actions",[]).has(action.id): return
	var started := _phase_clock(event)
	if Time.get_ticks_msec()-started >= CardReveal.DURATION*1000: return
	var flip := CardReveal.new()
	card.get_parent().add_child(flip)
	flip.initialize(card,true,false,started,true)

func _phase_announcement() -> void:
	var event: Dictionary = view.get("animation",{})
	if event.get("kind","") != "phase_change" or event.stage != "travel" or not event.get("announce",false): return
	var started := _phase_clock(event)
	var cue = preload("res://scripts/phase_announcement.gd").new()
	if Time.get_ticks_msec()-started >= cue.DURATION_MS:
		cue.free()
		return
	cue.title = Layout.PHASE_TITLES[event.turn_stage]
	cue.tint = Layout.PHASE_COLORS[event.turn_stage]
	cue.started = started
	cue.set_meta("center_phase_title",event.turn_stage)
	_place(cue,canvas,Rect2(Vector2.ZERO,BASE))

func _show_card(info: Dictionary, bonus: int = 0) -> void:
	var source = _active_widget()
	if source != null and source.card.get("id",-1) == info.get("id",-2):
		ui._inspect_visible(source,int(view.active_action.actor))
	else:
		# Rare synthetic effects (such as pain) have no physical card in the queue.
		ui.hand_focus = {"actor":int(view.active_action.get("actor",mine*3)),"card":int(info.id),"readonly":true,"info":info,"bonus":bonus}
		ui._schedule_render()

func _shade_unrevealed(card: Control, action: Dictionary, friendly: bool, death: bool, staged: bool) -> void:
	if death: return
	var unrevealed: bool = not action.get("revealed",false)
	card.set_meta("unrevealed",unrevealed)
	card.self_modulate = Color.WHITE
	# Owners keep a dim face until its priority reveals; opponents see a back.
	if not staged and unrevealed:
		card.hidden_card = not friendly
		if friendly: card.self_modulate = CardReveal.UNREVEALED_TINT

func _hand_preview() -> void:
	if ui.hand_focus.is_empty(): return
	var actor: int = ui.hand_focus.actor
	var card_id: int = ui.hand_focus.card
	if actor < 0 or actor >= view.characters.size(): return
	var c: Dictionary = view.characters[actor]
	var readonly: bool = ui.hand_focus.get("readonly",false)
	if not readonly and (c.team != mine or not c.hand.has(card_id)): readonly = true
	var source = _find_display_card(canvas,ui.hand_focus.source_key) if ui.hand_focus.has("source_key") else _find_hand_card(card_id)
	if ui.hand_focus.has("info") or (source == null and ui.hand_focus.has("saved_info")):
		var saved: Dictionary = ui.hand_focus.get("info",ui.hand_focus.get("saved_info",{}))
		source = _card(canvas,saved,saved.has("priority") and saved.get("type","") != "诅咒")
		source.position = Vector2(620,420)
		source.priority_bonus = ui.hand_focus.get("bonus",0)
		source.pressed.connect(ui._close_hand)
	if source == null: return
	var info: Dictionary = source.card
	var selected: bool = ui._selected_cards(actor).has(card_id) and view.phase == "planning"
	var origin: Vector2 = ui.hand_focus.get("origin",(source.global_position - canvas.global_position) / canvas.scale)
	var origin_scale: Vector2 = source.scale
	var destination := Vector2(clampf(origin.x,220,1125),326)
	var local_hand: bool = source.has_meta("hand_owner")
	var local_death: bool = source.death and source.has_meta("death_card_id")
	if local_hand:
		# Lift the real hand card locally; only resolution prompts use the center.
		destination = Vector2(clampf(origin.x-26,145,1200),minf(origin.y-128,680))
	if local_death:
		destination = Vector2(clampf(origin.x,145,1200),maxf(96,origin.y-76))
	var reopening: bool = ui.hand_focus.has("layout")
	if reopening:
		destination = ui.hand_focus.layout.destination
		local_hand = ui.hand_focus.layout.local_hand
		local_death = ui.hand_focus.layout.local_death
	else:
		ui.hand_focus.layout = {"destination":destination,"local_hand":local_hand,"local_death":local_death}
	var popup := Control.new()
	popup.z_index = 30
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.set_meta("hand_preview_card",card_id)
	_place(popup,canvas,Rect2(Vector2.ZERO,BASE))
	# This is the original widget, not another copy of the selected card.
	source.reparent(popup)
	source.position = origin
	source.scale = origin_scale
	source.expanded = true
	source.hidden_card = false
	source.tooltip_text = ""
	source.queue_redraw()
	var detail_width := 470.0 if str(info.text).length() > 75 else 320.0
	if info.get("key","") in ui.Rules.AMULETS: detail_width = 600.0
	var references := _related_cards(info)
	var body_width := detail_width-32
	if not references.is_empty(): detail_width += 392
	var side_x: float = destination.x+146 if destination.x+146+detail_width < 1325 else destination.x-detail_width-16
	var details := PanelContainer.new()
	details.set_meta("card_description",card_id)
	details.add_theme_stylebox_override("panel",Chrome.panel_style(16))
	var detail_y := 385.0 if local_hand else destination.y
	if local_death:
		detail_y = 352.0
		side_x = destination.x+146 if destination.x < 700 else destination.x-detail_width-16
		side_x = clampf(side_x,142,1318-detail_width)
	if local_hand: side_x = clampf(destination.x-40,160,1280-detail_width)
	_place(details,popup,Rect2(side_x,detail_y,detail_width,182))
	var detail_bottom := 572.0 if local_death else 588.0
	details.resized.connect(func(): details.position.y = minf(detail_y,detail_bottom-details.size.y))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	details.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	ui._label(heading,info.name,22,BLUE).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close: Button = ui._button(heading,"×",ui._close_hand)
	_small_button(close)
	close.tooltip_text = "收起（Esc）"
	var rank: String = str(int(info.priority)+source.priority_bonus) if source.death else "%d/%d" % [info.main+source.priority_bonus,info.secondary+source.priority_bonus]
	if info.get("main",0) < 0: rank = "无"
	ui._label(column,"%s · 优先级 %s" % ["诅咒牌" if info.type == "诅咒" else info.type,rank],14,SOFT)
	if references.is_empty():
		ui._paragraph(column,info.text,18,INK)
	else:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",18)
		column.add_child(row)
		var description: Label = ui._paragraph(row,info.text,18,INK)
		description.custom_minimum_size.x = body_width
		description.size_flags_horizontal = Control.SIZE_FILL
		description.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_append_references(row,references)
	var controls := Control.new()
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(controls,popup,Rect2(destination+Vector2(0,191),Vector2(130,34)))
	if view.phase == "planning" and not readonly:
		var allowed: bool = ui._can_edit_plan(actor) and info.get("playable",true)
		var full: bool = c.play_limit > 1 and ui._selected_cards(actor).size() >= c.play_limit and not selected
		var title := "撤回出牌" if selected else ("已锁定" if view.ready[mine] else "不可出牌" if not allowed else "出牌")
		if full: title = "已出满"
		var play := _button(controls,title,Rect2(0,0,130,32),func():
			if selected: ui._return_planned(actor,card_id,int(view.revision))
			else: ui._play_hand(actor,card_id,int(view.revision)),not allowed or full,true)
		play.set_meta("play_card_id",card_id)
	# Never let the old hover tooltip cover the raised card or its description.
	_silence_tooltips(canvas)
	clear_card_hover()
	if reopening:
		source.position = destination
		source.scale = Vector2.ONE*1.7
		ui.hand_lift = {"destination":destination,"card":source,"origin":origin,"scale":origin_scale,"tween":null,"details":details,"controls":controls}
		_fit_preview_details(details,detail_width,detail_y,detail_bottom)
		return
	details.modulate.a = 0
	controls.modulate.a = 0
	var lift: Tween = source.create_tween().set_parallel(true)
	lift.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	lift.tween_property(source,"position",destination,0.2)
	lift.tween_property(source,"scale",Vector2(1.7,1.7),0.2)
	lift.tween_property(details,"modulate:a",1.0,0.12).set_delay(0.08)
	lift.tween_property(controls,"modulate:a",1.0,0.12).set_delay(0.08)
	ui.hand_lift = {"destination":destination,"card":source,"origin":origin,"scale":origin_scale,"tween":lift,"details":details,"controls":controls}
	_fit_preview_details(details,detail_width,detail_y,detail_bottom)

func _fit_preview_details(details: Control, width: float, top: float, bottom: float = 588.0) -> void:
	# The first container pass can expand to an unwrapped label's natural width.
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	if not is_instance_valid(details): return
	details.size = Vector2(width,182)
	await ui.get_tree().process_frame
	if is_instance_valid(details): details.position.y = minf(top,bottom-details.size.y)

func _silence_tooltips(node: Node) -> void:
	if node is Card: node.tooltip_text = ""
	for child in node.get_children(): _silence_tooltips(child)

func _find_hand_card(card_id: int):
	for node in canvas.get_children():
		if not node.has_meta("hand_actor") and not node.has_meta("played_actor"): continue
		for child in node.get_children():
			if child.get_meta("card_id",-1) == card_id or child.get_meta("staged_card_id",-1) == card_id: return child
	return null

func _find_display_card(node: Node, key: String):
	if node.get_meta("inspect_key","") == key: return node
	for child in node.get_children():
		var found = _find_display_card(child,key)
		if found != null: return found
	return null

func _active_widget():
	if view.active_action.is_empty(): return null
	var a: Dictionary = view.active_action
	var source = _find_display_card(canvas,"played_%d_%s_%d" % [a.actor,str(a.get("death",false)),a.id])
	if source == null and a.get("death",false): source = _find_display_card(canvas,"death_%d_%d" % [a.actor,a.card])
	return source

func _resolution_animation() -> void:
	if view.get("animation",{}).get("kind","") in ["card_reveal","divinity_pulse"] or (view.active_action.get("id",0)==-2 and view.active_card.get("key","")=="divinity"):
		# A reaction/extra play can flip while another card is already raised.
		# Hold that card in place until the reveal finishes and resolution resumes.
		if not ui.resolution_focus.is_empty():
			var saved: Dictionary = ui.resolution_focus
			var previous = _find_display_card(canvas,saved.inspect_key)
			if previous != null:
				previous.position = previous.get_parent().get_global_transform().affine_inverse()*(canvas.get_global_transform()*saved.destination)
				previous.scale = saved.scale
				if is_instance_valid(previous.status_label): previous.status_label.position = previous.position+Vector2((previous.size.x*previous.scale.x-previous.status_label.size.x)/2,previous.size.y*previous.scale.y+3)
		return
	var source = _active_widget()
	var a: Dictionary = view.active_action
	var key := "" if a.is_empty() else "%d/%d/%d/%s/%d/%d" % [view.match,view.round,a.actor,str(a.get("death",false)),a.id,a.card]
	var now := Time.get_ticks_msec()
	if not ui.resolution_focus.is_empty() and ui.resolution_focus.key != key:
		var previous: Dictionary = ui.resolution_focus.duplicate()
		previous.started = now
		ui.resolution_returns[previous.inspect_key] = previous
		ui.resolution_focus.clear()
	for returning_key in ui.resolution_returns.keys():
		var previous: Dictionary = ui.resolution_returns[returning_key]
		if now-previous.started >= 240:
			ui.resolution_returns.erase(returning_key)
			continue
		var returning_card = _find_display_card(canvas,returning_key)
		if returning_card != null and returning_card != source:
			var from: Vector2 = returning_card.get_parent().get_global_transform().affine_inverse()*(canvas.get_global_transform()*previous.destination)
			returning_card.start_return(previous.started,from,previous.scale)
	if source == null: return
	var cue := int(view.animation.id) if view.get("animation",{}).get("kind","") == "card_start" else -1
	var saved: Dictionary = ui.resolution_times.get(key,{})
	if saved.is_empty() or (cue >= 0 and saved.get("cue",-1) != cue):
		saved = {"started":Time.get_ticks_msec(),"cue":cue}
		ui.resolution_times[key] = saved
	var side = _find_display_card(canvas,"death_%d_%d" % [a.actor,a.card]) if a.get("death",false) else null
	if side != null and side != source:
		if not saved.has("origin"):
			saved.origin = _board_rect(side).position
			saved.origin_scale = side.scale
		side.hide()
	var final_scale := Vector2(1.1616,1.1616)
	var destination := _resolution_destination(source,source.size*final_scale,a.actor)
	# Keep one settled location across target selection, travel, impact and rebuilds.
	if ui.resolution_focus.get("key","") == key: destination = ui.resolution_focus.destination
	var local_destination: Vector2 = source.get_parent().get_global_transform().affine_inverse()*(canvas.get_global_transform()*destination)
	source.start_resolution(saved.started,local_destination,final_scale.x/source.scale.x)
	if saved.has("origin"):
		source.resolution_origin = source.get_parent().get_global_transform().affine_inverse()*(canvas.get_global_transform()*saved.origin)
		source.resolution_scale = saved.origin_scale
		source.resolution_factor = final_scale.x/saved.origin_scale.x
		source._process(0)
	source.set_meta("resolving_card",true)
	ui.resolution_focus = {"key":key,"inspect_key":side.get_meta("inspect_key","") if side != null else source.get_meta("inspect_key",""),"destination":destination,"scale":final_scale}

func _board_rect(control: Control) -> Rect2:
	return Rect2((control.global_position-canvas.global_position)/canvas.scale,control.get_global_rect().size/canvas.scale)

func _presentation_obstacles(except: Control = null) -> Array:
	var obstacles: Array = []
	for node in _all_controls(canvas):
		if node == except or (except != null and node == except.status_label) or not node.is_visible_in_tree(): continue
		if node is Card or node is Label or node.has_meta("knight_id") or node.has_meta("health_actor") or node.has_meta("draw_pile"):
			obstacles.append(_board_rect(node))
	return obstacles

func _resolution_destination(source: Control,dimensions: Vector2,actor: int) -> Vector2:
	var origin := _board_rect(source).position
	var preferred := Vector2(clampf(origin.x+105,142,1300-dimensions.x),427 if actor/3 == mine else 350)
	var candidates: Array = [preferred]
	for x in range(144,1217,24):
		for y in [335.0,365.0,405.0,435.0]: candidates.append(Vector2(x,y))
	var obstacles := _presentation_obstacles(source)
	if ui.session.tutorial != null:
		obstacles.append(ui.session.tutorial.panel_rect().grow(12))
	var best := preferred
	var best_score := INF
	for at in candidates:
		var rect := Rect2(at,dimensions+Vector2(0,22)) # Include its status caption.
		var score: float = at.distance_to(preferred)*.1
		for obstacle in obstacles:
			var overlap: Rect2 = rect.grow(5).intersection(obstacle)
			score += overlap.get_area()*100 if overlap.has_area() else 0
		if not Rect2(135,328,1170,246).encloses(rect): score += 1000000
		if score < best_score: best_score = score; best = at
	return best

func _restore_scroll(scroll: ScrollContainer, key: String, vertical: bool) -> void:
	var saved: int = int(ui.table_scrolls.get(key,0))
	# Flow containers need two layout passes before their scroll range is known.
	# Do not let the initial zero range overwrite the saved browsing position.
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	if not is_instance_valid(scroll) or not scroll.is_inside_tree(): return
	if vertical: scroll.scroll_vertical = saved
	else: scroll.scroll_horizontal = saved
	var bar: ScrollBar = scroll.get_v_scroll_bar() if vertical else scroll.get_h_scroll_bar()
	bar.value_changed.connect(func(value): ui.table_scrolls[key] = value)

func _card(parent: Node, info: Dictionary, death: bool = false, hidden: bool = false, picked: bool = false):
	var b = Card.new()
	b.immediate_hover = true
	b.card = info
	b.death = death; b.hidden_card = hidden; b.selected = picked
	b.tooltip_text = ""
	parent.add_child(b)
	b.mouse_entered.connect(func(): _show_card_hover(b))
	b.mouse_exited.connect(func(): _hide_card_hover(b))
	return b

func _show_card_hover(source: Control) -> void:
	# Use an immediate board overlay instead of the native delayed tooltip.
	source.tooltip_text = ""
	if source.card.is_empty() or not ui.hand_focus.is_empty() or ui.card_hover_blocked: return
	_show_hover(source,{"info":source.card.duplicate(true)})

func bind_status_hover(source: Control, description: String, key: String) -> void:
	source.tooltip_text = ""
	source.set_meta("status_description",description)
	source.set_meta("status_hover_key",key)
	source.mouse_entered.connect(func(): _show_status_hover(source))
	source.mouse_exited.connect(func(): _hide_card_hover(source))

func _show_status_hover(source: Control) -> void:
	if not ui.hand_focus.is_empty(): return
	_show_hover(source,{"description":source.get_meta("status_description"),"status_key":source.get_meta("status_hover_key")})

func _show_hover(source: Control, content: Dictionary) -> void:
	if ui.card_hover_blocked: return
	if not ui.card_pointer.is_finite(): ui.card_pointer = ui.get_viewport().get_mouse_position()
	# Widgets can enter/leave a stationary pointer while dealing or rebuilding.
	# Keep the text being read until the player actually moves the pointer.
	if not ui.card_hover_state.is_empty() and ui.card_hover_state.pointer.is_equal_approx(ui.card_pointer): return
	ui.card_hover_state = {"anchor":_board_rect(source),"pointer":ui.card_pointer,"source_id":source.get_instance_id()}
	ui.card_hover_state.merge(content)
	_restore_card_hover()

func _restore_card_hover() -> void:
	if ui.card_hover_state.is_empty() or not ui.hand_focus.is_empty(): return
	if is_instance_valid(card_hover): card_hover.free()
	var saved: Dictionary = ui.card_hover_state
	var source = Card.new()
	source.card = saved.get("info",{})
	var info: Dictionary = source.card
	var kind: String = "诅咒牌" if info.get("type","") == "诅咒" else info.get("type","")
	var description_text: String = saved.description if saved.has("description") else "%s · %s\n%s" % [info.name,kind,info.text]
	card_hover = source.make_description(description_text)
	if saved.has("status_key"):
		card_hover.remove_meta("hover_card_description")
		card_hover.set_meta("hover_status_description",saved.status_key)
	source.free()
	var references := _related_cards(info)
	if not references.is_empty():
		var description: Control = card_hover.get_child(0)
		description.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		card_hover.remove_child(description)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation",18)
		card_hover.add_child(row)
		row.add_child(description)
		_append_references(row,references)
	card_hover.z_index = 100
	card_hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_hover.set_meta("hover_source",saved.source_id)
	canvas.add_child(card_hover)
	card_hover.resized.connect(func(): _place_card_hover(saved.anchor))
	_place_card_hover(saved.anchor)

func refresh_card_hover() -> void:
	if not is_instance_valid(canvas) or not canvas.is_inside_tree(): return
	var source = ui.get_viewport().gui_get_hovered_control()
	if source is Card and source.immediate_hover and not source.card.is_empty() and source.is_visible_in_tree():
		if is_instance_valid(card_hover) and card_hover.get_meta("hover_source",0) == source.get_instance_id():
			ui.card_hover_state.pointer = ui.card_pointer
		else: _show_card_hover(source)
	elif source != null and source.has_meta("status_description") and source.is_visible_in_tree():
		if is_instance_valid(card_hover) and card_hover.get_meta("hover_source",0) == source.get_instance_id():
			ui.card_hover_state.pointer = ui.card_pointer
		else: _show_status_hover(source)
	else: clear_card_hover()

func clear_card_hover() -> void:
	ui.card_hover_state.clear()
	if is_instance_valid(card_hover): card_hover.queue_free()
	card_hover = null

func _related_cards(info: Dictionary) -> Array:
	var result: Array = []
	for key in info.get("related_keys",[]):
		var definition: Dictionary = {}
		if key == "boulder": definition = ui.Rules.BOULDER
		elif key == "poison": definition = ui.Rules.POISON
		else:
			for known in view.catalog.values()+view.death_catalog.values():
				if known.key == key:
					definition = known
					break
		if not definition.is_empty(): result.append(definition)
	return result

func _append_references(row: HBoxContainer, references: Array) -> void:
	var separator := VSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(separator)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation",12)
	row.add_child(column)
	for info in references:
		var entry := HBoxContainer.new()
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_theme_constant_override("separation",12)
		column.add_child(entry)
		var face := Card.new()
		face.card = info
		face.death = info.has("priority")
		face.immediate_hover = true
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.focus_mode = Control.FOCUS_NONE
		face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		face.set_meta("reference_card_key",info.key)
		entry.add_child(face)
		var label := Label.new()
		label.text = "%s · %s\n%s" % [info.name,"诅咒牌" if info.type == "诅咒" else info.type,info.text]
		label.custom_minimum_size.x = 250
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		label.add_theme_font_size_override("font_size",18)
		label.add_theme_color_override("font_color",INK)
		label.set_meta("reference_description_key",info.key)
		entry.add_child(label)

func _place_card_hover(bounds: Rect2) -> void:
	if not is_instance_valid(card_hover): return
	var y: float = bounds.position.y-card_hover.size.y-14
	if y < 16: y = bounds.end.y+14
	card_hover.position = Vector2(clampf(bounds.get_center().x-card_hover.size.x/2,16,BASE.x-card_hover.size.x-16),clampf(y,16,BASE.y-card_hover.size.y-16))

func _hide_card_hover(source: Control) -> void:
	if not ui.card_hover_state.is_empty() and not ui.card_hover_state.pointer.is_equal_approx(ui.card_pointer) and ui.card_hover_state.source_id == source.get_instance_id():
		clear_card_hover()

func _plan_widgets(node: Node, actor: int) -> Array:
	var found: Array = []
	if node is Card and (node.get_meta("hand_owner",-1) == actor or (node.has_meta("staged_card_id") and node.get_meta("played_owner",-1) == actor)):
		found.append(node)
	for child in node.get_children(): found.append_array(_plan_widgets(child,actor))
	return found

func plan_positions(actor: int) -> Dictionary:
	var result := {}
	for card in _plan_widgets(canvas,actor):
		for child in card.get_children():
			if child is PlanningFlight: child.present(Time.get_ticks_msec())
		result[int(card.card.id)] = _board_rect(card)
	return result

func _planning_flights() -> void:
	if view.phase != "planning": return
	var now := Time.get_ticks_msec()
	for id in ui.planning_motions.keys():
		if now-ui.planning_motions[id].started >= PlanningFlight.DURATION_MS: ui.planning_motions.erase(id)
	for actor in range(mine*3,mine*3+3):
		for card in _plan_widgets(canvas,actor):
			var id: int = card.card.id
			if not ui.planning_motions.has(id): continue
			var motion: Dictionary = ui.planning_motions[id]
			var dest: Rect2 = _board_rect(card)
			if dest.is_equal_approx(motion.from): continue
			var flight := PlanningFlight.new()
			card.add_child(flight)
			flight.configure(card,motion.from,motion.started,canvas)

func _action_bar() -> void:
	var interactive: bool = view.phase in ["targeting","death_targeting","choosing","reacting","responding","selecting"]
	var my_input: bool = interactive and view.input.team == mine
	var picker: bool = my_input and view.phase == "selecting"
	if interactive and not picker:
		var info: Dictionary = view.active_card
		var can_skip: bool = my_input and view.input.get("can_skip",false)
		var can_reselect: bool = my_input and view.input.get("can_reselect",false)
		var content_width := 272.0 if can_skip and not info.is_empty() else 250.0
		var direct: bool = view.phase in ["targeting","death_targeting"] or (view.phase == "choosing" and view.input.type == "card")
		var height := 140.0 if direct or not my_input else 240.0
		if my_input and view.phase == "responding": height = 180.0+40*view.input.options.size()
		var line: String = view.input.description if my_input else "对方正在操作，请稍候。"
		# Reserve enough lines for the full target instruction, including rewards.
		var description_height := maxf(49,ceilf((line.length()+(6 if view.input.has("target") else 0))/15.0)*24)
		height += description_height-49
		if can_reselect: height += 40
		var rect := _decision_rect(Vector2(content_width+28,height))
		var panel := _box(rect,Color("efe0c2"),EDGE)
		panel.set_meta("decision_panel",true)
		panel.z_index = 5
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		var actor: int = view.active_action.get("actor",view.input.get("target",mine*3))
		var own_actor: bool = view.characters[actor].team == mine
		var title: String = "%s%s · %s" % ["我方 " if own_actor else "敌方 ",view.characters[actor].name,info.get("name","整理手牌")]
		_text(panel,title,Rect2(14,10,content_width,27),18,BLUE if own_actor else RED)
		var description := _input_heading(panel,Rect2(14,40,content_width,description_height),14,line)
		description.add_theme_color_override("default_color",SOFT)
		description.set_meta("target_description",true)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not info.is_empty():
			var details := _button(panel,"查看卡牌效果",Rect2(154 if can_skip else 14,height-43,132 if can_skip else content_width,31),func(): _show_card(info))
			details.set_meta("show_card_button",true)
		if can_skip:
			var skip := "跳过剩余效果" if (info.get("key","") == "last_dance" and view.active_action.get("hits",0) > 0) or (info.get("key","") == "cards_to_blades" and view.active_action.get("blade_hits",0) > 0) else "跳过效果"
			var skip_button := _button(panel,skip,Rect2(14,height-43,132 if not info.is_empty() else content_width,31),func(): ui._skip_effect(int(view.revision)),ui.submitting)
			_danger_button(skip_button)
			skip_button.set_meta("skip_effect_button",true)
		var controls := HFlowContainer.new()
		controls.add_theme_constant_override("h_separation",8)
		controls.add_theme_constant_override("v_separation",8)
		_place(controls,panel,Rect2(14,45+description_height,content_width,maxf(0,height-96-description_height)))
		if my_input:
			if can_reselect:
				var reselect := _control(controls,"重新选择",func(): ui._reselect_targets(int(view.revision)))
				reselect.set_meta("reselect_targets_button",true)
			if view.phase == "choosing" and view.input.type == "number":
				var selected: Array = view.input.get("selected_numbers",[])
				var values: Array = view.input.options.duplicate()
				values.append_array(selected)
				values.sort()
				for value in values:
					var choice := _control(controls,str(value),func(): ui._send_choice("choose",int(value),int(view.revision)),true)
					choice.set_meta("priority_choice",int(value))
					if selected.has(value):
						choice.toggle_mode = true
						choice.set_pressed_no_signal(true)
						choice.disabled = true
						choice.add_theme_stylebox_override("disabled",choice.get_theme_stylebox("pressed"))
						choice.add_theme_color_override("font_disabled_color",choice.get_theme_color("font_pressed_color"))
			if view.phase == "reacting":
				_control(controls,"使用防御 · 取消攻击",func(): ui._send_choice("defend",1,int(view.revision)),true).set_meta("tutorial_defend_button",true)
				_control(controls,"承受攻击 · 保留防御",func(): ui._send_choice("defend",0,int(view.revision)))
			if view.phase == "responding":
				for id in view.input.options:
					_control(controls,"使用"+view.catalog[id].name+" · 取消效果",func(): ui._send_choice("respond",int(id),int(view.revision)),true)
				_control(controls,"保留护符 · 继续",func(): ui._send_choice("respond",0,int(view.revision)))
	elif not picker and view.phase == "planning":
		var label := "取消确认" if view.ready[mine] else "确认出牌"
		var confirm := _button(canvas,label,Layout.CONFIRM_RECT,func():
			ui.submitting=true
			if view.ready[mine]: ui.session.act("unlock")
			else: ui.session.act("plan",ui._plan_payload())
			ui._schedule_render(),ui.submitting or (view.ready[mine] and view.ready[1-mine]))
		confirm.set_meta("planning_lock_button",true)
		preload("res://scripts/art_ui/confirm_skin.gd").install(confirm)
		confirm.tooltip_text = "等待对方确认；点击可取消确认并修改出牌。" if view.ready[mine] else "确认全队出牌，未选牌的棋子默认不出牌。"
	elif not picker and view.phase == "ended":
		Chrome.result_panel(self)
	if view.omniscient: _button(canvas,"天眼 · 查看卡牌",Rect2(1125,85,185,23),ui._show_eye)
	if not ui.notice.is_empty(): _text(canvas,ui.notice,Rect2(397,85,600,20),13,RED,true)

func _early_end_button() -> void:
	if not view.get("early_end_available",false): return
	var rect := Layout.CONFIRM_RECT
	if view.phase == "selecting" and view.input.get("team",-1) == mine and view.input.type not in ["inspect"] and not ui.picker_collapsed:
		rect.position.y = 756 # Below the open card picker, without covering its cards.
	var end_button := _button(canvas,"提前结束回合",rect,func(): ui._end_round_early(int(view.revision)),ui.submitting or not view.get("can_end_round_early",false))
	end_button.z_index = 20
	end_button.set_meta("early_end_round_button",true)
	end_button.tooltip_text = "跳过我方剩余普通牌；已生效部分保留，回合末效果及双方亡语照常结算。"

func _decision_rect(dimensions: Vector2) -> Rect2:
	var source = _active_widget()
	var origin := Vector2(720,440)
	var extent := Vector2.ZERO
	if source != null:
		origin = (source.global_position-canvas.global_position)/canvas.scale
		extent = source.size*source.scale
		# The resolving card is still moving when this panel is built. Reserve
		# its settled position, otherwise the card can slide behind the prompt.
		if not ui.resolution_focus.is_empty():
			origin = ui.resolution_focus.destination
			extent = source.size*ui.resolution_focus.scale
	var candidates: Array = []
	# Prefer the gaps between table cards, including while the opponent chooses.
	for x in [402.0,786.0,(BASE.x-dimensions.x)/2,150.0,1110.0-dimensions.x]:
		for y in [410.0-dimensions.y/2,295.0,491.0-dimensions.y]:
			candidates.append(Rect2(Vector2(x,clampf(y,295,maxf(295,491-dimensions.y))),dimensions))
	var obstacles: Array = [Rect2(origin,extent)]
	var backpack: Dictionary = view.get("prepared_backpack",{})
	if not backpack.is_empty():
		var dock: Vector2 = Vector2(235,377) if backpack.get("stage","")=="chest" else preload("res://scripts/prepared_timing.gd").hand_dock(int(backpack.actor),mine)
		obstacles.append(Rect2(dock-Vector2(75,75),Vector2(150,150)))
	_collect_targets(canvas,obstacles)
	var best: Rect2 = candidates[0]
	var best_score := INF
	for rect in candidates:
		var score: float = rect.get_center().distance_to(origin+extent/2)*0.01+rect.get_center().distance_to(Vector2(720,440))*0.003
		for obstacle in obstacles:
			var overlap: Rect2 = rect.intersection(obstacle.grow(5))
			score += overlap.get_area() if overlap.has_area() else 0
		if score < best_score: best_score = score; best = rect
	return best

func _collect_targets(node: Node, rects: Array) -> void:
	if node is Control and (node.has_meta("played_action_id") or node.has_meta("target_character_id") or node.has_meta("draw_pile")):
		rects.append(Rect2((node.global_position-canvas.global_position)/canvas.scale,node.size*node.scale))
	for child in node.get_children(): _collect_targets(child,rects)

func _effect_animation() -> void:
	if preload("res://scripts/prepared_timing.gd").supports(view.get("animation",{})):
		var prepared=preload("res://scripts/prepared_effect.gd").new()
		canvas.add_child(prepared);prepared.initialize(self)
		return
	var gem_event:Dictionary=view.get("animation",{})
	if gem_event.get("gem_polished",false):
		_add_polished_gem()
		return
	if preload("res://scripts/cinema/cinema.gd").supports(view.get("animation",{})):
		var cinema=preload("res://scripts/cinema/cinema.gd").new()
		canvas.add_child(cinema)
		cinema.set_meta("cinema_effect",view.animation.id)
		cinema.initialize(self)
		return
	if view.get("animation",{}).get("kind","") == "divinity_awaken":return
	if view.get("animation",{}).get("kind","") == "divinity_pulse":
		var pulse_key:="%d/%d/%s"%[view.match,view.animation.id,view.animation.stage]
		if ui.effect_key!=pulse_key:ui.effect_key=pulse_key;ui.effect_started=Time.get_ticks_msec()
		var pulse=preload("res://scripts/divinity_pulse.gd").new()
		canvas.add_child(pulse);pulse.set_meta("divinity_pulse",view.animation.id)
		pulse.initialize(self,ui.effect_started)
		return
	if view.active_action.has("blade_source") and view.phase in ["targeting","responding"]:
		var preview=preload("res://scripts/blade_volley_animation.gd").new()
		canvas.add_child(preview);preview.set_meta("blade_preparation",true)
		preview.initialize(self,-1,true)
	if view.get("animation",{}).is_empty(): return
	if view.animation.kind == "pawn_speech":
		var speech_key := "%d/%d/%s" % [view.match,view.animation.id,view.animation.stage]
		if ui.effect_key != speech_key: ui.effect_key = speech_key;ui.effect_started = Time.get_ticks_msec()
		var speaker: int = view.animation.action.actor
		var own: bool = speaker/3 == mine
		var speech = preload("res://scripts/pawn_speech.gd").new()
		canvas.add_child(speech)
		speech.configure(speaker,view.animation.message,Layout.pawn_rect(speaker,own),BLUE if own else RED,1.9)
		speech.started = ui.effect_started
		speech.present((Time.get_ticks_msec()-ui.effect_started)/1000.0)
		return
	if view.animation.kind == "blade_volley":
		var blade_key := "%d/%d/%s" % [view.match,view.animation.id,view.animation.stage]
		if ui.effect_key != blade_key:
			ui.effect_key = blade_key;ui.effect_started = Time.get_ticks_msec()
		var volley=preload("res://scripts/blade_volley_animation.gd").new()
		canvas.add_child(volley);volley.set_meta("blade_volley_animation",view.animation.id)
		volley.initialize(self,ui.effect_started)
		return
	if view.animation.kind in ["hand_place","reverse_restore"]:
		var placement_key := "%d/%d/%s" % [view.match,view.animation.id,view.animation.stage]
		if ui.effect_key != placement_key:
			ui.effect_key = placement_key;ui.effect_started = Time.get_ticks_msec()
		return
	if view.animation.kind in ["phase_change","card_reveal"]: return
	if view.animation.kind == "hand_transfer":
		var transfer_key := "%d/%d/%s" % [view.match,view.animation.id,view.animation.stage]
		if ui.effect_key != transfer_key:
			ui.effect_key = transfer_key
			ui.effect_started = Time.get_ticks_msec()
		var transfer = preload("res://scripts/hand_transfer_animation.gd").new()
		canvas.add_child(transfer)
		transfer.set_meta("hand_transfer_animation",view.animation.id)
		transfer.initialize(self,ui.effect_started)
		return
	if view.animation.kind == "gem_trigger":
		var gem_key := "%d/%d/%s" % [view.match,view.animation.id,view.animation.stage]
		if ui.effect_key != gem_key:
			ui.effect_key = gem_key
			ui.effect_started = Time.get_ticks_msec()
		var gem_effect = preload("res://scripts/gem_animation.gd").new()
		canvas.add_child(gem_effect)
		gem_effect.set_meta("gem_animation",view.animation.id)
		gem_effect.initialize(self,ui.effect_started)
		return
	if view.animation.kind == "draw_cards":
		var draw_key := "%d/%d/%s" % [view.match,view.animation.id,view.animation.stage]
		if ui.effect_key != draw_key:
			ui.effect_key = draw_key
			ui.effect_started = Time.get_ticks_msec()
		var draw_effect = preload("res://scripts/draw_animation.gd").new()
		canvas.add_child(draw_effect)
		draw_effect.set_meta("draw_animation",view.animation.id)
		draw_effect.initialize(self,ui.effect_started)
		if view.animation.has("gem_overlay"):_add_polished_gem()
		return
	var in_hand: bool = view.animation.get("hand_response",false)
	var effect = preload("res://scripts/amulet_hand_animation.gd").new() if in_hand else preload("res://scripts/effect_animation.gd").new()
	effect.event = view.animation
	effect.mine = mine
	var key := "%d/%d/%s" % [view.match,view.animation.id,view.animation.stage]
	if ui.effect_key != key:
		ui.effect_key = key
		ui.effect_started = Time.get_ticks_msec()
	effect.elapsed = (Time.get_ticks_msec()-ui.effect_started)/1000.0
	effect.clock_started = ui.effect_started
	var source = _active_widget()
	if source != null:
		effect.source_widget = source
		effect.source = (source.global_position-canvas.global_position)/canvas.scale+source.size*source.scale/2
	else:
		var actor: int = view.animation.action.actor
		effect.source = effect._knight(actor)+Vector2(63,-25)
	if in_hand: effect.prepare_hand(self)
	if view.animation.get("style","") in ["spare_food","spare_supplies"]:
		effect.source_widget = null
		effect.source = Vector2(1280,533)
	if view.animation.has("target_action"):
		for node in _all_controls(canvas):
			if node.get_meta("played_action_id",-999) == view.animation.target_action and not node.get_meta("played_death",false):
				effect.target_point = (node.global_position-canvas.global_position)/canvas.scale+node.size*node.scale/2
				if preload("res://scripts/amulet_cancel_effect.gd").supports(view.animation): effect.cancel_target = node
				break
	effect.set_meta("effect_animation",view.animation.id)
	if view.animation.has("hand_motion"):
		var motion: Dictionary = view.animation.hand_motion
		var friendly: bool = int(motion.actor)/3 == mine
		var slots: Array = motion.get("owner_slots",motion.slots) if friendly else motion.slots
		var cards: Array = []
		for node in canvas.get_children():
			if node.get_meta("hand_actor" if friendly else "enemy_hand_actor",-1) == motion.actor:
				cards = node.get_children().filter(func(c):return c is Card)
		for i in range(slots.size()):
			var card = cards[slots[i]] if slots[i]>=0 and slots[i]<cards.size() else null
			var point: Vector2 = Layout.hand_position(motion.actor,slots[i],friendly)+Layout.CARD_SIZE*Layout.hand_scale(friendly)/2
			if card != null:
				point = (card.global_position-canvas.global_position)/canvas.scale+card.size*card.scale/2
				if view.animation.get("op","") in ["convert_hand","gold_filter","frenzy"]:
					effect.outgoing_cards.append({"node":card,"alpha":card.modulate.a})
			effect.motion_points.append(point)
			effect.motion_faces.append(card.card.get("key","") if card!=null else "")
	if view.animation.get("style","") == "anticipation":
		for node in _all_controls(canvas):
			if node is Card and node.has_meta("played_action_id") and node.get_meta("played_owner",-1)/3 != view.animation.action.actor/3 and not node.get_meta("played_death",false) and not node.get_meta("played_revealed",false):
				effect.marked_points.append((node.global_position-canvas.global_position)/canvas.scale+node.size*node.scale/2)
	effect.feedback_obstacles = _presentation_obstacles()
	effect.obstacle_provider = _presentation_obstacles
	if view.animation.get("op","") in ["discard_all","strip","curse_after"] and not view.animation.targets.is_empty():
		var target: int = view.animation.targets[0].id
		var death_cards: bool = view.animation.op in ["strip","curse_after"]
		var fan_tag := "death_fan_actor" if death_cards else "hand_actor" if target/3 == mine else "enemy_hand_actor"
		for node in canvas.get_children():
			if node.get_meta(fan_tag,-1) != target: continue
			for card in node.get_children():
				if not card is Card or card.card.get("key","") in ["curse","immortal"]: continue
				if death_cards and card.action_status == "triggered": continue
				if not death_cards and not card.card.get("discardable",true): continue
				if effect.outgoing_cards.size() >= view.animation.get("card_count",0): break
				effect.outgoing_cards.append({"node":card,"alpha":card.modulate.a})
	_place(effect,canvas,Rect2(Vector2.ZERO,BASE))
	if view.animation.kind in ["strike","death_strike","card_effect","heal","shield","shield_block"]:
		for node in canvas.get_children():
			if node.has_meta("knight_id"):
				var sprite = node.get_child(0)
				effect.sprites[node.get_meta("knight_id")] = {"node":sprite,"position":sprite.position,"color":sprite.modulate,"scale":sprite.scale,"rotation":sprite.rotation,"pivot":sprite.pivot_offset}
	effect._process(0)

func _all_controls(parent: Node) -> Array:
	var found: Array = []
	for child in parent.get_children():
		if child is Control: found.append(child)
		found.append_array(_all_controls(child))
	return found

func _danger_button(button: Button) -> void:
	var font_size := button.get_theme_font_size("font_size")
	var target_size := button.size
	Chrome.danger_button(button)
	_small_button(button)
	button.add_theme_font_size_override("font_size",font_size)
	button.size = target_size

func _control(parent: Node, value: String, callback: Callable, primary: bool = false) -> Button:
	var b: Button = ui._button(parent,value,callback,ui.submitting,primary)
	_small_button(b)
	b.custom_minimum_size = Vector2(38,32)
	b.add_theme_font_size_override("font_size",16)
	if value.begins_with("跳过"): _danger_button(b)
	return b

func _selection_overlay() -> void:
	if ui.picker_collapsed:
		var compact_rect := _decision_rect(Vector2(502,64)) if not view.get("prepared_backpack",{}).is_empty() else Rect2(469,421,502,64)
		var compact := _box(compact_rect,Color("efe0c2"),EDGE)
		compact.set_meta("picker_collapsed",true)
		_text(compact,"已选 %d/%d 张 · 选牌仍在等待" % [ui.pick_cards.size(),view.input.count],Rect2(16,13,280,36),17,BLUE)
		_button(compact,"返回选牌",Rect2(309,15,177,34),func(): ui.picker_collapsed=false; ui._schedule_render()).set_meta("picker_toggle",true)
		return
	var panel := _box(Rect2(166,216,1108,528),Color("f2e4c8"),EDGE)
	panel.set_meta("selection_panel",true)
	panel.z_index = 10
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var browsing_deck: bool = view.input.type in ["deck","search"]
	_input_heading(panel,Rect2(20,12,606 if browsing_deck else 650,60))
	var search: LineEdit
	if browsing_deck:
		search = LineEdit.new()
		search.placeholder_text = "搜索卡牌名称"
		search.clear_button_enabled = true
		search.text = ui.picker_query
		search.set_meta("deck_search",true)
		search.add_theme_font_size_override("font_size",16)
		_place(search,panel,Rect2(642,18,232,34))
	_button(panel,"收起 · 查看战况",Rect2(890,18,198,34),func(): ui.picker_collapsed=true; ui._schedule_render()).set_meta("picker_toggle",true)
	var instruction := "选择一至两张手牌，按点击顺序赠送；超过上限的牌弃置（包括不可弃置牌）。不赠送可跳过效果。" if view.input.type == "gift" else "点击卡牌选择，再使用下方的确认按钮。可悬停查看完整说明。"
	if view.input.type == "hand_limit": instruction = "手牌上限 %d 张。凋萎、巨石、毒药及被玷污的牌不可弃置；若这些牌已超限，保留它们并弃置其余可弃置牌。" % view.hand_limit
	if view.input.type == "discard": instruction = "摸牌已处理，请选择 %d 张手牌弃置。再次点击可取消选择；不可弃置的牌不在列表中。" % view.input.count
	if view.input.type == "discard" and view.input.has("min_count"): instruction = "选择任意张手牌弃置，再摸牌至手牌上限；可以不选牌直接确认。再次点击可取消选择，不可弃置的牌不在列表中。"
	if view.input.type == "search": instruction = "选择要获得的一张牌，再点击「确认获取」。只有你能查看这次选牌。"
	if view.input.type == "plunder": instruction = "这里显示目标的全部手牌。选择一张后点击「确认掠夺」，将它加入自己的手牌。"
	if view.input.type == "defile": instruction = "这里显示目标的全部手牌。选择一张后点击「确认玷污」，该实体牌将无法打出或弃置。"
	if view.input.type == "deck" and view.input.get("accept_count",view.input.count) < view.input.count: instruction = "按点击顺序编号：前 %d 张加入手牌，其余保持牌背返回抽牌堆。再次点击可取消选择。" % view.input.accept_count
	_text(panel,instruction,Rect2(20,63,1068,25),14,BLUE if view.input.type == "gift" else SOFT)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(scroll,panel,Rect2(22,88,1064,360))
	var grid := HFlowContainer.new()
	grid.set_meta("picker_grid",true)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",13); grid.add_theme_constant_override("v_separation",15)
	scroll.add_child(grid)
	var scroll_key := "pick_%s" % view.revision
	scroll.set_meta("scroll_key",scroll_key)
	_restore_scroll(scroll,scroll_key,true)
	var options: Array = view.input.options.duplicate()
	if browsing_deck:
		options.sort_custom(func(a,b):
			var ca: Dictionary = view.catalog[a]; var cb: Dictionary = view.catalog[b]
			if ca.main != cb.main: return ca.main > cb.main
			if ca.secondary != cb.secondary: return ca.secondary > cb.secondary
			return a < b)
	for id in options:
		var b = _card(grid,view.catalog[id],false,false,ui.pick_cards.has(id))
		b.card_size=Vector2(120,171);b.custom_minimum_size=b.card_size
		b.set_meta("pick_card_id",int(id))
		if view.input.type in ["deck","gift"] and ui.pick_cards.has(id):
			b.selection_order = ui.pick_cards.find(id)+1
		b.disabled = ui.submitting
		b.pressed.connect(func():
			if ui.pick_cards.has(id): ui.pick_cards.erase(id)
			elif ui.pick_cards.size() < view.input.count: ui.pick_cards.append(id)
			ui._schedule_render())
	if browsing_deck:
		var empty: Label = ui._label(grid,"没有找到匹配的卡牌。",18,SOFT)
		empty.set_meta("picker_empty",true)
		_filter_deck_cards(grid,ui.picker_query)
		search.text_changed.connect(func(value):
			ui.picker_query = value
			clear_card_hover()
			_filter_deck_cards(grid,value)
			var auto: Button = panel.get_meta("auto_pick_button",null)
			if auto != null: auto.disabled = ui.submitting or _matching_deck_options(options).size() < view.input.count
			scroll.scroll_vertical = 0
			ui.table_scrolls[scroll_key] = 0)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation",12)
	_place(controls,panel,Rect2(22,470,1064,38))
	var valid: bool = ui.pick_cards.size() <= view.input.count if view.input.type == "bonus" else (ui.pick_cards.size() >= 1 and ui.pick_cards.size() <= view.input.count) if view.input.type == "gift" else ui.pick_cards.size() == view.input.count
	if view.input.type == "discard" and view.input.has("min_count"): valid = ui.pick_cards.size() >= view.input.min_count and ui.pick_cards.size() <= view.input.count
	var confirm := _control(controls,{"gift":"确认赠送","hand_limit":"确认弃牌","discard":"确认弃牌","search":"确认获取","defile":"确认玷污","plunder":"确认掠夺"}.get(view.input.type,"确认选牌")+" (%d/%d)" % [ui.pick_cards.size(),view.input.count],func(): ui._send_pick(ui.pick_cards.duplicate(),int(view.revision)),true)
	if view.input.type == "discard" and view.input.has("min_count"): confirm.text = "确认弃置 %d 张并补牌" % ui.pick_cards.size()
	confirm.set_meta("pick_confirm",true)
	confirm.disabled = not valid or ui.submitting
	if view.input.type != "hand_limit":
		var auto := _control(controls,"自动选择",func():
			var candidates: Array = _matching_deck_options(options) if browsing_deck else options
			if candidates.size() >= view.input.count: ui._send_pick(candidates.slice(0,view.input.count),int(view.revision)))
		panel.set_meta("auto_pick_button",auto)
		auto.set_meta("auto_pick",true)
		if browsing_deck: auto.disabled = ui.submitting or _matching_deck_options(options).size() < view.input.count
	var skip_button: Button
	if view.input.get("can_skip",false): skip_button = _control(controls,"跳过效果",func(): ui._skip_effect(int(view.revision)))
	if not view.active_card.is_empty():
		var details := _control(controls,"查看卡牌效果",func(): _show_card(view.active_card))
		if skip_button != null:
			var button_size := skip_button.get_combined_minimum_size().max(details.get_combined_minimum_size())
			skip_button.custom_minimum_size = button_size
			details.custom_minimum_size = button_size

func _filter_deck_cards(grid: Container, query: String) -> void:
	var needle := query.strip_edges().to_lower()
	var count := 0
	for child in grid.get_children():
		if child is Card:
			child.visible = needle.is_empty() or str(child.card.name).to_lower().contains(needle)
			if child.visible: count += 1
	for child in grid.get_children():
		if child.get_meta("picker_empty",false): child.visible = count == 0

func _matching_deck_options(options: Array) -> Array:
	var needle: String = ui.picker_query.strip_edges().to_lower()
	return options.filter(func(id): return needle.is_empty() or str(view.catalog[id].name).to_lower().contains(needle))

func _inspection() -> void:
	var panel := _box(Rect2(244,247,952,439),Color("f3e6cc"),EDGE)
	panel.z_index = 10
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_input_heading(panel,Rect2(20,12,912,55))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(scroll,panel,Rect2(22,67,908,295))
	_restore_scroll(scroll,"inspect_%s" % view.revision,true)
	var grid := HFlowContainer.new(); grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",12); grid.add_theme_constant_override("v_separation",12)
	scroll.add_child(grid)
	for id in view.input.cards: _inspection_card(grid,view.catalog[id],false)
	for id in view.input.get("deaths",[]): _inspection_card(grid,view.death_catalog[id],true)
	if view.input.cards.is_empty() and view.input.get("deaths",[]).is_empty(): ui._label(grid,"目标没有手牌或亡语牌。",18,SOFT)

	_button(panel,"查看完毕",Rect2(732,377,198,40),func(): ui._send_pick([],int(view.revision)),ui.submitting,true)

func _inspection_card(parent: Node, info: Dictionary, death: bool) -> void:
	var b = _card(parent,info,death)
	b.set_meta("inspect_key","inspection_%s_%d_%d" % [str(death),view.revision,info.id])
	b.set_meta("inspection_card",int(info.id))

func _add_polished_gem() -> void:
	var stamp:="%d/%d/%s"%[view.match,view.animation.id,view.animation.stage]
	if ui.effect_key!=stamp:ui.effect_key=stamp;ui.effect_started=Time.get_ticks_msec()
	var gem=preload("res://scripts/gem_animation.gd").new()
	canvas.add_child(gem);gem.set_meta("gem_animation",view.animation.id)
	gem.initialize(self,ui.effect_started)
