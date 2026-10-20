extends RefCounted
const Frame=preload("res://scripts/art_ui/frame_design.gd")
const UI=preload("res://scripts/art_ui/ui_chrome.gd")
static func draw(c):
	var s=c.size.x/76.0
	var body=Rect2(s,0,c.size.x-2*s,c.size.y-4*s)
	if c.card.get("key","")=="final_strike":
		var r=Rect2(15*s,78*s,46*s,10*s)
		UI.nine(c,UI.texture("panel"),r,3*s)
		Frame.text(c,Frame.CN,"伤害 %d"%int(c.card.get("damage",0)),r,7.5*s,Color("953e44"))
	if c.selected and c.selection_order>0:
		var r=Rect2(c.size.x/2-6*s,body.end.y,12*s,12*s)
		c.draw_circle(r.get_center(),6*s,Color("385d75"))
		Frame.text(c,Frame.NUM,str(c.selection_order),r,10*s,Color("fff0ca"))
	var blocked=c.card.get("defiled",false) or not c.card.get("playable",true)
	var finished=c.action_status in ["cancelled","blocked","suppressed","skipped","removed","declined","returned","triggered"]
	if blocked or finished:
		var r=Rect2(11*s,69*s,54*s,13*s)
		UI.nine(c,UI.texture("header"),r,4*s)
		var caption="玷污" if c.card.get("defiled",false) else "不可打出"
		if finished:caption={"cancelled":"已取消","blocked":"被抵挡","suppressed":"被压制","skipped":"已跳过","removed":"已移除","declined":"已放弃","returned":"已返回","triggered":"已触发"}.get(c.action_status,caption)
		Frame.text(c,Frame.CN,caption,r,8*s,Color("f1dbc3"))
	if c.targetable or c.expanded or c.is_hovered() or c.has_focus():
		var box=StyleBoxFlat.new();box.bg_color=Color.TRANSPARENT;box.border_color=Color("f5d397") if c.targetable else Color("d4b473")
		box.set_border_width_all(maxi(1,roundi(s)));box.set_corner_radius_all(roundi(4*s));c.draw_style_box(box,body.grow(s*.7))
