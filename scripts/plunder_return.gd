extends RefCounted
const Art=preload("res://scripts/cinema/atlas.gd")
const Pose=preload("res://scripts/ordinary_pose.gd")
const Layout=preload("res://scripts/board_layout.gd")
var h
var overlay
var flights=[]
var source
func setup(host):
	h=host;flights=h.flights.filter(func(f):return f.source_key=="plunder")
	source=h.board._active_widget()
	overlay=Control.new();overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.z_index=95
	h.add_child(overlay);overlay.draw.connect(draw)
func pose(f):
	var t=clampf((h.tick-f.started)/f.duration,0,1)
	var from=f.origin
	var target=f.node.get_meta("goal",Layout.hand_position(f.id,0,f.id/3==h.mine))+f.node.pivot_offset
	var catch_t=smoothstep(0,.20,t)
	var go=smoothstep(.22,1,t)
	return {"t":t,"q":from.lerp(target,go)+Vector2(0,-sin(go*PI)*75),"go":go,"catch":catch_t}
func update():
	if is_instance_valid(source):source.motif_alpha=0.;source.queue_redraw()
	for f in flights:
		var p=pose(f);var c=f.node
		c.position=p.q-c.pivot_offset;c.scale=Vector2.ONE*lerpf(Layout.hand_scale(f.id/3!=h.mine),Layout.hand_scale(f.id/3==h.mine),p.go)
		c.rotation=-.1*sin(p.go*PI);c.modulate.a=1.
		c.hidden_card=c.card.is_empty();c.queue_redraw()
	overlay.queue_redraw()
func restore():
	if is_instance_valid(source):source.motif_alpha=1.;source.queue_redraw()
func draw():
	for f in flights:
		var p=pose(f)
		var source_actor=h.event.draws[0].origin.actor
		var start=Pose.dock(source_actor,h.mine,"plunder")
		var card_scale=lerpf(Layout.hand_scale(f.id/3!=h.mine),Layout.hand_scale(f.id/3==h.mine),p.go)
		var offset=Vector2(15,-32-54*card_scale)
		var pos=start.lerp(f.origin+offset,p.catch) if p.t<.22 else p.q+offset
		Art.draw_prop(overlay,"plunder",pos,lerpf(91.,70.,p.catch),.12*sin(p.go*PI),1-smoothstep(.86,1,p.t))
