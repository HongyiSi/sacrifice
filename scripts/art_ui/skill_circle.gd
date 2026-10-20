extends RefCounted
## Approved circular illustration border; outer priority frames remain intact.
const SOURCE=preload("res://assets/art_ui/cards/skill_circle_source.png")
const SHADER=preload("res://scripts/art_ui/skill_circle.gdshader")
static var materials: Dictionary = {}
static var skill_keys: Dictionary = {}
static var flight_frame: Texture2D

static func applies(info:Dictionary,death:bool=false,hidden:bool=false)->bool:
	return not death and not hidden and info.get("type","")=="技能"

static func material_for(tex:Texture2D)->ShaderMaterial:
	var id=tex.get_instance_id()
	if not materials.has(id):
		var material=ShaderMaterial.new();material.shader=SHADER
		material.set_shader_parameter("circle_source",SOURCE)
		material.set_shader_parameter("source_size",SOURCE.get_size())
		if tex is AtlasTexture:
			var dimensions=tex.atlas.get_size();var area=tex.region
			material.set_shader_parameter("frame_uv_rect",Vector4(area.position.x/dimensions.x,area.position.y/dimensions.y,area.size.x/dimensions.x,area.size.y/dimensions.y))
		materials[id]=material
	return materials[id]

static func miniature(face:String,death:bool,fallback:Texture2D)->Texture2D:
	if face.is_empty() or death:return fallback
	if skill_keys.is_empty():
		for info in JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json")):
			if applies(info):skill_keys[info.key]=true
	if not skill_keys.has(face):return fallback
	if flight_frame==null:flight_frame=load("res://assets/art_ui/cards/skill_circle_flight.png")
	return flight_frame
