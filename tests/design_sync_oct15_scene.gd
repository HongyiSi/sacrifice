extends Node

func _ready()->void:
	# Export templates launch a scene; install the same SceneTree test runner
	# used by the native editor so the browser exercises production UI paths.
	var tree=get_tree()
	tree.set_script(load("res://tests/design_sync_oct15_ui_test.gd"))
	tree.call("_initialize")
