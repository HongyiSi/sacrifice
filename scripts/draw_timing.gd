extends RefCounted
## Faster consecutive cards, with increasing arrival times and a readable floor.
const INITIAL_FLIGHT_MS=1650
const INITIAL_GAP_MS=400
const MAX_SPEED_MULTIPLIER=1.5
const MAX_LAUNCH_RATE_MULTIPLIER=2.0
static func flight(index:int)->int:
	return maxi(roundi(INITIAL_FLIGHT_MS/MAX_SPEED_MULTIPLIER),roundi(INITIAL_FLIGHT_MS*pow(.85,index)))
static func gap(index:int)->int:
	return maxi(roundi(INITIAL_GAP_MS/MAX_LAUNCH_RATE_MULTIPLIER),roundi(INITIAL_GAP_MS*pow(.85,index)))
