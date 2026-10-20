extends Control
## A nonblocking, continuous overlay attached to one knight. State comes from
## the host snapshot; absolute time preserves the pulse across board rebuilds.
const Motifs = preload("res://scripts/card_effects.gd")
const Styles = preload("res://scripts/card_effect_styles.gd")
const NAMES := {"anticipation":"预判封锁 · 本回合不可翻牌","warcry":"战吼","greed":"贪婪","defense":"防御","blessing":"保佑","prison":"禁锢","privilege":"特权","ghost":"幽灵","pain":"苦肉","eye":"天眼","divinity":"神化","immortal":"不死","prophecy":"预言","overload":"过载","silence":"沉默","heart":"心脏","mirror":"魔镜","curse":"凋萎"}
const MARKER_RADIUS := 18.5
const MARKER_PITCH := 40.0
var statuses: Array = []
var actor_id := 0
var elapsed := 0.0
var event: Dictionary = {}
var painters: Dictionary = {}

static func description(status: Dictionary) -> String:
	var name: String = NAMES.get(status.key,status.key)
	match status.key:
		"rally": return "摇旗 · 额外出牌+%d（%s）" % [status.count,"下回合" if status.waiting else "本回合"]
		"defense": return "防御×%d" % status.count
		"blessing": return "保佑（攻击免疫 · 无法回复生命）"
		"prophecy": return "预言%d" % status.count
		"warcry": name += "攻击+%d" % status.count
		"greed": return "贪婪（后续回合多摸1张、多出1张）"
		"heart": name += "+%d" % status.count
	if status.dormant: return name+"（待死亡）" if status.key != "immortal" else name+"（待存活队友）"
	if status.key == "mirror": return "魔镜（待翻牌）"
	if status.key in ["overload","silence","heart","warcry"]: return name+"（下回合）" if status.waiting else name+"（本回合）"
	return name

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("status_actor",actor_id)
	for status in statuses:
		if status.key in ["defense","blessing","rally"]: continue
		event = Styles.profile(status.key)
		painters[status.key] = Motifs.new(self)
		painters[status.key].stroke_scale = 1.4
	_process(0)

func _process(_delta: float) -> void:
	elapsed = Time.get_ticks_msec()/1000.0
	queue_redraw()

func _shield(at: Vector2, size_factor: float, alpha: float, gold: bool = false) -> void:
	var shape := PackedVector2Array()
	for p in [Vector2(0,-53),Vector2(43,-35),Vector2(34,23),Vector2(0,54),Vector2(-34,23),Vector2(-43,-35)]: shape.append(at+p*size_factor)
	var tint := Color("e9d997") if gold else Color("81c9fa")
	draw_colored_polygon(shape,Color(tint,alpha*0.16))
	shape.append(shape[0]); draw_polyline(shape,Color(tint,alpha),2.8,true)
	draw_line(at+Vector2(0,-24)*size_factor,at+Vector2(0,26)*size_factor,Color(tint,alpha*0.6),2.8,true)
	draw_line(at+Vector2(-18,-5)*size_factor,at+Vector2(18,-5)*size_factor,Color(tint,alpha*0.6),2.8,true)

func marker_position(index: int) -> Vector2:
	# Three rows leave the health strip below the pawn unobstructed. Additional
	# columns extend into the side margin instead of overlapping existing badges.
	var column := index/3
	var x := MARKER_RADIUS+1 if column == 0 else size.x-MARKER_RADIUS-1+(column-1)*MARKER_PITCH
	return Vector2(x,20+(index%3)*MARKER_PITCH)

func _draw() -> void:
	var center := Vector2(size.x/2,62)
	for index in range(statuses.size()):
		var status: Dictionary = statuses[index]
		var key: String = status.key
		if key == "rally":
			var at := marker_position(index)
			draw_circle(at,MARKER_RADIUS,Color("51475c"))
			draw_arc(at,MARKER_RADIUS,0,TAU,32,Color("f4d785"),2,true)
			draw_texture_rect(preload("res://scripts/art_symbols.gd").icon(key,"f4d785"),Rect2(at-Vector2(13,13),Vector2(26,26)),false)
			draw_string(get_theme_font("font"),at+Vector2(7,15),str(status.count),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("fff1d6"))
			continue
		var phase := elapsed*1.8+actor_id*0.41+index*0.8
		var pulse := 0.92+0.06*sin(phase)
		var color := Color("81c9fa") if key in ["defense","blessing"] else Color(Styles.profile(key).color)
		if status.dormant: pulse *= 0.72
		if key in ["defense","blessing"]:
			_shield(center,1.02+sin(phase)*0.035,pulse,key == "blessing")
		elif key == "divinity" and not status.dormant:
			pass # The persistent angel form replaces the old sun and floor ring.
		else:
			# Preserve each activation's emblem, small enough to stack around a
			# character without covering their health, cards or target button.
			var painter: RefCounted = painters.get(key)
			if painter == null: continue
			if key == "prison":
				draw_set_transform(center,0,Vector2(0.92,0.92))
				painter._symbol(Vector2.ZERO,fmod(elapsed*0.3,1),pulse*0.95)
			elif key == "privilege":
				draw_set_transform(center+Vector2(0,-46),0,Vector2(0.45,0.45))
				painter._symbol(Vector2.ZERO,fmod(elapsed*0.35,1),pulse)
			else:
				draw_set_transform(center+Vector2(0,38),0,Vector2(1,0.28))
				draw_arc(Vector2.ZERO,48,0,TAU,48,Color(color,pulse*0.8),2.8,true)
				# Retain the activation's actual motif as a quieter loop, with the
				# miniature emblem remaining legible when several effects overlap.
				var offset := Vector2(0,10)
				var factor := Vector2(0.55,0.55)
				if key in ["eye","prophecy"]: offset = Vector2(0,-40); factor = Vector2(0.4,0.4)
				elif key in ["pain","immortal"]: offset = Vector2.ZERO; factor = Vector2(0.78,0.78)
				elif key in ["divinity","curse"]: offset = Vector2(0,36); factor = Vector2(0.9,0.45)
				elif key == "ghost": offset = Vector2(-35,0)
				draw_set_transform(center+offset,0,factor)
				painter._symbol(Vector2.ZERO,fmod(elapsed*0.28,1),pulse*0.98)
			draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
			for i in range(3):
				var angle := elapsed*0.6+i*TAU/3+index
				var point := center+Vector2(cos(angle)*58,sin(angle)*47)
				draw_circle(point,2.2,Color(color,pulse*.95))
		# Fixed locations and small emblems make simultaneous effects legible.
		var marker := marker_position(index)
		draw_circle(marker,MARKER_RADIUS,Color("f1e3c8" if key == "warcry" else "51475c")*Color(1,1,1,0.92 if not status.dormant else 0.67))
		draw_arc(marker,MARKER_RADIUS,0,TAU,32,Color(color,minf(1,pulse+0.12)),2.0,true)
		if key in ["defense","blessing"]: _shield(marker,0.27,1.0,key == "blessing")
		else:
			draw_set_transform(marker,0,Vector2(0.29,0.29))
			painters[key]._symbol(Vector2.ZERO,fmod(elapsed*0.28,1),1.0 if not status.dormant else 0.78)
			draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
		if key in ["defense","prophecy","heart","warcry"]:
			var font := get_theme_font("font")
			draw_string_outline(font,marker+Vector2(7,15),str(status.count),HORIZONTAL_ALIGNMENT_LEFT,-1,15,3,Color("463b39"))
			draw_string(font,marker+Vector2(7,15),str(status.count),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("fff1d6"))
		if status.waiting:
			draw_arc(marker+Vector2(-11,11),4,0,TAU,16,Color("fff1d6"),1.4,true)
