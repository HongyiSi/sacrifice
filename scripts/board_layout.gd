extends RefCounted
## Shared coordinates for table widgets and the existing card/attack animations.
const COLUMNS := 4
const SLOTS := 8
const CARD_SIZE := Vector2(76,108)
const FRIENDLY_PLAYED_Y := 399.0
const PLAYED_SCALE := 0.72
const PLANNING_BAR_Y := 329.0
const DECK_RECT := Rect2(0,268,149,224)
const DECK_CENTER := Vector2(77.9,369.9)
const DECK_EXIT := Vector2(166,343)
const DECK_LOCK := Vector2(120.75,386.95)
const CONFIRM_RECT := Rect2(1175,460,148,54)
const PHASE_CENTER_Y := 390.0
const PHASE_COLORS := {"start":Color("a9d4ed"),"planning":Color("a9d4ed"),"resolution":Color("f5d38c"),"death":Color("d0b6f1")}
const PHASE_TITLES := {"start":"游戏开始","planning":"出牌阶段","resolution":"结算阶段","death":"亡语阶段"}

static func column_x(id: int) -> float:
	return 157.0+(id%3)*390.0

static func hand_scale(friendly: bool) -> float:
	return 1.0 if friendly else 0.42

static func hand_origin(id: int, friendly: bool) -> Vector2:
	return Vector2(column_x(id)+(0 if friendly else 200),684 if friendly else 132)

static func hand_size(friendly: bool) -> Vector2:
	return Vector2(340,224) if friendly else Vector2(143,97)

static func hand_slot(index: int, friendly: bool) -> Vector2:
	# Eight real slots; the rules reject incoming cards beyond this cap.
	var slot := mini(index,SLOTS-1)
	return Vector2(slot%COLUMNS,slot/COLUMNS)*Vector2(88,116) * hand_scale(friendly) + Vector2(0,2*(slot/COLUMNS) if not friendly else 0)

static func hand_position(id: int, index: int, friendly: bool) -> Vector2:
	return hand_origin(id,friendly)+hand_slot(index,friendly)

static func pawn_rect(id: int, friendly: bool) -> Rect2:
	return Rect2(column_x(id)+(78 if friendly else 43),522 if friendly else 142,175 if friendly else 120,128)

static func death_origin(id: int, friendly: bool) -> Vector2:
	if friendly: return Vector2(column_x(id)+225,533)
	# Keep enemy death cards below the hand, clear of the pawn's health strip.
	return hand_origin(id,false)+Vector2((hand_size(false).x-120)/2,107)

static func pawn_center(id: int, friendly: bool) -> Vector2:
	var rect := pawn_rect(id,friendly)
	return rect.position+Vector2(rect.size.x/2,59)
