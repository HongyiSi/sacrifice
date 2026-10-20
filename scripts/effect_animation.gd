extends Control
## Pure presentation: authoritative snapshots change HP only at the impact boundary.
var event: Dictionary = {}
var mine := 0
var source := Vector2(720,440)
var elapsed := 0.0
var clock_started := -1
const StrikeStyles = preload("res://scripts/strike_styles.gd")
const StrikeEffects = preload("res://scripts/strike_effects.gd")
const CardLaunch = preload("res://scripts/card_emblem_launch.gd")
const AttackRewards = preload("res://scripts/attack_rewards.gd")
const AmuletCancel = preload("res://scripts/amulet_cancel_effect.gd")
var cancel_target: Control
var amulet_effect: RefCounted
var attack_reward: RefCounted
var strike_effect: RefCounted
var card_effect: RefCounted
var target_point := Vector2.ZERO
var sprites: Dictionary = {}
var source_widget: Control
var icon_side := 46.0
var launch_effect: RefCounted
var feedback_obstacles: Array = []
var feedback_positions: Dictionary = {}
var obstacle_provider: Callable
var outgoing_cards: Array = []
var motion_points: Array = []
var motion_faces: Array = []
var marked_points: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	if AmuletCancel.supports(event) and is_instance_valid(cancel_target) and is_instance_valid(source_widget):
		amulet_effect = AmuletCancel.new(self)
		return
	if AttackRewards.supports(event):
		attack_reward = AttackRewards.new(self)
		return
	if CardLaunch.supports(event): launch_effect = CardLaunch.new(self)
	if event.get("kind","") == "strike" or (event.get("kind","") == "shield_block" and StrikeStyles.PROFILES.has(event.get("style",""))): strike_effect = StrikeEffects.new(self)
	elif event.get("kind","") in ["card_effect","death_strike"]: card_effect = preload("res://scripts/card_motif_effects.gd").new(self)

func _process(delta: float) -> void:
	# Use the same monotonic clock as the host, including after a UI rebuild.
	# Frame deltas can be clamped or stretched during window resizing/loading.
	if clock_started >= 0: elapsed = (Time.get_ticks_msec()-clock_started)/1000.0
	else: elapsed += delta
	_reset_sprites()
	if amulet_effect != null:
		amulet_effect.update(clampf(elapsed/(StrikeStyles.duration(event)/1000.0),0,1))
		queue_redraw()
		return
	if event.get("stage","")=="travel" and not outgoing_cards.is_empty():
		var progress:=clampf(elapsed/(StrikeStyles.duration(event)/1000.0),0,1)
		# Preserve the old hand until the approved dice motion has settled.
		if event.get("style","")=="gambler" and event.get("op","")=="discard_all":progress=.32+(progress-.69)*(.49-.32)/(.77-.69)
		for i in range(outgoing_cards.size()):
			var item:Dictionary=outgoing_cards[i]
			if not is_instance_valid(item.node):continue
			if event.has("hand_motion"):
				var spread:float=minf(.34,(outgoing_cards.size()-1)*.055)
				var delay:float=spread*i/maxi(1,outgoing_cards.size()-1)
				var u:float=clampf((progress-.16-delay)/(.84-spread),0,1)
				item.node.modulate.a=item.alpha*(1-smoothstep(0,.08,u))
			else:item.node.modulate.a=item.alpha*(1-smoothstep(.32,.49,progress-i*.03))
	if launch_effect != null:
		var t := clampf(elapsed/(StrikeStyles.duration(event)/1000.0),0,1)
		_card_origin(t)
		_card_driven_pose(t)
	elif event.get("kind","") in ["strike","death_strike"] and event.stage == "impact":
		var t := clampf(elapsed/(StrikeStyles.duration(event)/1000.0),0,1)
		for target in event.targets:
			if target.get("amount",0) <= 0 or not sprites.has(target.id): continue
			var saved: Dictionary = sprites[target.id]
			if not is_instance_valid(saved.node): continue
			saved.node.position = saved.position+Vector2(sin(elapsed*58)*4*(1-t),0)
			saved.node.modulate = saved.color.lerp(Color(1,0.55,0.45,saved.color.a),maxf(0,sin(elapsed*22))*0.55*(1-t))
	elif event.get("kind","") == "card_effect" and event.stage == "impact" and event.get("motif","") in ["revive","phoenix","ghost","divinity"]:
		var t := clampf(elapsed/(StrikeStyles.duration(event)/1000.0),0,1)
		for target in event.targets:
			if not sprites.has(target.id): continue
			var saved: Dictionary = sprites[target.id]
			if not is_instance_valid(saved.node): continue
			saved.node.position = saved.position+Vector2(0,-sin(t*PI)*6)
			saved.node.modulate = saved.color.lerp(Color(event.color),sin(t*PI)*0.38)
	# Reflow feedback when the raised card finishes moving or the window changes.
	# Keeping the first frame's rectangles can put a label under the settled card.
	if obstacle_provider.is_valid():
		var current_obstacles: Array = obstacle_provider.call()
		if current_obstacles != feedback_obstacles:
			feedback_obstacles = current_obstacles
			feedback_positions.clear()
	queue_redraw()

func _card_origin(t: float) -> void:
	if not is_instance_valid(source_widget): return
	source = get_global_transform().affine_inverse()*(source_widget.get_global_transform()*source_widget.emblem_center())
	icon_side = minf(source_widget.size.x-25,42 if source_widget.compact else 46)*source_widget.scale.x
	if source_widget.expanded: return
	source_widget.motif_alpha = 0.0 if event.stage == "travel" else smoothstep(.25,.75,t)
	source_widget.rotation = -.018*sin(t*PI) if event.stage == "travel" else 0.0
	source_widget.queue_redraw()

func _reset_sprites() -> void:
	for saved in sprites.values():
		if not is_instance_valid(saved.node): continue
		saved.node.position = saved.position
		saved.node.modulate = saved.color
		saved.node.rotation = saved.get("rotation",0.0)
		saved.node.scale = saved.get("scale",Vector2.ONE)
		saved.node.pivot_offset = saved.get("pivot",Vector2.ZERO)

func _card_driven_pose(t: float) -> void:
	var actor: int = event.action.actor
	var blade: bool = event.kind in ["strike","shield_block"] and StrikeStyles.PROFILES.has(event.get("style",""))
	if blade and not event.targets.is_empty():
		var target: int = event.targets[0].id
		var direction := (_knight(target)-_knight(actor)).normalized()
		var effort := 12.0 if event.style == "strike" else 16.0 if event.style == "double_strike" else 20.0
		if sprites.has(actor):
			var saved: Dictionary = sprites[actor]
			var travel := clampf((t-CardLaunch.AIM_END)/(1-CardLaunch.AIM_END),0,1)
			var distance := effort*travel*travel if event.stage == "travel" else effort*(1-smoothstep(.08,.55,t))
			saved.node.position = saved.position+direction*distance
		if event.kind == "strike" and event.stage == "impact":
			for hit in event.targets:
				if hit.get("amount",0) <= 0 or not sprites.has(hit.id): continue
				var saved: Dictionary = sprites[hit.id]
				var back := 1-smoothstep(.08,.58,t)
				var hit_direction := (_knight(hit.id)-_knight(actor)).normalized()
				saved.node.pivot_offset = Vector2(saved.node.size.x*.5,saved.node.size.y*.88)
				saved.node.position = saved.position+hit_direction*(11*back+sin(t*16)*2*(1-t))
				saved.node.rotation = .08*back*signf(hit_direction.y)
				saved.node.scale = saved.scale*Vector2(1+.045*back,1-.035*back)
				saved.node.modulate = saved.color.lerp(Color(1,.73,.60,saved.color.a),.45*back)
	elif event.kind == "heal" and event.stage == "impact":
		for target in event.targets:
			if not sprites.has(target.id) or target.get("amount",0) <= 0: continue
			var saved: Dictionary = sprites[target.id]
			var lift := sin(t*PI)*6
			saved.node.position = saved.position+Vector2(0,-lift)
			saved.node.scale = saved.scale*Vector2(1-lift*.002,1+lift*.002)
	if event.kind == "shield_block" and event.stage == "impact":
		for target in event.targets:
			if sprites.has(target.id): sprites[target.id].node.position = sprites[target.id].position+Vector2(0,3*sin(t*PI))

func _exit_tree() -> void:
	if amulet_effect != null:
		amulet_effect.dispose()
		amulet_effect = null
	_reset_sprites()
	for item in outgoing_cards:
		if is_instance_valid(item.node):item.node.modulate.a=item.alpha
	if is_instance_valid(source_widget):
		source_widget.motif_alpha = 1.0
		source_widget.rotation = 0
		source_widget.queue_redraw()

func feedback_rect(at: Vector2,label: String,font_size: int = 22) -> Rect2:
	var key := str(at)+label+str(font_size)
	if feedback_positions.has(key): return feedback_positions[key]
	var width := minf(320,get_theme_font("font").get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+12)
	var dimensions := Vector2(width,30)
	var best := Rect2(at+Vector2(145,-34),dimensions)
	var best_score := INF
	var positions: Array = []
	for offset in [Vector2(232,-18),Vector2(-152,-18),Vector2(160,-18),Vector2(-175,-75),Vector2(170,-95),Vector2(0,96),Vector2(0,-134)]: positions.append(at+offset)
	# The central lane provides alternatives for long labels on either team.
	for x in range(240,1201,48):
		for y in [350,390,430,530]: positions.append(Vector2(x,y))
	var bounds := Rect2(145,116,1150,764)
	for center in positions:
		var rect := Rect2(center-dimensions/2,dimensions)
		if not bounds.encloses(rect.grow(4)): continue
		var offset: Vector2 = center-at
		var score: float = offset.length()*.05
		for obstacle in feedback_obstacles+feedback_positions.values():
			var overlap: Rect2 = rect.grow(18).intersection(obstacle)
			score += overlap.get_area()*100 if overlap.has_area() else 0
		if score < best_score: best = rect; best_score = score
	feedback_positions[key] = best
	return best

func result_text(at: Vector2,label: String,tint: Color,t: float) -> void:
	var fade := 1-smoothstep(.62,1,t)
	var rect := feedback_rect(at,label)
	var baseline := rect.position+Vector2(0,24-9*t)
	var font := get_theme_font("font")
	draw_string_outline(font,baseline,label,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x,22,4,Color(.15,.16,.13,fade))
	draw_string(font,baseline,label,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x,22,Color(tint,fade))

func _floating_text(at: Vector2, label: String, tint: Color, t: float) -> void:
	var fade := 1.0-smoothstep(0.62,1,t)
	var position := at+Vector2(-115,-79-18*t)
	var font := get_theme_font("font")
	draw_string_outline(font,position,label,HORIZONTAL_ALIGNMENT_CENTER,230,24,4,Color(0.18,0.14,0.15,fade))
	draw_string(font,position,label,HORIZONTAL_ALIGNMENT_CENTER,230,24,Color(tint,fade))

func _knight(id: int) -> Vector2:
	return preload("res://scripts/board_layout.gd").pawn_center(id,id/3 == mine)

func _glow(at: Vector2, color: Color, radius: float, strength: float) -> void:
	for i in range(7,0,-1):
		draw_circle(at,radius*i/3.5,Color(color,strength*0.055*(8-i)))
	draw_circle(at,radius*0.23,Color("f3ffe1")*Color(1,1,1,strength))

func _flight(at: Vector2, t: float, color: Color) -> void:
	var control := (source+at)/2+Vector2(0,-85)
	for i in range(18,-1,-1):
		var u := clampf(t-i*0.017,0,1)
		var point := source.lerp(control,u).lerp(control.lerp(at,u),u)
		draw_circle(point,3.5*(1.0-i/20.0),Color(color,(1.0-i/20.0)*0.75))
	var orb := source.lerp(control,t).lerp(control.lerp(at,t),t)
	_glow(orb,color,17,1)
	for i in range(5):
		var angle := elapsed*8+i*TAU/5
		draw_circle(orb+Vector2(cos(angle),sin(angle))*19,2.5,Color(color,0.8))

func _shield(at: Vector2, growth: float, alpha: float) -> void:
	var shape := PackedVector2Array()
	for p in [Vector2(0,-53),Vector2(43,-35),Vector2(34,23),Vector2(0,54),Vector2(-34,23),Vector2(-43,-35)]:
		shape.append(at+p*growth)
	draw_colored_polygon(shape,Color(0.27,0.64,0.98,0.25*alpha))
	shape.append(shape[0])
	draw_polyline(shape,Color(0.75,0.92,1,alpha),4,true)
	draw_line(at+Vector2(0,-29)*growth,at+Vector2(0,25)*growth,Color(0.9,0.94,0.67,alpha),4,true)
	draw_line(at+Vector2(-20,-8)*growth,at+Vector2(20,-8)*growth,Color(0.9,0.94,0.67,alpha),4,true)

func _draw() -> void:
	if event.is_empty(): return
	if amulet_effect != null:
		amulet_effect.draw(clampf(elapsed/(StrikeStyles.duration(event)/1000.0),0,1))
		return
	if event.kind == "card_start": return
	var impact: bool = event.stage == "impact"
	var t := clampf(elapsed/(StrikeStyles.duration(event)/1000.0),0,1)
	if attack_reward != null:
		attack_reward.draw(t)
		return
	if launch_effect != null and not impact:
		launch_effect.travel(t)
		return
	if launch_effect != null and impact and event.kind in ["heal","blessing","shield_block"] and event.get("style","") in ["team_heal","heal_other","blood_rite","blessing","holy_amulet","attack_amulet","magic_amulet"]:
		launch_effect.support_impact(t)
		return
	if strike_effect != null and event.kind == "strike":
		strike_effect.draw(t,impact)
		if launch_effect != null and impact: launch_effect.impact(t)
		return
	if card_effect != null:
		card_effect.draw(t,impact)
		return
	var healing: bool = event.kind == "heal"
	var color := preload("res://scripts/card_palette.gd").glow(str(event.get("style","defense")))
	if not impact:
		_glow(source,color,25,0.5+0.3*sin(t*PI))
		# The source card shines before energy leaves it.
		draw_arc(source,48,0,TAU,48,Color(color,0.6*(1-t)),3,true)
	for target in event.targets:
		var at := _knight(int(target.id))
		if not impact:
			if event.kind == "shield_block":
				_shield(at,0.8+0.2*sin(t*PI/2),0.8)
				_flight(at,t,Color("ffd98a"))
			else: _flight(at,t,color)
		else:
			var fade := 1.0-smoothstep(0.55,1.0,t)
			if healing and target.get("heal_blocked",false):
				_shield(at,1,fade)
				result_text(at,"保佑 · 无法回复生命",Color("f0d7a3"),t)
				continue
			_glow(at,color,36+18*t,0.7*fade)
			draw_arc(at,28+t*55,0,TAU,64,Color(color,0.85*(1-t)),3,true)
			if not healing: _shield(at,1+0.08*sin(t*PI),fade)
			for i in range(12):
				var angle := i*TAU/12+t*0.8
				var particle := at+Vector2(cos(angle),sin(angle))*(30+t*52)
				particle.y -= t*28
				draw_circle(particle,2.4,Color(color,fade))
			var label: String = ("+%d  生命" % target.amount if target.amount > 0 else "生命已满") if healing else ("抵挡！" if event.kind == "shield_block" else "保佑" if event.kind == "blessing" else "+1  防御")
			if target.get("max_bonus",0) > 0: label = "上限 +2 · " + ("回满生命" if target.after > 0 else "保持阵亡")
			if target.get("heal_blocked",false): label = "上限 +2 · 无法回复" if target.get("max_bonus",0) > 0 else "保佑 · 无法回复生命"
			result_text(at,label,Color("d8ffe3"),t)
