extends Control
## A physical card flips in its existing table slot. Both faces
## are rendered by the game's own card widget, preserving its paper and type.
const Card=preload("res://scripts/card_widget.gd")
const DURATION := 0.68
const UNREVEALED_TINT := Color(0.56,0.56,0.56,1.0)
var source:Control
var front_view:SubViewport
var initial_view:SubViewport
var progress:=0.0
var friendly:=false
var initial_hidden:=true
var final_hidden:=false
var final_tint := Color.WHITE
var started_ms:=-1
var source_visible:=true
var status_text:=""

func initialize(widget:Control,own:bool,was_hidden:bool,started:int=-1,to_back:bool=false)->void:
	source=widget;friendly=own;initial_hidden=was_hidden
	final_hidden=to_back and not own
	final_tint=UNREVEALED_TINT if to_back and own else Color.WHITE
	started_ms=started
	source_visible=source.visible
	if is_instance_valid(source.status_label):
		status_text=source.status_label.text
		source.status_label.text="盖牌中" if to_back else "翻开中"
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	position=widget.position;size=widget.size*widget.scale
	z_index=15
	front_view=_face(final_hidden,final_tint)
	initial_view=_face(was_hidden,UNREVEALED_TINT if own and not to_back and not was_hidden else Color.WHITE)
	source.visible=false
	set_meta("card_conceal_action" if to_back else "card_reveal_action",source.get_meta("played_action_id",-1))
	set_progress(clampf((Time.get_ticks_msec()-started_ms)/(DURATION*1000),0,1) if started_ms>=0 else 0)

func _face(hidden:bool,modulation:Color)->SubViewport:
	var viewport:=SubViewport.new()
	viewport.transparent_bg=true
	viewport.size=Vector2i(source.size*3)
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	viewport.gui_disable_input=true
	add_child(viewport)
	var widget=Card.new()
	widget.card=source.card.duplicate(true)
	widget.card_size=source.size;widget.size=source.size;widget.scale=Vector2.ONE*3
	widget.hidden_card=hidden;widget.compact=source.compact;widget.death=source.death
	widget.priority_bonus=source.priority_bonus
	widget.self_modulate=modulation
	widget.add_theme_font_override("font",source.get_theme_font("font"))
	widget.mouse_filter=Control.MOUSE_FILTER_IGNORE
	viewport.add_child(widget)
	widget.set_process(false)
	return viewport

func set_progress(value:float)->void:
	progress=clampf(value,0,1)
	queue_redraw()

func _process(_delta:float)->void:
	if started_ms<0:return
	set_progress((Time.get_ticks_msec()-started_ms)/(DURATION*1000))
	if progress>=1:dispose()

func pose()->Dictionary:
	var turn:=smoothstep(.09,.87,progress)
	var angle:=turn*PI
	var lift:=sin(progress*PI)
	var enlargement:=1.0+.08*lift
	# Both rows lean toward the empty middle lane, away from pawn health.
	var center:=size/2+Vector2(0,(-9 if friendly else 9)*lift)
	var points:=PackedVector2Array()
	var distance:=size.x*4.2
	for corner in [Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)]:
		var v:Vector2=corner*size*enlargement
		var depth:float=-v.x*sin(angle)
		var perspective:float=distance/(distance+depth)
		points.append(center+Vector2(v.x*cos(angle),v.y)*perspective)
	return {"points":points,"turned":turn>=.5,"lift":lift,"angle":angle,"center":center}

func _draw()->void:
	if not is_instance_valid(front_view):return
	var state:=pose()
	var points:PackedVector2Array=state.points
	var shadow:=PackedVector2Array()
	for p in points:shadow.append(p+Vector2(2+state.lift*2,4+state.lift*5))
	for i in range(5,0,-1):
		var edge:=shadow.duplicate();edge.append(edge[0])
		draw_polyline(edge,Color(.19,.13,.1,.012),i*2.5,true)
	if absf(cos(state.angle))>.025:draw_colored_polygon(shadow,Color(.19,.13,.1,.055))
	var uv:=PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
	if state.turned:
		uv=PackedVector2Array([Vector2(1,0),Vector2(0,0),Vector2(0,1),Vector2(1,1)])
	var texture:Texture2D=front_view.get_texture() if state.turned else initial_view.get_texture()
	var shade:float=1.0-.2*pow(sin(state.angle),2)
	if absf(cos(state.angle))>.025:
		draw_polygon(points,PackedColorArray([Color(shade,shade,shade,1)]),uv,texture)
	else:
		# A narrow paper edge bridges the face swap; text is never mirrored.
		draw_line(state.center+Vector2(0,-size.y*.54),state.center+Vector2(0,size.y*.54),Color("c1a375"),1.5,true)

func dispose()->void:
	_restore_source()
	queue_free()

func _restore_source()->void:
	if is_instance_valid(source):
		source.visible=source_visible
		source.hidden_card=final_hidden
		source.self_modulate=final_tint
		if is_instance_valid(source.status_label):source.status_label.text=status_text

func _exit_tree()->void:
	_restore_source()
