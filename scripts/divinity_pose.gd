extends Control
## Original figure follows its painted silhouette; the reconstructed pedestal
## and the original bronze rim remain entirely stationary.
const Landmarks=preload("res://scripts/pawn_landmarks.gd")
static var clean_base:Texture2D
static var clean_region:Rect2=Rect2()
var art_key=""
var base_bounds=Rect2()
var texture:Texture2D
var texture_rect:=Rect2()
var body_edge:=PackedVector2Array()
var red:=false
var clock:=0.0
var strength:=0.0
var pulse_age:=-1.0
var lift:=0.0
var hover_height:=13.0
var original:Control
var original_visible:=true
var started:=-1
var base_pixel:=Vector2(680,1050)
var halo_pixel:=Vector2(630,200)
var base_width:=300.0
var chest_pixel:=Vector2.ZERO
const INK=Color("8f8068")
const IVORY=Color("fff5da")
const GOLD=Color("f6d888")
const LIFT_START:=0.6
const LIFT_END:=2.0

func configure(sprite:Control,is_red:bool,art:String="",begin:int=-1)->void:
	red=is_red;original=sprite;original_visible=sprite.visible;sprite.hide()
	art_key=art;base_bounds=Landmarks.BASE[art]
	if clean_base==null:
		clean_base=load("res://assets/art/divinity/empty_stone_base.png")
		var image=clean_base.get_image()
		if image.is_compressed():image.decompress()
		# The generated transparent canvas has a few alpha=1 pixels outside
		# the real artwork. Sample the measured pedestal, never that noise.
		clean_region=Rect2(288,901,679,248)
	started=begin
	base_pixel=Vector2(630 if red else 680,1050);halo_pixel=Vector2(630,255 if red else 200);base_width=267 if red else 300
	var atlas:AtlasTexture=sprite.texture
	texture=atlas.atlas
	var factor:=minf(sprite.size.x/atlas.region.size.x,sprite.size.y/atlas.region.size.y)
	texture_rect=Rect2(sprite.position+(sprite.size-atlas.region.size*factor)/2-atlas.region.position*factor,texture.get_size()*factor)
	# The six approved miniatures share a low pedestal. Derive landmarks from
	# the cropped illustration so wings stay attached after texture replacement.
	var bounds=atlas.region
	body_edge=Landmarks.sole(art)
	var lowest=base_bounds.position.y
	for p in body_edge:
		if p.x>base_bounds.position.x and p.x<base_bounds.end.x:lowest=maxf(lowest,p.y)
	hover_height=maxf(13.,(lowest-base_bounds.position.y)*factor+4.)
	base_pixel=base_bounds.get_center()
	halo_pixel=Landmarks.HEAD[art]+Vector2(0,-40)
	chest_pixel=Vector2(bounds.get_center().x,bounds.position.y+bounds.size.y*.56)
	base_width=bounds.size.x*.31

	mouse_filter=Control.MOUSE_FILTER_IGNORE
	if started>=0:_process(0)

func _process(_delta:float)->void:
	if started<0:return
	var age:float=(Time.get_ticks_msec()-started)/1000.0
	pose(Time.get_ticks_msec()/1000.0,smoothstep(LIFT_START,LIFT_END,age))

func chest_position()->Vector2:
	return texture_rect.position+chest_pixel*texture_rect.size.x/texture.get_width()+Vector2(0,-lift)

func pose(time:float,amount:float,pulse:float=-1)->void:
	clock=time;strength=clampf(amount,0,1);pulse_age=pulse
	lift=(hover_height+1.5*sin(time*1.65))*strength
	queue_redraw()

func textured_polygon(points:PackedVector2Array,offset:Vector2,tint:Color)->void:
	var shape:=PackedVector2Array();var uv:=PackedVector2Array()
	for p in points:
		uv.append(p/texture.get_size())
		shape.append(texture_rect.position+p/texture.get_size()*texture_rect.size+offset)
	draw_polygon(shape,PackedColorArray([tint]),uv,texture)

func ellipse(at:Vector2,radius:Vector2,fill:Color)->void:
	var shape:=PackedVector2Array()
	for i in range(64):shape.append(at+Vector2.from_angle(i*TAU/64)*radius)
	draw_colored_polygon(shape,fill)

func curve(points:PackedVector2Array,a:Vector2,b:Vector2,c:Vector2,d:Vector2)->void:
	for i in range(1,13):points.append(a.bezier_interpolate(b,c,d,i/12.0))

func feather(root_at:Vector2,tip:Vector2,width:float,tint:Color)->void:
	var axis:=tip-root_at;var normal:=axis.normalized().orthogonal()
	var left:=root_at-normal*width*.28
	var right:=root_at+normal*width*.3
	var shape:=PackedVector2Array([left])
	var cap:=tip-axis.normalized()*2
	curve(shape,left,root_at+axis*.45-normal*width,cap-normal*width*.48,tip-normal*2)
	curve(shape,tip-normal*2,tip+axis.normalized()*2-normal*2,tip+axis.normalized()*2+normal*2,tip+normal*2)
	curve(shape,tip+normal*2,cap+normal*width*.6,root_at+axis*.32+normal*width*.8,right)
	shape.append(left)
	draw_colored_polygon(shape,tint)
	draw_polyline(shape,Color(INK,strength*.90),.95,true)
	draw_line(root_at+axis*.28,tip-axis*.15,Color("cabb97",strength*.55),.7,true)

func wing(center:Vector2,side:float,scale_factor:float)->void:
	var spread:=lerpf(.18,1.0,smoothstep(0,.95,strength))
	var flutter:=sin(clock*1.65)*.025
	draw_set_transform(center,side*(.07+flutter),Vector2(side*spread,1)*scale_factor)
	var contour:=PackedVector2Array([Vector2(0,6)])
	curve(contour,Vector2(0,6),Vector2(22,-6),Vector2(37,-32),Vector2(62,-43))
	curve(contour,Vector2(62,-43),Vector2(64,-12),Vector2(62,9),Vector2(45,23))
	curve(contour,Vector2(45,23),Vector2(25,29),Vector2(8,27),Vector2(0,6))
	draw_colored_polygon(contour,Color("eadcbd",strength))
	draw_polyline(contour,Color(INK,strength*.9),1.1,true)
	var tips:Array=[Vector2(62,-43),Vector2(68,-28),Vector2(65,-12),Vector2(57,4),Vector2(45,17),Vector2(31,24)]
	for i in range(tips.size()):
		feather(Vector2(20-i*2,-8+i*4),tips[i],12.5-i*.5,Color(IVORY.lerp(Color("dfd1b2"),i*.055),strength))
	for i in range(4):
		feather(Vector2(0,8+i*2),Vector2(30+i*3,-16+i*9),9.5,Color("fff8e5",strength))
	draw_set_transform(Vector2.ZERO)

func halo(at:Vector2)->void:
	draw_set_transform(at,-.13,Vector2(1,.3))
	var glow:=.85+.1*sin(clock*1.9)
	for i in range(6,0,-1):draw_arc(Vector2.ZERO,17.5,0,TAU,64,Color(GOLD,strength*glow*.015),3+i*2,true)
	draw_arc(Vector2.ZERO,17.5,0,TAU,64,Color("b49555",strength*.9),3.3,true)
	draw_arc(Vector2.ZERO,17.5,0,TAU,64,Color("ffe6a0",strength),2.4,true)
	draw_arc(Vector2.ZERO,17.5,PI,TAU,40,Color("fff9d8",strength),1.1,true)
	draw_set_transform(Vector2.ZERO)

func radiance(center:Vector2)->void:
	draw_radiance(self,center,pulse_age,strength)

static func draw_radiance(layer:Control,center:Vector2,age:float,power:float=1)->void:
	if age<0 or age>1.5:return
	var t:=age/1.5
	var radius:=18+132*(1-pow(1-t,1.25))
	var alpha:=sin(t*PI)*power
	layer.draw_circle(center,radius,Color("fff0c8",alpha*.025))
	for i in range(11,-1,-1):
		var width:=3+i*2.4
		layer.draw_arc(center,radius,0,TAU,100,Color("f8df9d",alpha*.013),width,true)
	layer.draw_arc(center,radius,0,TAU,100,Color("fff5cf",alpha*.36),2.2,true)
	for i in range(12):
		var angle:=i*TAU/12+.15
		var axis:=Vector2.from_angle(angle)
		layer.draw_line(center+axis*(radius-7),center+axis*(radius+5),Color("fff4cd",alpha*.22),1.3,true)

func _draw()->void:
	if texture==null:return
	var factor:=texture_rect.size.x/texture.get_width()
	var base_center:=texture_rect.position+base_pixel*factor
	# A continuous painted stone top avoids footprint-shaped inpainting seams.
	# Preserve the original front stone bevel and bronze rim below its curve.
	draw_texture_rect_region(clean_base,Rect2(texture_rect.position+base_bounds.position*factor,base_bounds.size*factor),clean_region)
	var stationary=PackedVector2Array()
	for i in range(49):
		var x=float(i)/48.;var semicircle=sqrt(maxf(0.,1.-pow(x*2.-1.,2)))
		stationary.append(base_bounds.position+Vector2(x*base_bounds.size.x,base_bounds.size.y*(.43+.32*semicircle)))
	stationary.append(base_bounds.end);stationary.append(Vector2(base_bounds.position.x,base_bounds.end.y))
	textured_polygon(stationary,Vector2.ZERO,Color.WHITE)
	ellipse(base_center-Vector2(0,3),Vector2(18,4),Color("53493e",.10-.04*strength))
	var chest:=chest_position()
	radiance(chest)
	var wing_size:=.8 if red else 1.0
	wing(chest+Vector2(-7,0),-1,wing_size);wing(chest+Vector2(7,0),1,wing_size)
	var body:=PackedVector2Array([Vector2.ZERO,Vector2(texture.get_width(),0)])
	for i in range(body_edge.size()-1,-1,-1):body.append(body_edge[i])
	textured_polygon(body,Vector2(0,-lift),Color.WHITE)
	var halo_at:=texture_rect.position+halo_pixel*factor+Vector2(0,-lift)
	halo(halo_at)

func stone_base(at:Vector2,factor:float)->void:
	var radius:=Vector2(base_width,78)*factor
	ellipse(at+Vector2(0,4),radius+Vector2(3,1),Color("5a4a36",.10))
	ellipse(at+Vector2(0,1),radius+Vector2(1,1),Color("453d33"))
	ellipse(at,radius,Color("766b5a"))
	var top:=at-Vector2(0,25)*factor
	var outer:=radius*Vector2(.96,.76)
	var palette:Array=[Color("9e917a"),Color("877b67"),Color("b0a38a"),Color("938670"),Color("796e5c")]
	for i in range(7):
		var a:=i*PI/7;var b:=(i+1)*PI/7
		var slab:=PackedVector2Array([top+Vector2.from_angle(a)*outer,top+Vector2.from_angle(b)*outer,at+Vector2.from_angle(b)*radius,at+Vector2.from_angle(a)*radius])
		draw_colored_polygon(slab,palette[i%palette.size()])
		draw_line(slab[1],slab[2],Color("574d3f"),.9,true)
	ellipse(top,outer,Color("b4a78f"))
	ellipse(top-Vector2(0,.7),outer*Vector2(.88,.82),Color("a1957f"))
	for i in range(6):
		var angle:=i*TAU/6+.13
		var a:=top+Vector2.from_angle(angle)*outer
		var b:=top+Vector2.from_angle(angle+.035)*outer*.8
		draw_line(a,b,Color("786d5b"),.7,true)
	for i in range(5):
		var chip:=top+Vector2(sin(i*4.3)*outer.x*.65,cos(i*2.7)*outer.y*.5)
		draw_line(chip,chip+Vector2(2+i*.25,-.7),Color("807764",.55),1.2,true)

func _exit_tree()->void:
	if is_instance_valid(original):original.visible=original_visible
