extends Control
## Independent preview prop. Cards can pass between the painted cavity and lip.
const Art=preload("res://scripts/cinema/atlas.gd")
# Follow the INSIDE edge of the leather lip, not its lower stitching. The
# complete painted lip must be in front of cards entering/leaving the cavity.
const FRONT_EDGE=[Vector2(0,.300),Vector2(.207,.300),Vector2(.214,.325),Vector2(.24,.345),Vector2(.30,.365),Vector2(.40,.381),Vector2(.50,.386),Vector2(.59,.381),Vector2(.67,.365),Vector2(.72,.340),Vector2(.742,.308),Vector2(.748,.278),Vector2(.760,.256),Vector2(1,.256),Vector2.ONE,Vector2(0,1)]
var opened=0.0
var side=150.0
var opacity=1.0
var front
class Front extends Control:
	var bag
	func _draw():bag.paint_front(self)
func _init():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	front=Front.new();front.bag=self;front.z_index=8;add_child(front)
func present(at,amount,alpha=1.0,angle=0.0,extent=150.0):
	position=at;opened=clampf(amount,0,1);opacity=alpha;rotation=angle;side=extent
	queue_redraw();front.queue_redraw()
func mouth():return position+Vector2(-.025,-.208).rotated(rotation)*side
func _draw():
	Art.draw_prop(self,"prepared",Vector2.ZERO,side,0,opacity*(1-opened))
	Art.draw_prop(self,"prepared_open",Vector2.ZERO,side,0,opacity*opened)
func paint_front(canvas):
	if opened<.001 or opacity<.001:return
	var tex=Art.texture("prepared_open")
	var pts=PackedVector2Array();var uv=PackedVector2Array()
	for q in FRONT_EDGE:
		pts.append((q-Vector2(.5,.5))*side)
		uv.append((tex.region.position+q*tex.region.size)/tex.atlas.get_size())
	canvas.draw_polygon(pts,PackedColorArray([Color(1,1,1,opacity*opened)]),uv,tex.atlas)
