extends Control
const Pose=preload("res://scripts/ordinary_pose.gd")
const Card=preload("res://scripts/card_widget.gd")
var elapsed=0.
var clock_started=-1
var event={}
var board
var cards=[]
var rows=[]
func initialize(b):
	board=b;event=b.view.animation;rows=b.view.get("staged_discards",[])
	size=Vector2(1440,960);mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=85
	var finish=event.get("op","")=="discard_finish"
	if finish:clock_started=b.ui.effect_started
	for i in range(rows.size()):
		var row=rows[i]
		var c=b._card(self,b.view.catalog.get(row.card,b.view.death_catalog.get(row.card,{})),false)
		c.size=Vector2(76,108);c.pivot_offset=c.size*.5;c.scale=Vector2.ONE*.72
		c.mouse_filter=Control.MOUSE_FILTER_IGNORE;c.set_process(false)
		c.position=Pose.staged_at(i)-c.size*.5
		c.motif_alpha=0. if row.key in ["spare_food","spare_supplies"] and row.spent else 1.
		cards.append(c)
	present(0.)
func present(age):
	elapsed=age
	for i in range(cards.size()):
		var c=cards[i];var row=rows[i]
		if event.get("op","")=="discard_finish":
			var v=smoothstep(.03+i*.045,.88+i*.035,age) if event.stage=="travel" else 1.
			c.position=Pose.staged_at(i).lerp(Vector2(1280,533),v)+Vector2(0,-sin(v*PI)*46)-c.size*.5
			c.scale=Vector2.ONE*lerpf(.72,.26,v);c.rotation=.3*sin(v*PI);c.modulate.a=1-smoothstep(.83,1,v)
			if row.key in ["spare_food","spare_supplies"] and row.spent:c.motif_alpha=0.
		c.queue_redraw()
func _process(_delta):
	if clock_started>=0:present(maxf(0,(Time.get_ticks_msec()-clock_started)/1000.))
