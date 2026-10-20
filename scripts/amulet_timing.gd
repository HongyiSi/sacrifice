extends RefCounted
## The approved second preview uses absolute seconds, without legacy rescaling.
const LIFT_START=.32
const LIFT_END=1.10
const FIRE_START=1.85
const HIT=2.10
const FIRE_OFF=2.78
const BURN_END=4.20
const RETURN_START=4.38
const RETURN_END=4.86
const END=4.98
const TRAVEL_MS=2100
const IMPACT_MS=2880
const DISCARD_MS=700
const CHARGE_SOUND=1.08
const DISCARD_SOUND=.03
# Match the approved preview at the existing default sound-volume setting.
# Asset PCM stays below full scale; per-voice gain preserves the volume slider.
const SOUND_GAIN=2.0
