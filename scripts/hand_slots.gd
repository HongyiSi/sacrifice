extends Control
const Layout=preload("res://scripts/board_layout.gd")
var friendly=true
func _ready():mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw():
	var factor=Layout.hand_scale(friendly)
	for index in range(Layout.SLOTS):
		var r=Rect2(Layout.hand_slot(index,friendly),Layout.CARD_SIZE*factor).grow(1)
		var box=StyleBoxFlat.new();box.bg_color=Color(.40,.26,.12,.035);box.border_color=Color(.45,.29,.12,.15);box.set_border_width_all(1);box.set_corner_radius_all(4);draw_style_box(box,r)
		for corner in range(4):
			var sx=1 if corner in [0,3] else -1;var sy=1 if corner in [0,1] else -1
			var pos=Vector2(r.position.x if sx>0 else r.end.x,r.position.y if sy>0 else r.end.y)
			var pts=PackedVector2Array([pos+Vector2(0,sy*8*factor),pos,pos+Vector2(sx*8*factor,0)])
			draw_polyline(pts,Color(.53,.34,.16,.39),1.3*factor,true)
