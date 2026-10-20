extends RefCounted
const Painted=preload("res://scripts/art_ui/painted_frames.gd")
const Circle=preload("res://scripts/art_ui/skill_circle.gd")
static var elapsed=-1.0
static var active=true
const PALETTE=[Color("d9a337"),Color("387fab"),Color("398760"),Color("b4483f"),Color("171b21")]
const LIGHT=[Color("fff0b1"),Color("bde9ff"),Color("cbebbb"),Color("ffb59d"),Color("747e89")]
class LightLayer extends Control:
	var lines=preload("res://scripts/art_ui/reusable_lines.gd").new()
	var draw_fn:Callable
	var body:Rect2
	var group=0
	var above=false
	var phase=0.0
	func _process(_dt):
		self_modulate=get_parent().self_modulate
		if above:get_parent().get_node("PriorityFrame").self_modulate=self_modulate
		if group>=0 and group<4 and is_visible_in_tree():queue_redraw()
	func _draw():
		lines.begin(self)
		draw_fn.call(lines,body,group,above,phase)
		lines.finish()
static func group_for(info,death=false,hidden=false):
	if hidden:return -1
	if info.get("type","")=="诅咒":return 4
	if death or info.has("priority") or int(info.get("main",-1))<0:return -1
	var rank=int(info.get("main",0))%100
	if rank==10:return 0
	if rank in [9,8,7]:return 1
	if rank in [2,1]:return 2
	if rank==0:return 3
	return -1
static func install_frame(c,tex,body,info,death,hidden):
	var group=group_for(info,death,hidden)
	var frame=c.get_node_or_null("PriorityFrame")
	if frame==null:
		var aura=LightLayer.new();aura.name="PriorityAura";aura.draw_fn=draw_layer;aura.show_behind_parent=true;aura.mouse_filter=Control.MOUSE_FILTER_IGNORE;c.add_child(aura)
		frame=TextureRect.new();frame.name="PriorityFrame";frame.show_behind_parent=true;frame.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;frame.stretch_mode=TextureRect.STRETCH_SCALE;c.add_child(frame)
		var rim=LightLayer.new();rim.name="PriorityRim";rim.draw_fn=draw_layer;rim.above=true;rim.show_behind_parent=true;rim.mouse_filter=Control.MOUSE_FILTER_IGNORE;c.add_child(rim)
	frame.texture=Painted.texture(group,death) if group>=0 else tex
	frame.position=body.position;frame.size=body.size
	frame.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	frame.material=Circle.material_for(frame.texture) if Circle.applies(info,death,hidden) else null
	c.set_meta("painted_frame_group",group)
	for child_name in ["PriorityAura","PriorityFrame","PriorityRim"]:
		c.get_node(child_name).show();c.get_node(child_name).self_modulate=c.self_modulate
	for name in ["PriorityAura","PriorityRim"]:
		var layer=c.get_node(name);layer.body=body;layer.group=group;layer.phase=float(int(info.get("secondary",1))%7)*.12;layer.queue_redraw()
static func outline(r,rounding):
	var pts=PackedVector2Array();var a=[Vector2(r.end.x-rounding,r.position.y+rounding),Vector2(r.end.x-rounding,r.end.y-rounding),Vector2(r.position.x+rounding,r.end.y-rounding),Vector2(r.position.x+rounding,r.position.y+rounding)]
	for corner in range(4):
		for i in range(13):
			var theta=-PI/2+corner*PI/2+float(i)/12*PI/2;pts.append(a[corner]+Vector2(cos(theta),sin(theta))*rounding)
	pts.append(pts[0]);return pts
static func at(edge,dist):
	for i in range(edge.size()-1):
		var length=edge[i].distance_to(edge[i+1])
		if dist<=length:return edge[i].lerp(edge[i+1],dist/maxf(.001,length))
		dist-=length
	return edge[0]
static func length_of(edge):
	var total=0.0
	for i in range(edge.size()-1):total+=edge[i].distance_to(edge[i+1])
	return total
static func trail(c,edge,head,span,color,light,width,strength):
	var total=length_of(edge)
	var points=PackedVector2Array();var inner=PackedColorArray();var outer=PackedColorArray()
	for i in range(81):
		var k=float(i)/80;var d=fposmod(head-span*k,total);var a=pow(1-k,1.35)*strength
		points.append(at(edge,d));inner.append(Color(light,a));outer.append(Color(color,a*.20))
	c.draw_polyline_colors(points,outer,width*3.3,true);c.draw_polyline_colors(points,inner,width,true)
static func draw_layer(c,body,group,above,phase):
	if group<0 or not active:return
	var s=body.size.x/74.0;var clock=(elapsed if elapsed>=0 else Time.get_ticks_msec()/1000.0)+phase;var r=body.grow(.25*s);var edge=outline(r,4.4*s);var perimeter=length_of(edge)
	var col=PALETTE[group];var light=LIGHT[group];var breathing=.72+.20*sin(clock*TAU/4.8)
	if group==4:
		return
	var cycle=fposmod(clock,3.8)
	var heart=exp(-pow((cycle-.72)/.23,2))+exp(-pow((cycle-1.14)/.30,2))*.62
	if not above:
		var strength=.86 if group==0 else .68 if group==1 else .40 if group==2 else .40+.44*heart
		for i in range(6,0,-1):c.draw_polyline(edge,Color(col,.016*strength*breathing),s*(2.0+i*1.30),true)
		return
	c.draw_polyline(edge,Color(col,.62),s*.62,true)
	if group==0:
		for offset in [0.0,.5]:trail(c,edge,fposmod(clock/4.8+offset,1.0)*perimeter,perimeter*.16,col,light,.95*s,.92)
		for x in [body.position.x+4.2*s,body.end.x-4.2*s]:
			for y in [body.position.y+4.2*s,body.end.y-4.2*s]:
				var a=.13+.13*sin(clock*TAU/4.8+(x+y)*.01);c.draw_circle(Vector2(x,y),2.2*s,Color(light,a))
	elif group==1:
		for side in [-1,1]:
			var points=PackedVector2Array();var colors=PackedColorArray();var halo=PackedColorArray();var head=fposmod(clock/5.2+(0 if side<0 else .5),1.0)
			for i in range(41):
				var u=float(i)/40;var y=body.position.y+(6+u*92)*s;var x=body.get_center().x+side*(body.size.x*.5-1.8*s)+sin(u*TAU*1.5+clock*2.2)*.40*s;points.append(Vector2(x,y))
				var d=absf(u-head);var a=exp(-d*d/0.030)*.68;colors.append(Color(light,a));halo.append(Color(col,a*.35))
			c.draw_polyline_colors(points,halo,3.2*s,true);c.draw_polyline_colors(points,colors,.80*s,true)
		trail(c,edge,fposmod(clock/8.5,1.0)*perimeter,perimeter*.1,col,light,.6*s,.37)
	elif group==2:
		for sx in [-1,1]:
			for sy in [-1,1]:
				var origin=Vector2(body.position.x if sx>0 else body.end.x,body.position.y if sy>0 else body.end.y)
				var points=PackedVector2Array()
				for i in range(24):
					var u=float(i)/23;points.append(origin+Vector2(sx*(2.1+9.3*u*u),sy*(12.2-9.9*sin(u*PI/2)))*s)
				c.draw_polyline(points,Color(light,.22+.22*breathing),.60*s,true)
				var pos=origin+Vector2(sx*4.4,sy*6.0)*s;var leaf=PackedVector2Array([pos,pos+Vector2(sx*1.3,sy*-3.0)*s,pos+Vector2(sx*3.3,sy*-3.0)*s,pos+Vector2(sx*2.2,sy*-.3)*s])
				c.draw_colored_polygon(leaf,Color(light,.25+.20*breathing))
		for side in [-1,1]:
			var x=body.position.x+.8*s if side<0 else body.end.x-.8*s
			for i in range(45):
				var u=float(i)/45;var d=absf(u-fposmod(clock/5.6,1.0));var a=exp(-d*d/.055)*.28
				c.draw_line(Vector2(x,body.end.y-u*body.size.y),Vector2(x,body.end.y-(u+1.0/45)*body.size.y),Color(light,a),.8*s,true)
	else:
		c.draw_polyline(edge,Color(light,.08+.32*heart),(.64+.30*heart)*s,true)
		var outside=outline(body.grow((.55+.9*heart)*s),4.8*s)
		c.draw_polyline(outside,Color(col,.11+.13*heart),1.0*s,true)
		for offset in [.0,.5]:trail(c,edge,fposmod(clock/7.6+offset,1.0)*perimeter,perimeter*.11,col,light,.65*s,.20+.34*heart)
