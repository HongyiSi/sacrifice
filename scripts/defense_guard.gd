extends Control
## Same painted shields during arrival, waiting, contact and round cleanup.
const Art=preload("res://scripts/cinema/atlas.gd")
const Layout=preload("res://scripts/board_layout.gd")
var center=Vector2.ZERO
var releasing=false
var clock_started=-1
var elapsed=0.0
var actor=-1
var shield_scale=1.0
static func anchor(board,id):
	return Layout.pawn_center(id,id/3==board.mine)+Vector2(0,26 if id/3==board.mine else 23)
static func scale_for(board,id):return 1.0 if id/3==board.mine else .78
static func paint(c,p,a=1.0,spread=1.0,squash=Vector2.ONE,shield_scale=1.0):
	if a<.002:return
	for h in [-1,1]:
		Art.draw_prop(c,"defense",p+Vector2(h*32*spread,6)*shield_scale,63*shield_scale,h*.38*spread,a*.8,Vector2(.58,1)*squash)
	Art.draw_prop(c,"defense",p,84*shield_scale,0,a,squash)
static func install(board):
	var cache:Dictionary=board.ui.get_meta("defense_guard_states",{})
	var stamp=str(board.view.match)+"/"
	for k in cache.keys():
		if not str(k).begins_with(stamp):cache.erase(k)
	var e:Dictionary=board.view.get("animation",{})
	var now=Time.get_ticks_msec()
	for pawn in board.view.characters:
		var key=stamp+str(pawn.id)
		var targets=e.get("targets",[]).any(func(h):return h.id==pawn.id)
		var applying=targets and e.get("kind","")=="shield" and e.get("style","")=="defense"
		var blocking=targets and e.get("kind","")=="shield_block" and e.get("guard_style","")=="defense"
		if pawn.shield>0:cache[key]={"count":pawn.shield}
		elif blocking:cache.erase(key)
		elif cache.has(key) and not cache[key].has("release"):cache[key].release=now
		if not cache.has(key):continue
		var state:Dictionary=cache[key]
		if state.has("release") and now-int(state.release)>600:cache.erase(key);continue
		# The active animation owns this identical geometry until it settles.
		if applying or blocking:continue
		var node=load("res://scripts/defense_guard.gd").new()
		node.actor=pawn.id;node.center=anchor(board,pawn.id);node.shield_scale=scale_for(board,pawn.id)
		node.releasing=state.has("release");node.clock_started=int(state.get("release",now))
		node.size=Vector2(1440,960);node.z_index=74;node.mouse_filter=Control.MOUSE_FILTER_IGNORE
		node.set_meta("persistent_defense",pawn.id);board.canvas.add_child(node)
	board.ui.set_meta("defense_guard_states",cache)
func _ready():
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_process(0)
func present(seconds):elapsed=maxf(0,seconds);queue_redraw()
func _process(_delta):present((Time.get_ticks_msec()-clock_started)/1000.0)
func _draw():
	var a=1.0-smoothstep(0.,.38,elapsed) if releasing else 1.0
	paint(self,center,a*.93,1.,Vector2.ONE,shield_scale)
