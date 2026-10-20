extends RefCounted
static var regions={}
static var textures={}
static func texture(key):
	if regions.is_empty():regions=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art_ui/backs/regions.json"))
	if not textures.has(key):
		var t=AtlasTexture.new();t.atlas=load("res://assets/art_ui/backs/"+key+".png");var r=regions[key];t.region=Rect2(r[0],r[1],r[2],r[3]);t.filter_clip=true;textures[key]=t
	return textures[key]
static func draw(c,death=false):
	c.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for child_name in ["PriorityAura","PriorityFrame","PriorityRim"]:
		var child=c.get_node_or_null(child_name)
		if child:child.hide()
	var s=c.size.x/76.0;var body=Rect2(s,0,c.size.x-2*s,c.size.y-4*s)
	c.draw_texture_rect(texture("death" if death else "back"),body,false)
