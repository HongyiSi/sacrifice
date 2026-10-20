extends RefCounted
## Approved timeline uses a continuous art clock across server-owned phases.
const DRAW_OFFSET=2.0
const DRAW_END=6.97
const PACK_OFFSET=8.72
static func hand_dock(actor,mine):
	var p=preload("res://scripts/board_layout.gd").hand_origin(actor,actor/3==mine)+(Vector2(341,-92) if actor/3==mine else Vector2(221,244))
	p.x=minf(p.x,1350)
	return p
static func supports(e):
	return e.get("prepared_draw",false) or (e.get("kind","")=="card_effect" and e.get("style","")=="prepared")
static func configure_draw(e):
	e.prepared_draw=true;e.style="prepared";e.travel_ms=4970;e.impact_ms=0
	var ordinal=0
	for d in e.draws:
		d.prepared_draw=true
		for i in range(d.count):
			if d.returned[i]:continue
			d.starts[i]=50+ordinal*500
			d.durations[i]=4190+ordinal*430-d.starts[i]
			ordinal+=1
		d.speech_start=3100
		if d.returned.has(true):e.travel_ms=maxi(e.travel_ms,d.speech_start+d.speech_ms)
static func cues(e,bank):
	var out=[]
	if e.get("stage","")!="travel":return out
	var b=bank.get("prepared",{})
	var op=e.get("op","")
	if op=="prepared_depart":
		add(out,b.get("lift",""),.60);add(out,b.get("open",""),1.55)
		add(out,bank.cards.collect.open,1.60,.77)
	elif e.get("prepared_draw",false):
		var ordinal=0
		for d in e.draws:
			for i in range(d.count):
				if d.returned[i]:continue
				add(out,b.get("paper_in",""),.05+ordinal*.50,1.26 if ordinal==0 else 1.232)
				add(out,b.get("paper_out",""),3.15+ordinal*.43,1.4 if ordinal==0 else 1.33)
				add(out,"res://assets/sfx/cards/place.ogg",(d.starts[i]+d.durations[i])/1000.,.84)
				ordinal+=1
		add(out,b.get("close",""),1.60);add(out,b.get("carry",""),1.95);add(out,b.get("open",""),2.80,1.26)
	elif op=="prepared_arrive":
		add(out,b.get("close",""),0.);add(out,b.get("carry",""),.35);add(out,b.get("open",""),1.20,1.26)
	elif op in ["prepared_pack","prepared_finish"]:
		var base=PACK_OFFSET if op=="prepared_pack" else 10.42
		for i in range(e.get("hand_motion",{}).get("slots",[]).size()):add(out,b.get("paper_in",""),i*.48,1.4 if i==0 else 1.33)
		add(out,b.get("close",""),10.42-base,1.33);add(out,b.get("disappear",""),10.94-base)
	return out
static func add(out,file,delay,gain=1.4):
	if not file.is_empty():out.append({"file":file,"delay":delay,"cut_with_stage":false,"gain":gain})
