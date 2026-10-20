extends Control
## Right-facing chest: painted volume, projected lid and a foreground rim.
const Art=preload("res://scripts/cinema/atlas.gd")
const Back=preload("res://scripts/art_ui/back_design.gd")
const ORIGIN=preload("res://scripts/board_layout.gd").DECK_CENTER
const BASE_RECT=Rect2(4,68,144,131.42857)
const ART_ORIGIN=Vector2(243,202)
const ART_SCALE=144.0/882.0
const FRONT_Z=145
const DEPARTURE_Z=146
const LID_Z=147
# The long lock face and opposite hinge follow the user's receding cloth edge.
const HINGE_NEAR=Vector2(314,547)
const HINGE_FAR=Vector2(587,232)
const RIM_NEAR=Vector2(799,547)
const RIM_FAR=Vector2(1057,232)
# Trace the cavity-side edge, including both foreground walls and their gold
# trim. A polygon through the rivets bisects the rim and lets cards cover it.
const FRONT_EDGE=[Vector2(243,547),Vector2(314,513),Vector2(374,535),Vector2(752,535),Vector2(1008,267),Vector2(1030,253),Vector2(1125,202),Vector2(1125,1007),Vector2(243,1007)]
var count:=0
var pulse:=0.0
var opening:=0.0
class FrontWall extends Control:
	var chest
	func _draw()->void:
		if is_instance_valid(chest):chest.draw_front_wall(self)
class Lid extends Control:
	var chest
	func _draw()->void:
		if is_instance_valid(chest):chest.draw_lid(self)
func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_meta("draw_pile",true);set_meta("draw_chest",true)
	var front=FrontWall.new();front.name="ChestFront";front.chest=self
	front.mouse_filter=Control.MOUSE_FILTER_IGNORE;front.z_index=FRONT_Z
	add_child(front);front.size=size
	var lid=Lid.new();lid.name="ChestLid";lid.chest=self
	lid.mouse_filter=Control.MOUSE_FILTER_IGNORE;lid.z_index=LID_Z
	add_child(lid);lid.size=size
	queue_redraw()
func set_count(value:int)->void:
	count=value;queue_redraw()
func present(value:float)->void:
	opening=clampf(value,0,1);queue_redraw()
	if has_node("ChestLid"):get_node("ChestLid").queue_redraw()
func art_point(pixel:Vector2)->Vector2:
	return BASE_RECT.position+(pixel-ART_ORIGIN)*ART_SCALE
func lid_corners(amount:float)->PackedVector2Array:
	var angle=deg_to_rad(95)*amount
	var near=art_point(HINGE_NEAR);var far=art_point(HINGE_FAR)
	var lift=Vector2(0,-64)*sin(angle)
	var depth_ratio=(RIM_FAR.x-HINGE_FAR.x)/(RIM_NEAR.x-HINGE_NEAR.x)
	return PackedVector2Array([near,far,far+(art_point(RIM_FAR)-far)*cos(angle)+lift*depth_ratio,near+(art_point(RIM_NEAR)-near)*cos(angle)+lift])
func surface(quad:PackedVector2Array,u:float,v:float)->Vector2:
	return quad[0].lerp(quad[1],u).lerp(quad[3].lerp(quad[2],u),v)
func top_card_corners()->PackedVector2Array:
	var rim=lid_corners(0);var corners=PackedVector2Array()
	# Portrait backs run along the long interior, with narrow margins all around.
	for q in [Vector2(.91,.15),Vector2(.91,.87),Vector2(.10,.87),Vector2(.10,.15)]:
		corners.append(surface(rim,q.x,q.y)+Vector2(0,3.2))
	return corners
func textured_quad(canvas:CanvasItem,tex:AtlasTexture,quad:PackedVector2Array,tint:Color=Color.WHITE)->void:
	# Subdivision keeps the painted planks smooth across the perspective trapezoid.
	for y in range(3):
		for x in range(4):
			var points=PackedVector2Array();var uv=PackedVector2Array()
			for step in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
				var q=(Vector2(x,y)+step)/Vector2(4,3)
				points.append(surface(quad,q.x,q.y));uv.append((tex.region.position+q*tex.region.size)/tex.atlas.get_size())
			# Explicit triangles remain valid through the edge-on lid pose.
			for tri in [[0,1,2],[0,2,3]]:
				if absf((points[tri[1]]-points[tri[0]]).cross(points[tri[2]]-points[tri[0]]))>.03:
					canvas.draw_polygon(PackedVector2Array([points[tri[0]],points[tri[1]],points[tri[2]]]),PackedColorArray([tint]),PackedVector2Array([uv[tri[0]],uv[tri[1]],uv[tri[2]]]),tex.atlas)
func draw_front_wall(canvas:CanvasItem)->void:
	# Both foreground walls occlude the lower part of an emerging card.
	# Sample the same painting at exactly the same coordinates as the body below.
	var tex:AtlasTexture=Art.texture("draw_chest_right_base")
	var points=PackedVector2Array();var uv=PackedVector2Array()
	for p in FRONT_EDGE:
		points.append(art_point(p));uv.append(p/tex.atlas.get_size())
	canvas.draw_polygon(points,PackedColorArray([Color.WHITE]),uv,tex.atlas)
func _draw()->void:
	var footprint=PackedVector2Array()
	for p in [Vector2(314,994),Vector2(585,687),Vector2(1101,690),Vector2(782,994)]:footprint.append(art_point(p))
	var center=Vector2.ZERO
	for p in footprint:center+=p/4.0
	# Warm contact shadow follows the footprint and the table's top-left light.
	for i in range(6,0,-1):
		var shadow=PackedVector2Array()
		for p in footprint:shadow.append(center+(p-center)*(1+i*.012)+Vector2(2+i*.45,1+i*.35))
		draw_colored_polygon(shadow,Color(.12,.055,.022,.032))
	draw_texture_rect(Art.texture("draw_chest_right_base"),BASE_RECT,false)
	if count>0:
		var card=Back.texture("back")
		for i in range(mini(count,4)):
			var corners=top_card_corners()
			for j in range(4):corners[j]+=Vector2(.18*(3-i),1.05*(3-i))
			textured_quad(self,card,corners,Color("ded0b4").lerp(Color.WHITE,i/3.0))
func draw_lid(canvas:CanvasItem)->void:
	var rim=lid_corners(0)
	var lid=lid_corners(opening)
	var edge=Vector2(0,2.2)
	for pair in [[0,3],[3,2]]:
		var a=lid[pair[0]];var b=lid[pair[1]]
		canvas.draw_colored_polygon(PackedVector2Array([a,b,b+edge,a+edge]),Color("82501f"))
	textured_quad(canvas,Art.texture("draw_chest_lid"),lid,Color.WHITE.lerp(Color("dbc08e"),opening*.20))
	for t in [.18,.82]:
		var at=rim[0].lerp(rim[1],t);var axis=(rim[1]-rim[0]).normalized()*3
		canvas.draw_line(at-axis,at+axis,Color("b7772b"),2.7,true)
