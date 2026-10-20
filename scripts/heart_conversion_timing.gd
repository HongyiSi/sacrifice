extends RefCounted
const DEPART=.20
const STEP=.46
const IN_FLIGHT=.78
const MORPH=.24
const OUT_START=.12
const OUT_STEP=.55
const OUT_FLIGHT=.62
const TAIL=.62
static func enter(i):return DEPART+i*STEP+IN_FLIGHT
static func leave(i):return OUT_START+i*OUT_STEP
static func arrive(i):return leave(i)+OUT_FLIGHT
static func gather_ms(n):return roundi((enter(maxi(0,n-1))+MORPH+.18)*1000) if n>0 else 550
static func release_ms(n):return roundi((arrive(maxi(0,n-1))+TAIL)*1000)
static func count(e):return e.get("hand_motion",{}).get("slots",[]).size() if e.get("kind","")=="card_effect" else int(e.get("action",{}).get("convert_count",0))
static func cues(e):
	var out=[];var n=count(e);var kind=e.get("kind","");var stage=e.get("stage","")
	if kind=="card_effect" and stage=="travel":
		for i in range(n):
			out.append(cue("paper_%d"%(i%3),DEPART+i*STEP,1.4))
			out.append(cue("transmute",enter(i)-.10,.85))
	elif kind=="heal" and stage=="impact":
		var gain=int(e.targets[0].after)-int(e.targets[0].before)
		for i in range(n):
			out.append(cue("heart_flight",leave(i),.85))
			if i<gain:out.append(cue("restore_%d"%(i%3),arrive(i),1.35))
	return out
static func cue(name,at,gain):return {"file":"res://assets/sfx/heart_conversion/"+name+".wav","delay":at,"cut_with_stage":false,"gain":gain}
