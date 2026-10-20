extends Control
const UI=preload("res://scripts/art_ui/ui_chrome.gd")
const DURATION_MS=1500
var title="出牌阶段"
var tint=Color("a9d4ed")
var started=0
var age=0.0
func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=90;_process(0)
func _process(_delta):
	age=maxf(0,(Time.get_ticks_msec()-started)/1000.0);visible=age<1.5;queue_redraw()
	if not visible:set_process(false)
func _draw():
	var alpha=smoothstep(0,.18,age)*(1-smoothstep(1.04,1.5,age))
	if alpha<.001:return
	var rect=Rect2(414,337+lerpf(15,0,smoothstep(0,.28,age)),612,108)
	UI.nine(self,UI.texture("header"),rect,24,Color(1,1,1,alpha))
	var font=UI.CN;var fs=34;var length=font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
	var baseline=rect.get_center().y+(font.get_ascent(fs)-font.get_descent(fs))/2
	draw_string(font,Vector2(rect.get_center().x-length/2,baseline),title,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color(UI.CREAM,alpha))
