extends RefCounted
## Painted emblems travel directly from the active card into real hand slots.
const Art=preload("res://scripts/cinema/atlas.gd")
const Layout=preload("res://scripts/board_layout.gd")
const Frame=preload("res://scripts/art_ui/frame_design.gd")
var host
var source
var key=""
var flights=[]
var origin=Vector2.ZERO
var source_side=44.0
var accepted=0
var overlay
static func stone_part(i,side):
	return {"offset":Vector2(-.19,-.12)*side,"side":side*.60,"angle":-.10} if i==0 else {"offset":Vector2(.18,.14)*side,"side":side*.67,"angle":.07}
func setup(control):
	host=control;source=host.board._active_widget()
	flights=host.flights.filter(func(v):return v.get("direct",false))
	key=flights[0].source_key;accepted=flights.size()
	overlay=Control.new();overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.size=host.size;overlay.z_index=95
	host.add_child(overlay);overlay.draw.connect(draw)
	refresh_origin()
func refresh_origin():
	if not is_instance_valid(source):
		origin=flights[0].origin;return
	var w=source.size.x;var body=Rect2(w/76.,0,w-w/38.,source.size.y-w/19.)
	var rect=Frame.scaled(Frame.layout(Frame.style).art,body)
	var tr=host.board.canvas.get_global_transform().affine_inverse()*source.get_global_transform()
	origin=tr*rect.get_center()
	source_side=minf(rect.size.x,rect.size.y)*tr.get_scale().x
	if key=="poisoning":
		var dimensions=Art.texture("poison").get_size()
		source_side=maxf(dimensions.x,dimensions.y)*minf(rect.size.x/dimensions.x,rect.size.y/dimensions.y)*tr.get_scale().x
	source.motif_alpha=0.;source.queue_redraw()
func printed(i):
	return stone_part(i,source_side) if key=="obstruct" else {"offset":Vector2.ZERO,"side":source_side,"angle":0.}
func endpoint(f):
	var own=f.id/3==host.mine;var c=f.node
	var scale=Layout.hand_scale(own)
	return goal(f)+c.pivot_offset+(c.emblem_center()-c.pivot_offset)*scale
func goal(f):
	var own=f.id/3==host.mine;var c=f.node
	var fallback=Layout.hand_position(f.id,host.rows[f.id].cards.find(c),own)-c.pivot_offset*(Vector2.ONE-Vector2.ONE*Layout.hand_scale(own))
	return c.get_meta("goal",fallback)
func pose(f,age):
	var t=clampf(age/f.duration,0,1);var part=printed(f.prop_index)
	var start=origin+part.offset;var end=endpoint(f)
	var u=smoothstep(0,1,t)
	# Follow one uninterrupted arc; reduce the bend near the upper edge.
	var bend=-minf(62.,maxf(24.,minf(start.y,end.y)-110.))
	var at=start.lerp(end,u)+Vector2(0,bend*sin(u*PI))
	var final_side=(55.64 if key=="poisoning" else 53.28)*Layout.hand_scale(f.id/3==host.mine)
	var side=lerpf(part.side,final_side,u)+sin(t*PI)*(44. if key=="obstruct" else 39.)
	var turn=(-.27 if f.prop_index==0 else .25)*sin(t*PI)
	return {"at":at,"side":side,"angle":part.angle*(1-u)+turn,"t":t}
func update():
	refresh_origin()
	for f in flights:
		var c=f.node;var age=host.tick-f.started;var t=clampf(age/f.duration,0,1)
		var scale=Layout.hand_scale(f.id/3==host.mine)
		c.position=goal(f);c.scale=Vector2.ONE*scale;c.rotation=0
		# Until the object docks, this slot has no already-placed card.
		c.modulate.a=smoothstep(.89,1.,t)
		c.motif_alpha=smoothstep(.92,1.,t)
		c.hidden_card=c.card.is_empty();c.queue_redraw()
	overlay.queue_redraw()
func restore():
	if is_instance_valid(source):source.motif_alpha=1.;source.queue_redraw()
func draw():
	# A rejected second stone stays printed; only accepted cards fly.
	if key=="obstruct" and accepted==1:
		var p=printed(1);Art.draw_prop(overlay,"boulder",origin+p.offset,p.side,p.angle)
	for f in flights:
		var age=host.tick-f.started;var p=pose(f,age);var t=p.t
		if age<f.duration:
			var a=1-smoothstep(.93,1.,t)
			# A short, subdued painted echo supplies motion without covering the board.
			if t>.06 and t<.90:
				for j in range(3,0,-1):
					var q=pose(f,maxf(0,age-j*.026))
					Art.draw_prop(overlay,f.prop_key,q.at,q.side,q.angle,.045*(1-j/4.))
			Art.draw_prop(overlay,f.prop_key,p.at,p.side,p.angle,a)
		else:
			var tail=age-f.duration
			if tail>.36:continue
			var a=(1-smoothstep(.03,.36,tail))*.25
			var end=endpoint(f)
			if key=="obstruct":
				for j in range(5):
					var dir=Vector2.from_angle(.4+j*2.399)
					Art.draw_prop(overlay,"boulder",end+dir*(13+tail*43)+Vector2(0,tail*12),2.8+j%2,j*.7,a)
