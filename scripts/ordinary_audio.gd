extends RefCounted
static func cues(e,b):
	var out=[]
	var key=e.get("style","");var op=e.get("op","");var stage=e.get("stage","");var kind=e.get("kind","")
	var bank=b.get("ordinary_suite",{})
	if bank.is_empty():return out
	var keyframes=[]
	if op=="discard_finish":
		if stage=="travel":keyframes=[["discard",0.]]
	elif kind=="card_effect":
		if key=="defile":
			if op=="defile" and stage=="travel":keyframes=[["ink_fly",0.]]
			elif op=="defile_seal" and stage=="travel":keyframes=[["ink_stroke",.295],["ink_stroke",.55]]
		elif key=="plunder" and stage=="travel":keyframes=[["hook_out",0.]]
		elif key=="rally":keyframes=[["flag",0.]] if stage=="travel" else [["rally_arrive",0.]]
		elif key=="raise_dead":keyframes=[["soul_return",0.]] if stage=="travel" else [["revive",0.]]
		elif key=="overload":keyframes=[["overload",0.]] if stage=="travel" else [["charged",0.]]
		elif key=="feign":keyframes=[["mask_fly",0.]] if stage=="travel" else [["mask_hurt",0.]]
		elif key=="skip_death" and stage=="travel":keyframes=[["hourglass",0.]]
		elif key=="frenzy" and stage=="travel":keyframes=[["frenzy",0.]]
		elif key=="elegy" and stage=="travel":
			if op=="elegy_cost":keyframes=[["box_lift",0.]]
			elif op=="elegy_pack":keyframes=[["box_card",0.],["box_card",.36]]
			elif op=="draw_death":keyframes=[["box_work",0.],["death_card",.86]]
		elif key=="spare_supplies" and stage=="travel":
			keyframes=[["supplies",0.]]
			out.append({"file":b.cards.collect.open,"delay":1.08,"cut_with_stage":false,"gain":1.5})
		# Every source of badge gain shares this exact material and chime.
		if op=="badges" or key=="badge":
			if stage=="impact":
				for i in range(int(e.get("card_count",1))):keyframes.append(["badge",i*.12])
	elif kind=="heal" and key=="spare_food":
		if stage=="travel":keyframes=[["bread",0.]]
		elif e.get("targets",[]).any(func(h):return h.get("after",0)>h.get("before",0)):
			out.append({"file":b.cards.heal.impact,"delay":0.,"cut_with_stage":false,"gain":1.})
	elif kind=="draw_cards" and stage=="travel":
		if e.draws.any(func(d):return d.get("hook_return",false)):keyframes=[["hook_catch",.12],["hook_return",.32]]
		for d in e.draws:
			if d.get("source_key","")=="spare_supplies":
				for i in range(d.count):
					if d.starts[i]>=0 and not d.returned[i]:out.append({"file":b.gem_movement.deal,"delay":d.starts[i]/1000.+.10,"cut_with_stage":false,"gain":1.24})
	for cue in keyframes:out.append({"file":bank[cue[0]],"delay":cue[1],"cut_with_stage":false,"gain":2.})
	return out
