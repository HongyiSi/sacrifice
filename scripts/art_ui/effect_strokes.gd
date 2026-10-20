extends RefCounted
## Shared painted ribbons for controllers that also own private card movement.
static func ribbon(canvas,points,width,color,alpha=1.0):
	if points.size()<3 or alpha<.005:return
	var shape=PackedVector2Array();var outer=PackedVector2Array();var colors=PackedColorArray();var tail=PackedColorArray()
	for i in range(points.size()):
		var u=float(i)/(points.size()-1);var normal=(points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized().orthogonal()
		var w=width*pow(maxf(.001,sin(u*PI)),.65)
		shape.append(points[i]-normal*w*.1);outer.append(points[i]+normal*w)
		colors.append(Color(color.lightened(.27),alpha*.92));tail.append(Color(color.darkened(.17),alpha*.055))
	outer.reverse();tail.reverse();shape.append_array(outer);colors.append_array(tail)
	if Geometry2D.triangulate_polygon(shape).is_empty():return
	canvas.draw_polygon(shape,colors)
	canvas.draw_polyline(points,Color(color,alpha*.35),4.0,true)
	canvas.draw_polyline(points,Color("fff6dd",alpha*.9),1.3,true)
static func slash(canvas,p,angle,r,age,color):
	if age<0 or age>.57:return
	var alpha=1-smoothstep(.13,.56,age);var reveal=smoothstep(-.01,.12,age);var points=PackedVector2Array()
	for i in range(61):
		var a=lerpf(-2.75,1.45,float(i)/60*reveal);points.append(p+Vector2(cos(a)*r,sin(a)*r*.43).rotated(angle))
	ribbon(canvas,points,25,color,alpha)
	var faint=PackedVector2Array()
	for q in points:faint.append(p+(q-p)*1.14)
	ribbon(canvas,faint,4.5,color,alpha*.45)
