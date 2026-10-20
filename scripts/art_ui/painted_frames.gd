extends RefCounted
const FAMILIES=["gold","blue","green","red","black"]
static var regions={}
static var textures={}
static func texture(group:int,death:bool)->AtlasTexture:
	if regions.is_empty():regions=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art_ui/repainted/regions.json"))
	var family=FAMILIES[group];var face="death" if death else "normal";var key=family+face
	if not textures.has(key):
		var tex=AtlasTexture.new();tex.atlas=load("res://assets/art_ui/repainted/"+family+".png")
		var r=regions[family][face];tex.region=Rect2(r[0],r[1],r[2],r[3]);tex.filter_clip=true;textures[key]=tex
	return textures[key]
