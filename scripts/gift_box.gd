extends Control
const Art=preload("res://scripts/cinema/atlas.gd")
const Layout=preload("res://scripts/board_layout.gd")
const CENTER=Vector2(118,141)
const SIDE=132.0
var opened=1.0
var opacity=1.0
var side=SIDE
var front
static var shadow_texture:GradientTexture2D
class Front extends Control:
	var box
	func _draw():box.draw_front(self)
func _init():
	mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	front=Front.new();front.box=self;front.mouse_filter=Control.MOUSE_FILTER_IGNORE;front.z_index=3;add_child(front)
static func dock(actor,mine):
	var friendly=actor/3==mine
	return Layout.pawn_center(actor,friendly)+Vector2(103,-65 if friendly else 70)
func mouth():return position+Vector2(0,-16)*side/257.0
func present(at,amount,alpha=1.0,angle=0.0,new_side=SIDE):
	position=at;opened=amount;opacity=alpha;rotation=angle;side=new_side
	queue_redraw();front.queue_redraw()
func patch(canvas,key,points,coords,offset=Vector2.ZERO,angle=0.0,pivot=Vector2.ZERO):
	var tex=Art.texture(key);var vertices=PackedVector2Array();var uvs=PackedVector2Array()
	for i in range(points.size()):
		vertices.append(((points[i]-pivot).rotated(angle)+pivot+offset-CENTER)*side/257.0)
		uvs.append((tex.region.position+coords[i])/tex.atlas.get_size())
	canvas.draw_polygon(vertices,PackedColorArray([Color(1,1,1,opacity)]),uvs,tex.atlas)
func _draw():
	if opacity<.001:return
	if shadow_texture==null:
		var grad=Gradient.new();grad.set_color(0,Color(.24,.13,.075,.22));grad.set_color(1,Color(.24,.13,.075,0))
		grad.add_point(.3,Color(.24,.13,.075,.16));grad.add_point(.7,Color(.24,.13,.075,.025))
		shadow_texture=GradientTexture2D.new();shadow_texture.gradient=grad;shadow_texture.width=256;shadow_texture.height=128
		shadow_texture.fill=GradientTexture2D.FILL_RADIAL;shadow_texture.fill_from=Vector2(.5,.5);shadow_texture.fill_to=Vector2(1,.5)
	var factor=side/SIDE
	draw_texture_rect(shadow_texture,Rect2(Vector2(-74,52)*factor,Vector2(148,34)*factor),false,Color(1,1,1,opacity))
	if opened<.001:
		draw_texture_rect(Art.texture("gift_closed"),Rect2(-CENTER*side/257.0,Vector2(236,257)*side/257.0),false,Color(1,1,1,opacity));return
	# Painted interior sampled from the existing open-gift art, fitted to the
	# original closed box's rim. The same atlas supplies both moving halves.
	var mouth_plane=[Vector2(5,125),Vector2(116,76),Vector2(232,124),Vector2(118,164)]
	var paint=[Vector2(7,114),Vector2(87,75),Vector2(187,123),Vector2(114,159)]
	patch(self,"gift",mouth_plane,paint)
	var lid=[Vector2(0,0),Vector2(236,0),Vector2(236,123),Vector2(118,164),Vector2(0,125)]
	var lift=smoothstep(0,1,opened)
	# Move the detached lid to the right of the vertical loading corridor.
	patch(self,"gift_closed",lid,lid,Vector2(180,-58)*lift,.32*lift,Vector2(198,126))
func draw_front(canvas):
	if opacity<.001 or opened<.001:return
	var body=[Vector2(0,125),Vector2(118,164),Vector2(236,123),Vector2(236,257),Vector2(0,257)]
	patch(canvas,"gift_closed",body,body)
