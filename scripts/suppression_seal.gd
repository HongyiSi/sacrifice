extends Control
## A child of the real targeted card, retained across unrelated UI rebuilds.
const Pose=preload("res://scripts/suppression_pose.gd")
var key=""
var event={}
var active=false
var clock_started=-1
var elapsed=0.
var age=100.
func configure(style,e,started):
	key=style;event=e;active=not e.is_empty();clock_started=started
	mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=6
	set_meta("persistent_suppression",key)
	set_process(active);present(0.)
func present(seconds):
	elapsed=seconds
	age=(Pose.contact(key) if event.get("stage","")=="impact" else 0.)+seconds if active else 100.
	visible=not active or age>=Pose.contact(key)
	queue_redraw()
func _process(_delta):
	present(maxf(0,(Time.get_ticks_msec()-clock_started)/1000.) if clock_started>=0 else elapsed)
func _draw():
	if not visible:return
	var card=get_parent()
	Pose.settled(self,key,card.size*.5+Vector2(0,-3.),card.size.x*Pose.SIDE,age)
