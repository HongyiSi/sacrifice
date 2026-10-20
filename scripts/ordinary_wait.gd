extends Control
const Pose=preload("res://scripts/ordinary_pose.gd")
const Art=preload("res://scripts/cinema/atlas.gd")
var key=""
var actor=0
var mine=0
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=6
func _draw():Art.draw_prop(self,key,Pose.dock(actor,mine,key),142. if key=="elegy" else 102.)
