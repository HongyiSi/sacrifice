extends Control
## Alpha-derived contours are cached; no changes to the painted pawn assets.
const PERIOD := 1.5
const MIN_WIDTH := 1.8
const MAX_WIDTH := 2.94
const HOVER_WIDTH := 4.34
static var contours: Dictionary = {}
var target: Button
var portrait: TextureRect
var paths: Array[PackedVector2Array] = []
var stroke_width := MIN_WIDTH
var hovered := false

static func width_at(seconds: float, is_hovered: bool) -> float:
	if is_hovered: return HOVER_WIDTH
	return lerpf(MIN_WIDTH,MAX_WIDTH,0.5-0.5*cos(TAU*seconds/PERIOD))

func initialize(button: Button, sprite: TextureRect) -> void:
	target = button
	portrait = sprite
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	# As a sibling of the portrait, a dead pawn's gray modulation does not dim
	# its legal target outline. The portrait covers the inner half of the stroke.
	var key := sprite.texture.get_instance_id()
	if not contours.has(key):
		var bitmap := BitMap.new()
		# AtlasTexture.get_image() crops before returning the image. Compressed
		# atlases cannot be cropped until their source pixels are decompressed.
		var atlas := sprite.texture as AtlasTexture
		var img := atlas.atlas.get_image() if atlas != null else sprite.texture.get_image()
		if img.is_compressed(): img.decompress()
		if atlas != null: img = img.get_region(atlas.region)
		bitmap.create_from_image_alpha(img,0.25)
		contours[key] = bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO,img.get_size()),1.0)
	var ratio := minf(sprite.size.x/sprite.texture.get_width(),sprite.size.y/sprite.texture.get_height())
	var offset := sprite.position+(sprite.size-sprite.texture.get_size()*ratio)/2
	for contour in contours[key]:
		var points := PackedVector2Array()
		for point in contour: points.append(offset+point*ratio)
		if points.size() < 3: continue
		points.append(points[0])
		paths.append(points)
	_process(0)

func _process(_delta: float) -> void:
	if not is_instance_valid(target): return
	hovered = target.is_hovered()
	stroke_width = width_at(Time.get_ticks_msec()/1000.0,hovered)
	queue_redraw()

func _draw() -> void:
	for points in paths:
		draw_polyline(points,Color("97701f"),(stroke_width+0.7)*2,true)
		draw_polyline(points,Color("ffd15c"),stroke_width*2,true)
