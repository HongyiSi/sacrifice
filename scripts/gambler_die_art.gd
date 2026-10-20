extends RefCounted
## Shared paper die: identical faces, ink, pips and projection on the card and in flight.
static var textures:Dictionary={}
static func rest_basis()->Basis:
	return Basis(Vector3.RIGHT,-.30)*Basis(Vector3.UP,-.45)

static func project(v:Vector3,side:float)->Vector2:
	return Vector2(v.x,v.y)*side*.5*(4.8/(5.8-v.z))

static func geometry(side:float,basis:Basis)->Array:
	var faces:Array=[]
	for f in [
		[Vector3(0,0,1),Vector3.RIGHT,Vector3.DOWN,5],
		[Vector3(0,0,-1),Vector3.LEFT,Vector3.DOWN,2],
		[Vector3(1,0,0),Vector3.FORWARD,Vector3.DOWN,3],
		[Vector3(-1,0,0),Vector3.BACK,Vector3.DOWN,4],
		[Vector3(0,-1,0),Vector3.RIGHT,Vector3.BACK,1],
		[Vector3(0,1,0),Vector3.RIGHT,Vector3.FORWARD,6]]:
		var normal:Vector3=basis*f[0]
		if normal.z>1.0/5.8+.005:faces.append({"n":f[0],"u":f[1],"v":f[2],"value":f[3],"light":normal.z})
	faces.sort_custom(func(a,b):return a.light<b.light)
	for face in faces:
		var points:=PackedVector2Array()
		for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			var center:Vector2=corner*.88
			var angle:float=atan2(corner.y,corner.x)-PI*.25
			for i in range(4):
				var uv:Vector2=center+Vector2.from_angle(angle+i*PI/6)*.12
				points.append(project(basis*(face.n+face.u*uv.x+face.v*uv.y),side*42/64))
		face.outline=points
		face.fill=Color("f5e7c9").lerp(Color("c8a77c"),(1-face.light)*.42)
		face.pips=[]
		for pip in pips(face.value):
			var circle:=PackedVector2Array()
			for i in range(20):
				var uv:Vector2=pip+Vector2.from_angle(i*TAU/20)*.16
				circle.append(project(basis*(face.n+face.u*uv.x+face.v*uv.y),side*42/64))
			face.pips.append(circle)
	return faces

static func draw(canvas:Control,at:Vector2,side:float,basis:Basis,ink:Color,alpha:float)->void:
	canvas.draw_set_transform(at)
	for face in geometry(side,basis):
		fill_convex(canvas,face.outline,Color(face.fill,alpha))
		var outline:PackedVector2Array=face.outline.duplicate();outline.append(outline[0])
		canvas.draw_polyline(outline,Color(ink,alpha),side*2.7/72,true)
		for pip in face.pips:fill_convex(canvas,pip,Color(ink,alpha))
	canvas.draw_set_transform(Vector2.ZERO)

static func fill_convex(canvas:Control,points:PackedVector2Array,color:Color)->void:
	for i in range(1,points.size()-1):
		canvas.draw_primitive(PackedVector2Array([points[0],points[i],points[i+1]]),PackedColorArray([color]),PackedVector2Array())

static func svg_points(points:PackedVector2Array)->String:
	var values:=PackedStringArray()
	for p in points:values.append("%.4f,%.4f"%[p.x+32,p.y+32])
	return " ".join(values)

static func texture(ink:String)->Texture2D:
	if textures.has(ink):return textures[ink]
	var svg:='<svg xmlns="http://www.w3.org/2000/svg" width="384" height="384" viewBox="0 0 64 64">'
	for face in geometry(64,rest_basis()):
		svg+='<polygon points="%s" fill="#%s" stroke="#%s" stroke-width="2.4" stroke-linejoin="round"/>'%[svg_points(face.outline),face.fill.to_html(false),ink]
		for pip in face.pips:svg+='<polygon points="%s" fill="#%s"/>'%[svg_points(pip),ink]
	svg+='</svg>'
	var img:=Image.new();img.load_svg_from_string(svg)
	var tex:=ImageTexture.create_from_image(img);textures[ink]=tex
	return tex

static func pips(value:int)->Array:
	var a:=Vector2(-.5,-.5);var b:=Vector2(.5,.5)
	match value:
		1:return [Vector2.ZERO]
		2:return [a,b]
		3:return [a,Vector2.ZERO,b]
		4:return [a,Vector2(.5,-.5),Vector2(-.5,.5),b]
		5:return [a,Vector2(.5,-.5),Vector2.ZERO,Vector2(-.5,.5),b]
	return [a,Vector2(.5,-.5),Vector2(-.5,0),Vector2(.5,0),Vector2(-.5,.5),b]
