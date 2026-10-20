extends RefCounted
## Broad, circular lobes and a softly rounded tip; shared at every health size.
static func outline(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var start := Vector2(0,-.32)
	var curves := [
		[Vector2(-.38,-1.04),Vector2(-1.06,-.76),Vector2(-1,-.12)],
		[Vector2(-.96,.3),Vector2(-.44,.73),Vector2(-.12,.94)],
		[Vector2(-.05,1),Vector2(.05,1),Vector2(.12,.94)],
		[Vector2(.44,.73),Vector2(.96,.3),Vector2(1,-.12)],
		[Vector2(1.06,-.76),Vector2(.38,-1.04),Vector2(0,-.32)]
	]
	for curve in curves:
		for i in range(12): points.append(center+start.bezier_interpolate(curve[0],curve[1],curve[2],i/12.0)*radius)
		start = curve[2]
	return points
