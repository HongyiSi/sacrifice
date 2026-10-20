extends Control
## Painted, state-driven deathrattle companions. No history or private cards.
const Art=preload("res://scripts/cinema/atlas.gd")
const Layout=preload("res://scripts/board_layout.gd")
const Landmarks=preload("res://scripts/pawn_landmarks.gd")
const KEYS=["blessing","greed","prison","privilege","eye","ghost","immortal"]
const ALL_KEYS=["blessing","greed","prison","privilege","eye","ghost","immortal","pain","divinity"]
const POSES={
	"blessing":[Vector2(0,-42),144.0],
	"greed":[Vector2(32,41),53.0],
	"prison":[Vector2(0,3),132.0],
	"privilege":[Vector2(2,-37),48.0],
	"eye":[Vector2(-28,-24),49.0],
	"ghost":[Vector2(-37,10),69.0],
	"immortal":[Vector2(35,9),66.0]
}
var board
var pawn:Dictionary
var sprite:Control
var rest_position=Vector2.ZERO
var deity:Control
var back=false
var keys:Array=[]
var event:Dictionary={}
var statuses:Dictionary={}
var clock_started=0
var elapsed=0.0
var event_started=0

static func is_arrival(e:Dictionary)->bool:
	return e.get("style","") in KEYS and (e.get("op","")=="activate" or e.get("kind","")=="blessing")
static func affects(e:Dictionary,id:int)->bool:
	return e.get("targets",[]).any(func(h):return int(h.id)==id)
static func visible_keys(c:Dictionary,e:Dictionary)->Array:
	var result:Array=[]
	for s in c.get("ongoing_effects",[]):
		if s.key in ALL_KEYS and not result.has(s.key):result.append(s.key)
	if is_arrival(e) and affects(e,c.id) and not result.has(e.style):result.append(e.style)
	return result
static func install(table,c,target,pawn_sprite):
	var e:Dictionary=table.view.get("animation",{})
	var found=visible_keys(c,e)
	pawn_sprite.set_meta("death_prop_rest_position",pawn_sprite.position)
	var divine=null
	for child in target.get_children():
		if child.has_meta("divinity_actor"):divine=child
	if found.has("blessing") or found.has("privilege") or divine!=null:
		var top=10000.
		if divine!=null:
			var factor=divine.texture_rect.size.x/divine.texture.get_width()
			var art_top=pawn_sprite.texture.region.position.y*factor
			var halo_top=divine.halo_pixel.y*factor-10.
			top=target.position.y+divine.texture_rect.position.y+minf(art_top,halo_top)-divine.hover_height-2.
		for k in ["blessing","privilege"]:
			if not found.has(k):continue
			var dock=world_pose(table,c.id,k,found)
			var prop_top=dock.at.y-dock.side*.5*(.78 if k=="privilege" else 1.)
			if divine!=null:prop_top+=divine.lift-divine.hover_height-1.5
			top=minf(top,prop_top)
		for label in table.canvas.get_children():
			if label.get_meta("pawn_title",-1)!=c.id:continue
			label.z_index=2
			var label_y=top-label.size.y-4
			if label_y>=87:label.position.y=minf(label.position.y,label_y)
			else:label.position.x+=135 if int(c.id/3)!=table.mine else -125
	if not found.any(func(key):return key in KEYS):return
	var stamp="%d/%d/%s"%[table.view.match,e.get("id",-1),e.get("stage","")]
	if not e.is_empty() and table.ui.effect_key!=stamp:
		table.ui.effect_key=stamp;table.ui.effect_started=Time.get_ticks_msec()
	for behind in [true,false]:
		var n=load("res://scripts/persistent_death_props.gd").new()
		n.board=table;n.pawn=c;n.sprite=pawn_sprite;n.rest_position=pawn_sprite.position;n.back=behind;n.keys=found
		n.event=e;n.event_started=table.ui.effect_started
		n.mouse_filter=Control.MOUSE_FILTER_IGNORE;n.size=target.size
		# Keep the pawn sprite at child zero (combat controllers depend on it).
		n.show_behind_parent=behind
		for child in target.get_children():
			if child.has_meta("divinity_actor"):n.deity=child
		for s in c.get("ongoing_effects",[]):n.statuses[s.key]=s
		n.set_meta("persistent_death_props",c.id);n.set_meta("back_layer",behind)
		target.add_child(n)

static func pose_for(table,id:int,key:String,all:Array)->Dictionary:
	var own=id/3==table.mine
	var factor=1.0 if own or key=="blessing" else .84
	var offset:Vector2=POSES[key][0];var side:float=POSES[key][1]
	if all.size()>=4 and key not in ["prison","blessing"]:side*=.86
	if key=="eye" and (all.has("privilege") or all.has("blessing")):offset=Vector2(-43,-19);side=minf(side,43)
	if key=="ghost" and all.has("eye"):offset=Vector2(-40,29);side=minf(side,59)
	if key=="immortal" and (all.has("greed") or all.has("blessing")):offset=Vector2(40,-10);side=minf(side,56)
	if key=="greed" and all.has("prison"):offset=Vector2(43,45);side=minf(side,47)
	if key=="privilege":
		for target in table.canvas.get_children():
			if target.get_meta("knight_id",-1)!=id:continue
			var sprite=target.get_child(0)
			offset=(Landmarks.head(sprite)+Vector2(0,-side*factor*.78*.30)-Vector2(sprite.size.x*.5,59))/factor
			break
	return {"at":Layout.pawn_center(id,own)+offset*factor,"side":side*factor,"offset":offset*factor}

static func world_pose(table,id:int,key:String,all:Array)->Dictionary:
	var pose=pose_for(table,id,key,all)
	for target in table.canvas.get_children():
		if target.get_meta("knight_id",-1)!=id:continue
		var sprite=target.get_child(0)
		var center=Vector2(sprite.size.x*.5,59)
		pose.at=target.position+sprite.get_transform()*(center+pose.offset)
		if key in ["prison","greed"]:pose.at=target.position+sprite.get_meta("death_prop_rest_position",sprite.position)+center+pose.offset
		else:
			for child in target.get_children():
				if child.has_meta("divinity_actor"):pose.at+=Vector2(0,-child.lift)
		break
	return pose

static func shade(c:CanvasItem,at:Vector2,side:float,alpha:float):
	# Soft, warm contact shadow under objects resting on the table.
	for j in range(4,0,-1):
		var points=PackedVector2Array()
		for i in range(32):points.append(at+Vector2(cos(i*TAU/32)*side*(.35+j*.015),sin(i*TAU/32)*side*(.065+j*.007)))
		c.draw_colored_polygon(points,Color(.18,.10,.055,alpha*.035))
static func cage_front(c:CanvasItem,at:Vector2,side:float,a:float):
	var tex:AtlasTexture=Art.texture("prison")
	var dimensions=tex.get_size()*side/maxf(tex.get_width(),tex.get_height())
	# Reuse the exact painted front sill and two near bars, with their original
	# alpha edges. The pawn sits between the back painting and these metal parts.
	var strips=[Rect2(0,.86,.83,.14),Rect2(.18,.41,.045,.46),Rect2(.44,.43,.045,.44)]
	for r in strips:
		var part=AtlasTexture.new();part.atlas=tex.atlas
		part.region=Rect2(tex.region.position+r.position*tex.region.size,r.size*tex.region.size)
		part.filter_clip=true
		c.draw_texture_rect(part,Rect2(at-dimensions*.5+r.position*dimensions,r.size*dimensions),false,Color(1,1,1,a))
static func paint(c:CanvasItem,key:String,at:Vector2,side:float,time:float,a:float=1.0,behind:bool=false):
	if a<.002:return
	if key=="prison":
		if behind:Art.draw_prop(c,key,at,side,0,a)
		else:cage_front(c,at,side,a)
		return
	if behind:return
	match key:
		"blessing":Art.draw_prop(c,key,at,side,.012*sin(time*.8),a)
		"greed":
			shade(c,at+Vector2(0,side*.46),side,a)
			Art.draw_prop(c,key,at,side,0,a)
			var glint=pow(maxf(0.,sin(time*.65)),24)*a*.62
			if glint>.02:
				var tip=at+Vector2(.03,-.22)*side
				c.draw_line(tip+Vector2(-2,0),tip+Vector2(2,0),Color("fff4d2",glint),.9,true)
				c.draw_line(tip+Vector2(0,-2),tip+Vector2(0,2),Color("fff4d2",glint),.9,true)
		"privilege":Art.draw_prop(c,key,at,side,0,a,Vector2(1,.78))
		"eye":
			var blink=pow(maxf(0.,cos(time*.9)),70)
			Art.draw_prop(c,"eye",at+Vector2(0,sin(time*1.1)*.7),side,0,a*(1-blink))
			Art.draw_prop(c,"eye_closed",at+Vector2(0,sin(time*1.1)*.7),side,0,a*blink)
		"ghost":Art.draw_warp(c,"ghost",at+Vector2(0,sin(time*1.4)*1.4),side,time*.8,a)
		"immortal":Art.draw_prop(c,"phoenix_mid",at+Vector2(0,sin(time*1.2)*.7),side,0,a,Vector2(1,1+.018*sin(time*1.2)))

func _ready():
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;_process(0)
func _process(_delta):
	if clock_started>=0:elapsed=Time.get_ticks_msec()/1000.0
	queue_redraw()
func present(seconds):elapsed=seconds;queue_redraw()
func age()->float:
	if clock_started<0:return elapsed
	return maxf(0,(Time.get_ticks_msec()-event_started)/1000.)
func weight(key:String)->float:
	if is_arrival(event) and event.style==key and affects(event,pawn.id):
		if event.stage=="travel":return smoothstep(.65,.86,age()/maxf(.001,event.travel_ms/1000.))
		return 1.0
	if key=="immortal" and event.get("style","")==key and event.get("kind","")=="card_effect" and affects(event,pawn.id):
		if event.stage=="travel":return 1-smoothstep(0,.12,age()/maxf(.001,event.travel_ms/1000.))
		return smoothstep(.55,.95,age()/maxf(.001,event.impact_ms/1000.))
	return 1.0
func _draw():
	if not is_instance_valid(sprite):return
	for key in keys:
		if key not in KEYS:continue
		var pose=pose_for(board,pawn.id,key,keys)
		var center=Vector2(sprite.size.x*.5,59)
		var at:Vector2=sprite.get_transform()*(center+pose.offset)
		if key=="greed" or key=="prison":at=center+rest_position+pose.offset
		elif is_instance_valid(deity):at+=Vector2(0,-deity.lift)
		var a=weight(key)*(.66 if statuses.get(key,{}).get("dormant",false) else 1.0)
		paint(self,key,at,pose.side,elapsed+pawn.id*.43,a,back)

static func draw_arrival(f)->bool:
	if not is_arrival(f.event):return false
	if f.stage!="travel":return true
	var u=f.u
	for id in f.target_ids:
		var c=f.board.view.characters[id];var all=visible_keys(c,f.event)
		var pose=world_pose(f.board,id,f.key,all)
		var v=smoothstep(.12,.65,u)
		var at=f.bezier(f.source,pose.at,v,-47)
		if f.key=="prison":at=pose.at+Vector2(0,-80*(1-smoothstep(.18,.58,u)))
		var scale=lerpf(1.25,1.,v)
		var alpha=smoothstep(0,.10,u)*(1-smoothstep(.65,.86,u))
		if f.key=="eye":
			var opened=smoothstep(.23,.50,u)
			Art.draw_prop(f,"eye_closed",at,pose.side*scale,0,alpha*(1-opened))
			Art.draw_prop(f,"eye",at,pose.side*scale,0,alpha*opened)
		elif f.key=="blessing":Art.draw_prop(f,f.key,at,pose.side*scale,0,alpha,Vector2(lerpf(.18,1.,smoothstep(.06,.53,u)),1))
		elif f.key=="privilege":Art.draw_prop(f,f.key,at,pose.side*scale,0,alpha,Vector2(1,.78))
		else:Art.draw_prop(f,f.key,at,pose.side*scale,0,alpha)
		if f.key in ["greed","privilege"] and u<.72:f.stream(f.source,at,1,7,Color("e3be78"),alpha*.4,-47)
		if f.key=="eye":
			for slot in range(3):
				var target=f.hand((1-int(f.actor/3))*3+slot)
				var scan=smoothstep(.45+slot*.09,.91+slot*.02,u)
				f.stream(pose.at,target,scan,7,Color("93b8d3"),sin(scan*PI)*.24,-35)
	return true
