extends Control
const Pose=preload("res://scripts/divinity_pose.gd")
const Layout=preload("res://scripts/board_layout.gd")
var event:Dictionary={}
var started:=-1
var elapsed:=0.0
var owner_pose:Control
var center:=Vector2.ZERO
func initialize(board,begin:int)->void:
	event=board.view.animation;started=begin
	size=Vector2(1440,960);mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=20
	var owner:int=event.action.actor
	center=Layout.pawn_center(owner,owner/3==board.mine)
	for node in board.canvas.get_children():
		if node.get_meta("knight_id",-1)==owner:
			for child in node.get_children():
				if child.get_meta("divinity_actor",-1)==owner:owner_pose=child
	_process(0)
func _process(delta:float)->void:
	if started>=0:elapsed=(Time.get_ticks_msec()-started)/1000.0
	else:elapsed+=delta
	if is_instance_valid(owner_pose):center=get_global_transform().affine_inverse()*(owner_pose.get_global_transform()*owner_pose.chest_position())
	queue_redraw()
func _draw()->void:
	Pose.draw_radiance(self,center,elapsed)
