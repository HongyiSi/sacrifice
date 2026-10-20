extends RefCounted
const MORPH_MS=180
const FLIGHT_MS=900
const STEP_MS=300
const TAIL_MS=420
static func arrival(index:int)->int:return index*STEP_MS+MORPH_MS+FLIGHT_MS
