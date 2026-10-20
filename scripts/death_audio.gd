extends RefCounted
## Added effect sounds only. Card motions and already-approved death sounds stay intact.
const KEYS=["mediocrity","death_sentence","last_dance","ghost","legacy","greed","prison","pain","resurrection","vanish","blessing","heart","life_steal","curse","eye","privilege"]
static func cues(e,b):
	var out=[];var bank=b.get("death_suite",{})
	if bank.is_empty():return out
	var kind=e.get("kind","");var stage=e.get("stage","");var key=e.get("style","");var op=e.get("op","")
	var travel=float(e.get("travel_ms",850))/1000.;var marks=[]
	if kind in ["card_start","card_reveal"] or op=="discard_finish":return out
	if kind=="card_effect":
		match key:
			"mediocrity":
				if stage=="travel":
					marks=[["shears_open",.12*travel],["shears_cut",.64*travel]]
					if e.get("card_count",0)>0:marks.append(["severed_cards",.76*travel])
			"ghost":
				if stage=="travel":marks=[["ghost_rise",.10*travel],["ghost_blade",.65*travel]]
			"legacy":
				if stage=="travel":
					marks=[["legacy_open",.24*travel]]
					if e.get("draw_mode","ready") not in ["blocked","empty"]:marks.append(["legacy_pages",.34*travel])
			"greed":
				if stage=="travel":marks=[["greed_pouch",.06*travel]]
			"prison":
				if stage=="travel":marks=[["cage_fall",.18*travel],["cage_lock",.58*travel]]
			"pain":
				if stage=="travel":marks=[["vines_grow",.20*travel],["thorns_tighten",.78*travel]]
			"resurrection":
				if stage=="travel":marks=[["lantern_soul",.10*travel]]
				elif stage=="impact":out.append(healing(b))
			"vanish":
				if stage=="travel":
					marks=[["vanish_portal",.12*travel]]
					var count=int(e.get("card_count",0))
					for i in range(count):marks.append(["vanish_paper",minf(.9,.35+i*.09)*travel,2./sqrt(maxi(1,count))])
			"heart":
				if stage=="travel":
					marks=[["heart_flow",.10*travel]]
					for pulse in [.0833,.4167,.75]:marks.append(["heartbeat",pulse*travel])
			"life_steal":
				if op=="life_after":
					if stage=="travel":marks=[["life_return",.12*travel]]
					elif stage=="impact":out.append(healing(b))
			"eye":
				if stage=="travel":
					marks=[["eye_open",.23*travel]]
					for i in range(3):marks.append(["eye_sweep",(.45+i*.09)*travel,1.2])
			"privilege":
				if stage=="travel":marks=[["crown_ascend",.12*travel],["crown_settle",.71*travel]]
	elif kind=="death_strike":
		var hit=e.get("targets",[]).any(func(h):return not h.get("miss",false) and not h.get("blocked",false) and int(h.get("amount",0))>0)
		match key:
			"death_sentence":
				if stage=="travel":marks=[["reaper_arrive",.12*travel],["scythe_sweep",maxf(0.,travel-.16)]]
				elif stage=="impact" and hit:marks=[["reap_contact",0.],["soul_release",.18]]
			"last_dance":
				var index=posmod(int(e.get("action",{}).get("hits",1))-1,3)
				if stage=="travel":marks=[["dance_sweep_%d"%index,.24*travel]]
				elif stage=="impact" and hit:marks=[["dance_hit_%d"%index,0.]]
			"life_steal":
				if stage=="travel":marks=[["drain_tendrils",.20*travel]]
				elif stage=="impact" and hit:marks=[["drain_contact",0.]]
			"curse":
				if stage=="travel":marks=[["vines_grow",.20*travel]]
				elif stage=="impact" and hit:marks=[["curse_wither",0.]]
	elif kind=="hand_transfer" and key=="curse" and stage=="travel":marks=[["curse_carry",.05*travel]]
	elif kind=="blessing" and key=="blessing":
		marks=[["blessing_unfurl",.06*travel]] if stage=="travel" else [["blessing_settle",0.]] if stage=="impact" else []
	elif kind=="draw_cards" and stage=="travel":
		for d in e.get("draws",[]):
			if d.get("source_key","")!="legacy":continue
			for i in range(int(d.get("count",0))):
				if d.starts[i]>=0 and not d.returned[i]:out.append({"file":b.gem_movement.deal,"delay":d.starts[i]/1000.+.08,"cut_with_stage":false,"gain":1.1})
	for cue in marks:out.append({"file":bank[cue[0]],"delay":cue[1],"cut_with_stage":false,"gain":cue[2] if cue.size()>2 else 2.})
	return out
static func healing(b):return {"file":b.cards.heal.impact,"delay":0.,"cut_with_stage":false,"gain":1.}
