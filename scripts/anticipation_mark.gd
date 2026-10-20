extends Control
## Two real brush impressions; only the mark art changes from the first preview.
const BRUSH=preload("res://assets/cinema/anticipation/blue_brush_strokes.png")
const REGIONS=[Rect2(109,138,1598,242),Rect2(105,547,1599,242)]
const BRUSH_SHADER=preload("res://scripts/anticipation_brush.gdshader")
var clock_started=-1
var elapsed=0.
var active=false
var brushes=[]
static func applies(view:Dictionary,action:Dictionary)->bool:
	return not action.get("death",false) and not action.get("revealed",false) and action.get("status","") not in ["removed","returned","cancelled"] and view.get("reveal_locked_teams",[false,false])[int(action.actor)/3]
func configure(started:int)->void:
	clock_started=started;active=started>=0;mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=9
	set_meta("anticipation_mark",true)
	for region in REGIONS:
		var tex=AtlasTexture.new();tex.atlas=BRUSH;tex.region=region;tex.filter_clip=true
		var sprite=TextureRect.new();sprite.texture=tex;sprite.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;sprite.stretch_mode=TextureRect.STRETCH_SCALE
		sprite.mouse_filter=Control.MOUSE_FILTER_IGNORE;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var material=ShaderMaterial.new();material.shader=BRUSH_SHADER
		material.set_shader_parameter("atlas_region",Vector4(region.position.x/BRUSH.get_width(),region.position.y/BRUSH.get_height(),region.size.x/BRUSH.get_width(),region.size.y/BRUSH.get_height()))
		sprite.material=material;add_child(sprite);brushes.append(sprite)
	set_process(active);present(0.)
func present(seconds:float)->void:
	elapsed=seconds if active else 100.
	var card=get_parent();var mid=card.size*Vector2(.5,.505)
	var extent=Vector2(card.size.x*.285,card.size.y*.255)
	place_brush(0,mid-extent,mid+extent,smoothstep(.045,.275,elapsed))
	place_brush(1,mid+Vector2(extent.x,-extent.y),mid+Vector2(-extent.x,extent.y),smoothstep(.30,.545,elapsed))
	queue_redraw()
func place_brush(index:int,a:Vector2,b:Vector2,part:float)->void:
	var sprite=brushes[index];var direction=b-a
	var breadth=direction.length()*.170
	sprite.size=Vector2(direction.length(),breadth);sprite.pivot_offset=Vector2(0,breadth*.5)
	sprite.position=a-sprite.pivot_offset;sprite.rotation=direction.angle();sprite.visible=part>.001
	sprite.material.set_shader_parameter("reveal",part)
func _process(_delta:float)->void:
	present(maxf(0,(Time.get_ticks_msec()-clock_started)/1000.) if clock_started>=0 else elapsed)
func line_points(a:Vector2,b:Vector2,part:float,offset:float=0.)->PackedVector2Array:
	var pts=PackedVector2Array();var normal=(b-a).normalized().orthogonal()
	for i in range(41):
		var t=float(i)/40*part
		pts.append(a.lerp(b,t)+normal*(offset+sin(t*PI)*.65+sin(t*23.)*.14))
	return pts
func stroke_glimmer(a:Vector2,b:Vector2,part:float,age:float,seed:float)->void:
	if part<=.001:return
	var pts=line_points(a,b,part)
	var flash=(1.-smoothstep(.18,.62,age))*.24
	if flash>0.:
		draw_polyline(pts,Color("58bcf6",flash*.30),14.,true)
		draw_polyline(pts,Color("63cbfa",flash*.6),10.,true)
	if age>=0 and age<.42:
		var tip=pts[-1]
		for i in range(7):
			var v=fposmod(float(i)*.217+age*1.2,1.)
			var p=tip+Vector2.from_angle(i*2.4+seed)*(3.+v*15.)+Vector2(0,-v*5.)
			draw_circle(p,.45+(1-v)*.45,Color("78caf2",(1-v)*.55*(1-smoothstep(.24,.42,age))),true,-1,true)
func _draw()->void:
	var card=get_parent();var mid=card.size*Vector2(.5,.505)
	var extent=Vector2(card.size.x*.285,card.size.y*.255)
	stroke_glimmer(mid-extent,mid+extent,smoothstep(.045,.275,elapsed),elapsed-.045,.3)
	stroke_glimmer(mid+Vector2(extent.x,-extent.y),mid+Vector2(-extent.x,extent.y),smoothstep(.30,.545,elapsed),elapsed-.30,2.1)
