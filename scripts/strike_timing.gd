extends RefCounted
## Drawing and sound scheduling share the physical blade contact times.
const SWORDS=["strike","double_strike","triple_strike","quick_strike","area_strike","precise_strike","godslayer","holy_strike","bounty","glory","final_strike","judgment"]
const SINGLE_CARD=["strike","quick_strike","bounty","glory","final_strike","godslayer","holy_strike"]
const CARD_ANGLE=PI/6.0
static func count(key):return {"double_strike":2,"triple_strike":3}.get(key,1)
static func gap(event):return minf(.21,float(event.get("impact_ms",600))/1000.0*.5/maxi(1,count(event.get("style",""))-1))
static func contact(event,index):return float(event.travel_ms)/1000.0+index*gap(event)
static func flight_lead(key):return .20 if key=="quick_strike" else .22 if key=="holy_strike" else .1584 if key=="judgment" else .35
