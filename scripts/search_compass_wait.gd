extends Control
const Pose=preload("res://scripts/search_compass_pose.gd")
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	z_index=6;set_meta("search_compass_wait",true)
func _draw():Pose.settled(self)
