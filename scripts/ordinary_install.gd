extends RefCounted
const Card=preload("res://scripts/card_widget.gd")
static func walk(n):
	var out=[n]
	for c in n.get_children():out.append_array(walk(c))
	return out
static func install(b):
	var view=b.view
	if not view.get("prepared_backpack",{}).is_empty() and not preload("res://scripts/prepared_timing.gd").supports(view.animation):
		var backpack=preload("res://scripts/prepared_effect.gd").new()
		b.canvas.add_child(backpack);backpack.initialize(b,true)
	if view.phase=="selecting" and view.input.get("type","") in ["defile","plunder","elegy"]:
		var wait=preload("res://scripts/ordinary_wait.gd").new()
		wait.key=view.input.type;wait.actor=view.input.target;wait.mine=b.mine;b.canvas.add_child(wait)
		var source=b._active_widget()
		if source!=null:source.motif_alpha=0.;source.queue_redraw()
	var seal=view.animation.get("style","")=="defile" and view.animation.get("op","")=="defile_seal"
	for n in walk(b.canvas):
		var actor=n.get_meta("hand_actor",n.get_meta("enemy_hand_actor",-1))
		if actor<0:continue
		for c in n.get_children():
			if not c is Card or not preload("res://scripts/defile_mark.gd").is_marked(c,view.characters[actor].get("defiled_slots",[])):continue
			if seal:continue
			var mark=preload("res://scripts/defile_mark.gd").new();c.add_child(mark);mark.configure(-1)
	if view.get("staged_discards",[]).any(func(d):return d.key in ["spare_food","spare_supplies"]):
		var staging=preload("res://scripts/discard_staging.gd").new();b.canvas.add_child(staging);staging.initialize(b)
