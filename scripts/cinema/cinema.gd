extends Control
const Art=preload("res://scripts/cinema/atlas.gd")
const Layout=preload("res://scripts/board_layout.gd")
const CardWidget=preload("res://scripts/card_widget.gd")
const FNT=preload("res://assets/fonts/NotoSansCJKsc-GameSubset.otf")
const WEAPONS=["strike","double_strike","triple_strike","quick_strike","area_strike","precise_strike","godslayer","holy_strike","magic_strike","bounty","glory","final_strike","hasty_spell","judgment"]
const HEALS=["heal","heal_other","team_heal","blood_rite","spare_food","spare_supplies","cards_to_heart"]
const GUARDS=["defense","holy_amulet","attack_amulet","magic_amulet","blessing"]
const GEMS=["sapphire","ruby","amethyst","topaz","emerald","amber"]
const DECK=Layout.DECK_CENTER
const DISCARD=Vector2(1280,533)
var event={}
var board
var mine=0
var key=""
var op=""
var kind=""
var stage=""
var source=Vector2.ZERO
var source_widget
var elapsed=0.0
var clock_started=-1
var duration=1.0
var u=0.0
var t=0.0
var actor=0
var targets=[]
var target_ids=[]
var target_point=Vector2.ZERO
var target_widget
var sprites={}
var outgoing=[]
var motion_points=[]
var motion_faces=[]
var marked_points=[]
var accent=Color("e9b96c")
var ink=Color("965927")
var handler
var hidden_nodes=[]
var initialized=false
static var modules={}
static var glow_texture:GradientTexture2D
static func family_for(e):
	if e.get("op","")=="discard_finish":return "ordinary_pose"
	var kind=e.get("kind","");var key=e.get("style","divinity" if kind.begins_with("divinity") else "strike")
	if key in ["defile","plunder","elegy","feign","spare_food","spare_supplies"]:return "ordinary_pose"
	if key=="cards_to_heart":return "heart_conversion"
	if key in ["curse","vanish"]:return "souls"
	if key=="boulder":return "hands"
	return "weapons" if kind in ["strike","death_strike"] and key in WEAPONS else "healing" if kind=="heal" else "guards" if kind in ["shield","shield_block","blessing"] else "gems" if kind=="gem_trigger" or (kind=="hand_transfer" and key in GEMS) else "hands" if kind in ["hand_transfer","blade_volley"] or key in ["collect","gambler","gift","plunder","bloodletting","gold_panning","search","cards_to_heart","cards_to_blades","frenzy","badge","legacy","greed","heart","sacrifice_badges","obstruct","poisoning","emerald","topaz","bounty","glory"] else "fate" if key in ["prophecy","mirror","reverse","ignore","skip_death","suppress","late_suppress","anticipation","peek","silence","defile","warcry","rally","overload","poison"] else "souls"
static func supports(e):
	return not e.get("hand_response",false) and not preload("res://scripts/amulet_cancel_effect.gd").supports(e) and not e.is_empty() and e.get("kind","") in ["strike","death_strike","heal","shield","blessing","card_effect","shield_block"] and (family_for(e)=="ordinary_pose" or ResourceLoader.exists("res://scripts/cinema/"+family_for(e)+".gd"))
func initialize(table):
	board=table;event=board.view.animation;mine=board.mine
	var stamp="%d/%d/%s"%[board.view.match,event.id,event.stage]
	if board.ui.effect_key!=stamp:board.ui.effect_key=stamp;board.ui.effect_started=Time.get_ticks_msec()
	clock_started=board.ui.effect_started
	kind=event.kind;stage=event.stage;key=event.get("style","divinity" if kind.begins_with("divinity") else "strike");op=event.get("op","");actor=int(event.get("action",{}).get("actor",0))
	if int(event.get("placed_count",-1))==0 and key in ["obstruct","poisoning","gift"]:
		var speech=preload("res://scripts/pawn_speech.gd").new();add_child(speech)
		speech.configure(actor,"它的手牌满了！",Layout.pawn_rect(actor,actor/3==mine),Color("355f89") if actor/3==mine else Color("a95138"),duration+2)
		speech.started=clock_started;speech.present((Time.get_ticks_msec()-clock_started)/1000.0)
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter=Control.MOUSE_FILTER_IGNORE;size=Vector2(1440,960);z_index=75
	source_widget=board._active_widget()
	source=pawn(actor)+Vector2(65,-20)
	if source_widget!=null:source=local_center(source_widget,true)
	if key in ["spare_food","spare_supplies"] or op=="discard_finish":source=DISCARD;source_widget=null
	if kind=="gem_trigger":source=hand_slot(actor,int(event.get("owner_slot",event.get("hand_index",0))));source_widget=null
	for hit in event.get("targets",[]):target_ids.append(int(hit.id));targets.append(pawn(hit.id))
	if targets.is_empty():target_ids=[actor];targets=[pawn(actor)]
	var colors={"strike":"f2b95d","double_strike":"eda143","triple_strike":"ef764b","quick_strike":"6bdfe7","area_strike":"e7a753","precise_strike":"57d7b7","godslayer":"ae68ef","holy_strike":"f3d480","magic_strike":"b36aff","hasty_spell":"f87ba0","final_strike":"d25c70","heal":"88c958","heal_other":"67dcb7","team_heal":"a2d879","blood_rite":"e27983","spare_food":"e6b66d","spare_supplies":"bbd9ba","death":"9bcbe8"}
	accent=Color(colors.get(key,preload("res://scripts/card_palette.gd").glow(key).to_html(false)));ink=accent.darkened(.54)
	for node in board.canvas.get_children():
		if node.has_meta("knight_id"):
			var sprite=node.get_child(0);sprites[node.get_meta("knight_id")]={"node":sprite,"position":sprite.position,"color":sprite.modulate,"scale":sprite.scale,"rotation":sprite.rotation,"pivot":sprite.pivot_offset}
	for n in all_nodes(board.canvas):
		if event.has("target_action") and n.get_meta("played_action_id",-999)==event.target_action and (key not in ["suppress","late_suppress"] or not n.get_meta("played_death",false)):target_point=local_center(n);target_widget=n
		if n.has_meta("hand_actor") or n.has_meta("enemy_hand_actor"):
			var id=int(n.get_meta("hand_actor",n.get_meta("enemy_hand_actor",-1)))
			if id==int(event.get("hand_motion",{}).get("actor",actor)):
				for card in n.get_children():
					if not card is CardWidget:continue
					motion_points.append(local_center(card));motion_faces.append(card.card.get("key","") if id/3==mine else "")
		if key=="anticipation" and not n.get_meta("played_death",false) and n.has_meta("played_action_id") and n.get_meta("played_owner",0)/3!=actor/3 and not n.get_meta("played_revealed",false):marked_points.append(local_center(n))
	if kind=="hand_transfer":
		var recipient=int(event.get("recipient",target_ids[0]));var slot=int(event.get("owner_slot",0) if recipient/3==mine else event.get("hand_index",0))
		for n in all_nodes(board.canvas):
			if n.get_meta("hand_actor",-1)==recipient or n.get_meta("enemy_hand_actor",-1)==recipient:
				var cards=n.get_children().filter(func(c):return c is CardWidget)
				if slot<cards.size():cards[slot].hide();hidden_nodes.append(cards[slot])
	var family=family_for(event)
	var script_path="res://scripts/"+family+".gd" if family=="ordinary_pose" else "res://scripts/cinema/"+family+".gd"
	if ResourceLoader.exists(script_path):
		if not modules.has(family):modules[family]=load(script_path)
		handler=modules[family].new();handler.f=self
		if handler.has_method("setup"):handler.setup()
	else:push_error("UNIMPLEMENTED_FAMILY "+family+" "+key)
	initialized=true;set_process(true);present(maxf(0,(Time.get_ticks_msec()-clock_started)/1000.0))
func all_nodes(node):
	var result=[]
	for n in node.get_children():result.append(n);result.append_array(all_nodes(n))
	return result
func local_center(node,emblem=false):
	var p=node.emblem_center() if emblem else node.size*.5
	return board.canvas.get_global_transform().affine_inverse()*(node.get_global_transform()*p)
func pawn(id):return Layout.pawn_center(int(id),int(id)/3==mine)
func hand(id):return Layout.hand_origin(int(id),int(id)/3==mine)+Layout.hand_size(int(id)/3==mine)*.5
func hand_slot(id,slot):return Layout.hand_position(int(id),int(slot),int(id)/3==mine)+Layout.CARD_SIZE*Layout.hand_scale(int(id)/3==mine)*.5
func landing(id):return hand_slot(id,int(event.get("owner_slot",0) if int(id)/3==mine else event.get("hand_index",0)))
func crest():return Vector2(1035 if actor/3==mine else 414,56)
func reset_sprites():
	for s in sprites.values():
		if is_instance_valid(s.node):s.node.position=s.position;s.node.scale=s.scale;s.node.modulate=s.color;s.node.rotation=s.rotation;s.node.pivot_offset=s.pivot
func present(seconds):
	elapsed=seconds;t=seconds;stage=event.stage;duration=float(preload("res://scripts/strike_styles.gd").duration(event))/1000.0;u=clampf(t/maxf(.001,duration),0,1)
	reset_sprites()
	if kind=="hand_transfer":
		for n in hidden_nodes:
			if is_instance_valid(n):n.visible=stage!="travel" and u>.12
	if is_instance_valid(source_widget):
		source=local_center(source_widget,true);source_widget.motif_alpha=1.0-smooth(0,.13,u) if stage=="travel" else smooth(.55,.95,u);source_widget.queue_redraw()
		if preload("res://scripts/reverse_timing.gd").is_reverse(event):
			var age=preload("res://scripts/reverse_timing.gd").age(event,elapsed)
			source_widget.motif_alpha=1-smooth(.55,.80,age)*(1-smooth(4.1,4.5,age))
		if key=="search" and op=="search_depart":source_widget.motif_alpha=1.0
	if handler!=null and handler.has_method("update"):handler.update()
	queue_redraw()
func _process(_delta):present(maxf(0,(Time.get_ticks_msec()-clock_started)/1000.0))
func _draw():
	if not initialized or handler==null:return
	if not preload("res://scripts/persistent_death_props.gd").draw_arrival(self):handler.draw()
	if key!="cards_to_heart" and stage=="impact" and kind in ["strike","death_strike","heal"]:
		for h in event.get("targets",[]):
			var amount=int(h.get("amount",0));var label=("+" if kind=="heal" else "-")+str(amount)
			if amount>0:label_at(pawn(h.id)+Vector2(65,-42),label,Color("efffd5") if kind=="heal" else Color("fff0d1"),1-smooth(.65,1,u),23)
func _exit_tree():
	reset_sprites()
	for n in hidden_nodes:
		if is_instance_valid(n):n.show()
	if is_instance_valid(source_widget):source_widget.motif_alpha=1;source_widget.queue_redraw()
func smooth(a,b,x):return smoothstep(a,b,x)
func ease(x):return 1-pow(1-clampf(x,0,1),3)
func spring(x):return 1-exp(-maxf(0,x)*7)*cos(maxf(0,x)*13)
func envelope(x,a=.1,b=.75):return smooth(0,a,x)*(1-smooth(b,1,x))
func bezier(a,b,x,bend=-55.0):return a.lerp(b,x)+Vector2(0,bend*sin(x*PI))
func path(a,b,x,bend=-55.0):
	var pts=PackedVector2Array()
	for i in range(41):pts.append(bezier(a,b,lerpf(maxf(0,x-.28),x,float(i)/40),bend))
	return pts
func prop(which,p,side=100.0,angle=0.0,alpha=1.0,squash=Vector2.ONE,modulate=Color.WHITE):Art.draw_prop(self,which,p,side,angle,alpha,squash,modulate)
func shadow(p,rx,alpha=.2):
	if alpha>.002:ellipse(p,rx,rx*.20,Color(.15,.1,.12,alpha),0,true)
func line(points,col,width=2.0):
	if points.size()>1 and col.a>.003 and width>.05:draw_polyline(points,col,width,true)
func ellipse(p,rx,ry,col,rotation=0.0,fill=false):
	if rx<.2 or ry<.2 or col.a<.003:return
	var pts=PackedVector2Array()
	for i in range(65):pts.append(p+Vector2(cos(float(i)*TAU/64)*rx,sin(float(i)*TAU/64)*ry).rotated(rotation))
	if fill:draw_colored_polygon(pts,col)
	else:line(pts,col,1.6)
func ring(p,r,a=1.0,col=Color.TRANSPARENT,width=2.0,start=0.0,end=TAU):
	if col==Color.TRANSPARENT:col=accent
	if r>.5 and a>.003:draw_arc(p,r,start,end,64,Color(col,a),width,true)
func glow(p,r,a=.3,col=Color.TRANSPARENT):
	if col==Color.TRANSPARENT:col=accent
	if a<.001:return
	if glow_texture==null:
		var grad=Gradient.new();grad.set_color(0,Color.WHITE);grad.set_color(1,Color(1,1,1,0));grad.add_point(.2,Color(1,1,1,.3));grad.add_point(.6,Color(1,1,1,.025))
		glow_texture=GradientTexture2D.new();glow_texture.gradient=grad;glow_texture.width=256;glow_texture.height=256;glow_texture.fill=GradientTexture2D.FILL_RADIAL;glow_texture.fill_from=Vector2(.5,.5);glow_texture.fill_to=Vector2(1,.5)
	draw_texture_rect(glow_texture,Rect2(p-Vector2.ONE*r,Vector2.ONE*r*2),false,Color(col,a))
func ribbon(points,width,alpha=1.0,col=Color.TRANSPARENT):
	if col==Color.TRANSPARENT:col=accent
	if points.size()<3 or width<.3 or alpha<.005:return
	var outer=PackedVector2Array();var inner=PackedVector2Array();var colors=PackedColorArray();var other=PackedColorArray()
	for i in range(points.size()):
		var x=float(i)/(points.size()-1);var dir=(points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized().orthogonal()
		var w=width*pow(maxf(.001,sin(x*PI)),.65)
		inner.append(points[i]-dir*w*.1);outer.append(points[i]+dir*w)
		colors.append(Color(col.lightened(.27),alpha*.92));other.append(Color(col.darkened(.17),alpha*.055))
	outer.reverse();other.reverse();var shape=inner.duplicate();shape.append_array(outer);colors.append_array(other)
	if Geometry2D.triangulate_polygon(shape).is_empty():return
	draw_colored_polygon(shape,Color(col.darkened(.62),alpha*.16));draw_polygon(shape,colors)
	line(points,Color(col,alpha*.35),5.5);line(points,Color("fff6dd",alpha*.92),1.5)
func slash(p,angle,r,age,col=Color.TRANSPARENT):
	if col==Color.TRANSPARENT:col=accent
	if age<0 or age>.57:return
	var alpha=1-smooth(.13,.56,age);var reveal=smooth(-.01,.12,age)
	var pts=PackedVector2Array()
	for i in range(61):
		var a=lerpf(-2.75,1.45,float(i)/60*reveal);pts.append(p+Vector2(cos(a)*r,sin(a)*r*.43).rotated(angle))
	ribbon(pts,25,alpha,col)
	var faint=PackedVector2Array()
	for q in pts:faint.append(p+(q-p)*1.14)
	ribbon(faint,4.5,alpha*.45,col)
func flash(p,age,scale_value=1.0,col=Color.TRANSPARENT):
	if col==Color.TRANSPARENT:col=accent
	if age<0 or age>.45:return
	var a=exp(-age*15);glow(p,112*scale_value,a*.5,col)
	star(p,76*scale_value*(1-smooth(0,.22,age)),-.54,Color(col.darkened(.52),a*.65))
	star(p,68*scale_value*(1-smooth(0,.20,age)),-.54,Color("fff9e8",a))
	star(p,32*scale_value*(1-smooth(0,.14,age)),.25,Color.WHITE*a)
	ellipse(p+Vector2(0,51),15+110*(1-exp(-age*7)),4+22*(1-exp(-age*7)),Color(col.darkened(.40),(1-smooth(.05,.42,age))*.37))
func star(p,r,angle,col):
	if r<.6 or col.a<.004:return
	draw_set_transform(p)
	var pts=PackedVector2Array()
	for i in range(8):pts.append(Vector2.from_angle(angle+i*PI/4)*(r if i%2==0 else r*.095))
	if r>2:draw_colored_polygon(pts,col)
	draw_set_transform(Vector2.ZERO)
func label_at(p,text,col,alpha=1.0,size_value=19):
	if alpha<.01:return
	var w=FNT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value).x
	var q=p-Vector2(w/2,0)
	draw_string_outline(FNT,q,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value,4,Color(.14,.12,.13,alpha))
	draw_string(FNT,q,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value,Color(col,alpha))
func little_card(p,angle=0.0,scale_value=1.0,alpha=1.0,face="",death=false):
	if alpha<.004:return
	draw_set_transform(p,angle,Vector2.ONE*scale_value)
	var tex=preload("res://scripts/art_ui/back_design.gd").texture("death" if death else "back") if face=="" else preload("res://scripts/art_ui/frame_design.gd").texture("parchment",death)
	tex=preload("res://scripts/art_ui/skill_circle.gd").miniature(face,death,tex)
	draw_texture_rect(tex,Rect2(-19,-27,38,54),false,Color(1,1,1,alpha))
	draw_set_transform(Vector2.ZERO)
	if face!="":prop(face,p,26*scale_value,angle,alpha)

func react(id,age,strength=1.0,healing=false):
	if not sprites.has(id) or age<0:return
	var s=sprites[id];var kick=exp(-age*9)*(1-smooth(.35,.65,age))*strength
	var dir=(pawn(id)-source).normalized()
	s.node.pivot_offset=Vector2(s.node.size.x*.5,s.node.size.y*.86)
	s.node.position=s.position+(Vector2(0,-7*kick) if healing else dir*9*kick)
	s.node.rotation=s.rotation+(.02 if healing else .07)*kick*signf(dir.x+.01)
	s.node.scale=s.scale*Vector2(1+(.015 if healing else .045)*kick,1-(.03 if healing else .038)*kick)
	s.node.modulate=s.color.lerp(Color(1.18,1.16,.98,s.color.a),kick*.5)
func leaf(p,length,angle,col,alpha=1.0,wide=.38):
	if length<1 or alpha<.004:return
	var pts=PackedVector2Array();var vein=PackedVector2Array()
	for i in range(41):
		var x=float(i)/40;pts.append(p+Vector2(length*x,sin(x*PI)*length*wide).rotated(angle))
	for i in range(40,-1,-1):
		var x=float(i)/40;pts.append(p+Vector2(length*x,-sin(x*PI)*length*wide*.63).rotated(angle))
	draw_colored_polygon(pts,Color(col,alpha));line(pts,Color(col.darkened(.48),alpha*.7),1.6)
	line(PackedVector2Array([p,p+Vector2(length*.92,0).rotated(angle)]),Color(col.lightened(.5),alpha*.75),1.5)
func stream(a,b,reveal,width=12.0,col=Color.TRANSPARENT,alpha=1.0,bend=-50.0):
	if col==Color.TRANSPARENT:col=accent
	var points=PackedVector2Array()
	for i in range(49):points.append(bezier(a,b,clampf(reveal,0,1)*float(i)/48,bend))
	ribbon(points,width,alpha,col)
func coil(p,r,height,phase,reveal=1.0,alpha=1.0,col=Color.TRANSPARENT,turns=2.0):
	if col==Color.TRANSPARENT:col=accent
	var points=PackedVector2Array()
	for i in range(81):
		var x=float(i)/80*clampf(reveal,0,1);var a=x*TAU*turns+phase
		points.append(p+Vector2(cos(a)*r,sin(a)*r*.22-x*height))
	ribbon(points,7,alpha,col)
func prop_half(which,p,side,half,offset,angle=0.0,alpha=1.0):
	var tex=Art.texture(which)
	if tex==null or alpha<.003:return
	var sz=tex.get_size();var scale_value=side/maxf(sz.x,sz.y);var region=Rect2(0 if half==0 else sz.x*.5,0,sz.x*.5,sz.y)
	draw_set_transform(p+offset,angle)
	tex.draw_rect_region(get_canvas_item(),Rect2(Vector2(-sz.x*.5 if half==0 else 0,-sz.y*.5)*scale_value,region.size*scale_value),region,Color(1,1,1,alpha))
	draw_set_transform(Vector2.ZERO)
