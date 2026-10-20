extends RefCounted
static var regions={}
static var textures={}
static var atlases={}
const ALIAS={"collect":"collection_key","cards_to_heart":"heart","cards_to_blades":"triple_strike","obstruct":"boulder","poisoning":"poison","raise_dead":"lantern","resurrection":"lantern","death_sentence":"reaper","immortal":"phoenix_mid","sacrifice_badges":"badge","life_steal":"pain","vanish":"reaper"}
static func init():
	if regions.is_empty():regions=JSON.parse_string(FileAccess.get_file_as_string("res://assets/cinema/index.json"))
static func supports(key):
	init();return regions.has(ALIAS.get(key,key))
static func texture(key):
	init();key=ALIAS.get(key,key)
	if textures.has(key):return textures[key]
	if not regions.has(key):return null
	var row=regions[key]
	if not atlases.has(row.atlas):atlases[row.atlas]=load("res://assets/cinema/"+row.atlas)
	var tex=AtlasTexture.new();tex.atlas=atlases[row.atlas];tex.region=Rect2(row.rect[0],row.rect[1],row.rect[2],row.rect[3]);tex.filter_clip=true;textures[key]=tex
	return tex
static func card_texture(key):return texture(key)
static func draw_prop(canvas,key,at,side,angle=0.0,alpha=1.0,squash=Vector2.ONE,modulate=Color.WHITE):
	var tex=texture(key)
	if tex==null or alpha<.002 or side<.1:return
	var dimensions=tex.get_size();var ratio=side/maxf(dimensions.x,dimensions.y);var size=dimensions*ratio
	canvas.draw_set_transform(at,angle,squash)
	canvas.draw_texture_rect(tex,Rect2(-size*.5,size),false,Color(modulate,alpha))
	canvas.draw_set_transform(Vector2.ZERO)
static func draw_card(canvas,key,rect,alpha=1.0):
	var center=rect.get_center();var size=minf(rect.size.x,rect.size.y)
	var count={"double_strike":2,"triple_strike":3,"area_strike":3,"precise_strike":2,"cards_to_blades":3,"sacrifice_badges":2}.get(key,1)
	if key=="obstruct":
		for i in range(2):
			var part=preload("res://scripts/curse_placement.gd").stone_part(i,size)
			draw_prop(canvas,"boulder",center+part.offset,part.side,part.angle,alpha)
		return
	if count>1:
		for i in range(count):
			var p=float(i)-(count-1)*.5;var tilt=p*.33
			draw_prop(canvas,key,center+Vector2(p*size*.25,absf(p)*size*.06),size*(.86 if count==3 else .91),tilt,alpha)
	elif key=="death_sentence":
		draw_prop(canvas,"reaper",center+Vector2(-size*.10,0),size,0,alpha)
		draw_prop(canvas,"scythe",center+Vector2(size*.18,0),size*.92,-.2,alpha)
	else:
		var angle=preload("res://scripts/strike_timing.gd").CARD_ANGLE if key in preload("res://scripts/strike_timing.gd").SINGLE_CARD else 0.0
		draw_prop(canvas,key,center,size,angle,alpha)
static func draw_warp(canvas,key,at,side,phase,alpha=1.0,wing=false):
	var tex=texture(key)
	if tex==null or alpha<.003:return
	var dimensions=tex.get_size();var size=dimensions*(side/maxf(dimensions.x,dimensions.y));var atlas_size=tex.atlas.get_size()
	for row in range(12):
		for col in range(12):
			var pts=PackedVector2Array();var uv=PackedVector2Array()
			for offset in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var q=(Vector2(col,row)+offset)/12.0;var local=(q-Vector2(.5,.5))*size
				if wing:
					local.y+=sin(phase)*pow(absf(q.x-.5)*2,1.6)*side*.17
					local.x*=1-.06*cos(phase)*absf(q.x-.5)*2
				else:
					local.x+=sin(phase+q.y*4)*pow(q.y,1.6)*side*.06
					local.y+=cos(phase+q.x*3)*q.y*side*.015
				pts.append(at+local);uv.append((tex.region.position+q*tex.region.size)/atlas_size)
			canvas.draw_polygon(pts,PackedColorArray([Color(1,1,1,alpha)]),uv,tex.atlas)
