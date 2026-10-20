extends RefCounted
const Timing=preload("res://scripts/blade_volley_timing.gd")
const Card=preload("res://scripts/card_widget.gd")
var f
var points=[]
var faces=[]
var chest
var blood_pose
var gift_pose
func setup():
	if f.key=="gift" and f.op=="gift_transfer":
		gift_pose=preload("res://scripts/gift_pose.gd").new();gift_pose.setup(f);return
	points=f.motion_points.duplicate();faces=f.motion_faces.duplicate()
	if f.key=="collect":f.z_index=160 # The key is in front of the lock, above the chest rim.
	if f.key in ["collect","search","bloodletting"]:
		for n in f.all_nodes(f.board.canvas):
			if n.get_meta("draw_chest",false):chest=n;break
	if f.key=="bloodletting":
		blood_pose=preload("res://scripts/bloodletting_pose.gd").new();blood_pose.setup(f,chest)
	var hand_actor=int(f.event.get("hand_motion",{}).get("actor",f.actor));var friendly=hand_actor/3==f.mine
	var source=f.event.get("hand_motion",f.event.get("source_hand",{}))
	if f.op=="discard_all":points=[];faces=[]
	if not source.is_empty():
		points=[];faces=[]
		var ids=source.get("owner_cards",source.get("owner_hand",[]));var slots=source.get("owner_slots",source.get("slots",[]))
		for i in range(slots.size()):
			points.append(f.Layout.hand_position(hand_actor,int(slots[i]),friendly)+f.Layout.CARD_SIZE*f.Layout.hand_scale(friendly)*.5)
			faces.append(f.board.view.catalog.get(int(ids[i]),{}).get("key","") if friendly and i<ids.size() else "")
	if f.kind=="blade_volley" or f.op in ["convert_hand","frenzy","discard_all","gold_filter"]:
		for n in f.all_nodes(f.board.canvas):
			if n.get_meta("hand_actor",-1)==hand_actor or n.get_meta("enemy_hand_actor",-1)==hand_actor:
				for c in n.get_children():
					if not c is Card:continue
					var slot=int(c.get_meta("hand_slot",-1))
					if not source.is_empty() and slot not in source.get("owner_slots",source.get("slots",[])):continue
					if f.op=="frenzy":
						if not c.card.get("playable",true):continue
					elif not c.card.get("discardable",true):continue
					if f.op=="discard_all":
						if points.size()>=int(f.event.get("card_count",0)):continue
						points.append(f.local_center(c));faces.append(c.card.get("key","") if friendly else "")
					c.hide();f.hidden_nodes.append(c)
func update():
	if gift_pose!=null:gift_pose.update();return
	if blood_pose!=null:blood_pose.update();return
	if f.key=="collect" and is_instance_valid(chest):
		var u=progress()
		var mode=f.event.get("draw_mode","ready")
		var amount=f.smooth(.78,1.0,u)
		if mode=="blocked":amount=0.0
		elif mode!="ready":amount=f.smooth(.65,.80,u)*(1-f.smooth(.84,1,u))
		chest.present(amount)
	elif f.kind=="blade_volley":
		var tick=float(f.event.timeline_ms)+f.t*1000
		for i in range(f.event.hits.size()):f.react(f.event.hits[i].id,(tick-Timing.arrival(i))/1000.0)
	elif f.key=="bloodletting" and f.stage=="impact":f.react(f.actor,f.t,.6)
func draw():
	if gift_pose!=null:gift_pose.draw();return
	if f.kind=="blade_volley":volley();return
	if f.kind=="hand_transfer":transfer();return
	match f.key:
		"collect":unlock_chest()
		"legacy","gift":boxes()
		"gambler":dice()
		"plunder":hook()
		"gold_panning":sieve()
		"search":compass()
		"cards_to_heart","frenzy":convert_cards()
		"badge","sacrifice_badges","glory","topaz":badges()
		"obstruct","boulder","poisoning":place_token()
		"bloodletting":bloodletting()
		"heart":heart()
		"greed":greed()
		"emerald":emerald()
		_:boxes()
func progress():return f.u if f.stage=="travel" else 1.0
func alpha():return f.smooth(0,.10,f.u) if f.stage=="travel" else 1-f.smooth(.10,.88,f.u)
func lifted():return f.source+Vector2(0,-32*f.spring(minf(1,progress()/.35)))
func unlock_chest():
	var u=progress()
	if f.stage!="travel":return
	var fly=f.smooth(.09,.43,u);var turn=f.smooth(.53,.76,u)
	var side=lerpf(84,59,fly)
	var tip=Vector2(.44,.39)
	var angle=(PI-tip.angle())*fly
	# Approach the right-facing lock from the cloth, then roll about the shaft.
	var lock=f.Layout.DECK_LOCK
	var inserted=lock-tip.rotated(angle)*side
	var approach=inserted+Vector2(7,0)*(1-f.smooth(.43,.52,u))
	var p=f.bezier(f.source,approach,fly,-56)
	var a=f.smooth(0,.09,u)*(1-f.smooth(.80,.91,u))
	var tex=f.Art.texture("collect");var proportions=tex.get_size()/maxf(tex.get_width(),tex.get_height())
	var axis=tip.normalized();var normal=Vector2(-axis.y,axis.x)
	var points=PackedVector2Array();var uv=PackedVector2Array()
	for q in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
		var offset=(q-Vector2(.5,.5))*proportions-tip
		var rolled=axis*offset.dot(axis)+normal*offset.dot(normal)*cos(turn*1.28)
		points.append(p+(tip+rolled).rotated(angle)*side);uv.append((tex.region.position+q*tex.region.size)/tex.atlas.get_size())
	if a>.002:f.draw_polygon(points,PackedColorArray([Color(1,1,1,a)]),uv,tex.atlas)
func boxes():
	var u=progress();var a=alpha();var p=lifted();var isgift=f.key=="gift"
	var open=f.smooth(.24,.40,u);var closed="gift_closed" if isgift else "legacy" if f.key=="legacy" else "chest_closed"
	var opened="gift" if isgift else "legacy_open" if f.key=="legacy" else "chest_open"
	f.shadow(p+Vector2(0,49),46,a*.15)
	f.prop(closed,p,125,0,a*(1-open),Vector2(1+.12*sin(u*PI),1-.10*sin(u*PI)))
	f.prop(opened,p,125,-.04*sin(u*14),a*open,Vector2(1,1+.045*sin(u*12)))
	f.glow(p+Vector2(0,-18),86,a*open*.25)
	var count=int(f.event.get("placed_count",f.event.get("card_count",3)))
	count=clampi(count,0,5)
	var mode=f.event.get("draw_mode",f.event.get("reward_mode","ready"))
	if mode in ["blocked","empty"]:
		f.label_at(p+Vector2(0,78),"无法摸牌" if mode=="blocked" else "牌堆已空",Color("f3d3ab"),a,19);return
	if isgift:
		for i in range(count):
			var v=f.smooth(.08+i*.05,.35+i*.05,u);var start=f.hand(f.actor)+Vector2(i*27,0)
			if u<.45:f.little_card(f.bezier(start,p,v,-55),(i-.5)*.13,1.05,a*(1-f.smooth(.26,.43,u)))
	else:
		for i in range(count):
			var v=f.smooth(.34+i*.055,.72+i*.04,u);var q=p+Vector2((i-(count-1)*.5)*33,-27-47*v)
			f.little_card(q,(i-(count-1)*.5)*.18,1.1,a*v)
		for target in f.targets:
			if u>.64:f.stream(p+Vector2(0,-52),target+Vector2(0,68),f.smooth(.64,1,u),12,f.accent,a*.6,-75)
func dice():
	var u=progress();var a=alpha();var p=lifted()+Vector2(82*f.smooth(.1,.62,u),-absf(sin(u*PI*3))*46*(1-u))
	f.shadow(p+Vector2(0,44+absf(sin(u*PI*3))*46*(1-u)),36,a*.19)
	f.prop("gambler",p,107,(1-f.smooth(.18,.76,u))*TAU*1.6,a,Vector2(1+.10*sin(u*PI*6),1-.10*sin(u*PI*6)))
	for i in range(points.size()):
		var v=f.smooth(.20+i*.06,.78+i*.04,u)
		var q=f.bezier(points[i],p+Vector2(0,15),v,-65)
		f.little_card(q,lerpf(0,(i-1)*.42,v),1.8*(1-.85*v),a*(1-f.smooth(.7,1,v)),faces[i])
	if f.stage=="impact":f.ellipse(p+Vector2(0,39),45+u*20,10,Color(f.accent,a*.55))
func hook():
	var u=progress();var a=alpha();var target=f.hand(f.target_ids[0]);var out=f.smooth(.15,.50,u);var back=f.smooth(.57,.94,u)
	var p=f.bezier(f.source,target,out,-60).lerp(f.source+Vector2(0,-38),back)
	var pts=PackedVector2Array()
	for i in range(49):
		var v=float(i)/48;pts.append(f.source.lerp(p,v)+Vector2(0,sin(v*PI)*(36*(1-back))))
	f.line(pts,Color("543325",a),6);f.line(pts,Color("c6a573",a),2.6)
	f.prop("plunder",p,91,-.6+out*.8-back*.7,a)
	if u>.48:f.flash(target,(u-.48)*2,.42)
func sieve():
	var u=progress();var a=alpha();var center=lifted()+Vector2(0,-5)
	var shake=sin(u*45)*4*f.smooth(.25,.4,u)*(1-f.smooth(.8,1,u))
	f.prop("gold_panning",center+Vector2(shake,0),145,shake*.012,a)
	if f.op=="gold_filter":
		for i in range(points.size()):
			var v=f.smooth(.12+i*.04,.85+i*.03,u);var q=f.bezier(points[i],f.DISCARD,v,-45)
			f.little_card(q,-.3*sin(v*PI),1.7,a,faces[i])
		if points.is_empty():f.star(center+Vector2(0,-34),15,0,Color("fff4cc",a))
	else:
		# Prepare the sieve; the following receipt owns the five real cards.
		f.ellipse(center+Vector2(0,20),48,15,Color(f.accent,a*.35))
func compass():
	var pose=preload("res://scripts/search_compass_pose.gd")
	if f.op=="search_depart":pose.depart(f)
	else:pose.fly(f)
func convert_cards():
	var u=progress();var a=alpha();var center=f.hand(f.actor)+Vector2(0,-104)
	f.prop("frenzy" if f.key=="frenzy" else "heart",center,100,0,a*f.smooth(.25,.6,u),Vector2.ONE*(1+.07*sin(u*18)))
	for i in range(points.size()):
		var v=f.smooth(.08+i*.045,.73+i*.055,u);var angle=(i-(points.size()-1)*.5)*.43
		var end=center+Vector2(sin(angle)*87,cos(angle)*34) if f.key=="frenzy" else center+Vector2.from_angle(i*TAU/maxi(1,points.size()))*27
		var q=f.bezier(points[i],end,v,-36)
		f.little_card(q,angle*v,lerpf(1.85,.9,v),a*(1-f.smooth(.75,1,u)) if f.key!="frenzy" else a,faces[i])
		if f.key=="cards_to_heart" and v>.5:f.leaf(q,30*(v-.5)*2,angle-PI/2,Color("eb9b9f"),a)
	if f.key=="frenzy":
		for i in range(2):f.coil(center+Vector2(0,29),68,42,u*4+i*PI,1,a*.4,Color("ed9e74"),.6)
func badges():
	var u=progress();var a=alpha();var count=clampi(int(f.event.get("card_count",1)),1,4)
	if f.key=="topaz":f.prop("topaz",lifted(),99,0,a)
	if f.key=="sacrifice_badges":f.prop("rally",lifted(),115,-.6+u*.8,a*(1-f.smooth(.45,.8,u)),Vector2(1,1-.2*u))
	for i in range(count):
		var v=f.smooth(.20+i*.12,.90+i*.05,u);var start=lifted()+Vector2((i-(count-1)*.5)*37,-12)
		var q=f.bezier(start,f.crest(),v,-64)
		f.stream(start,q,1,7,Color("e1b354"),a*.45,-40)
		f.prop("badge",q,lerpf(82,35,v),sin(v*PI)*.23,a,Vector2(.70+.30*absf(cos(v*TAU)),1))
	if f.stage=="impact":f.ellipse(f.crest(),54,23,Color(f.accent,a*.4))
func place_token():
	if f.op=="immovable":
		var u=progress();var a=alpha();var center=f.hand(f.target_ids[0]);var strain=sin(u*PI*5)*f.smooth(.1,.3,u)*(1-f.smooth(.70,.85,u))
		f.shadow(center+Vector2(0,36),48,a*.2)
		f.prop("boulder",center+Vector2(strain*5,-absf(strain)*7),101,strain*.055,a)
		for h in [-1,1]:f.line(PackedVector2Array([center+Vector2(h*46,-38),center+Vector2(h*52,0),center+Vector2(h*46,37)]),Color("ad9770",a*.8),3.5)
		f.label_at(center+Vector2(0,62),"不可打出或弃置",Color("e7d5b1"),a,19)
		return
	# Prepare the same props that the authoritative receipt carries to real slots.
	# Keeping them by the source avoids a decorative flight followed by a second deal.
	var u=progress();var a=f.smooth(0,.18,u) if f.stage=="travel" else 1.0
	var count=int(f.event.get("placed_count",2));var which="poison" if f.key=="poisoning" else "boulder"
	for i in range(count):
		var v=f.smooth(.12+i*.09,.65+i*.07,u) if f.stage=="travel" else 1.0
		var q=f.source+Vector2((i-(count-1)*.5)*53,-35*v)
		f.shadow(q+Vector2(0,37),29,a*.16)
		f.prop(which,q,lerpf(30,70,v),(1-v)*.22,a,Vector2(1+.08*sin(v*PI),1-.08*sin(v*PI)))
func bloodletting():
	blood_pose.draw()
func heart():
	var u=progress();var a=alpha();var dest=f.targets[0]+Vector2(43,-35);var p=f.bezier(lifted(),dest,f.smooth(.2,.85,u),-55)
	f.prop("heart",p,79,0,a,Vector2.ONE*(1+.10*pow(maxf(0,sin(u*TAU*3)),2)))
	f.coil(p+Vector2(0,30),34,51,u*4,1,a*.55,Color("ef9caa"),1)
func greed():
	if f.op!="activate" and f.board.view.characters[f.target_ids[0]].get("statuses",[]).has("greed"):return
	var u=progress();var a=alpha();var p=lifted()
	f.prop("greed",p,122,0,a,Vector2(1+.13*sin(u*PI),1-.06*sin(u*PI)))
	for i in range(3):f.little_card(p+Vector2((i-1)*22,-22-33*f.smooth(.2,.6,u)),(i-1)*.23,.75,a*f.smooth(.2,.6,u))
	for target in f.targets:
		var dest=target+Vector2(42,-34);var v=f.smooth(.43,.93,u)
		f.stream(p,dest,v,11,Color("e4bd75"),a*.6,-55)
		f.prop("greed",f.bezier(p,dest,v,-55),45,0,a*v)
func emerald():
	var u=progress();var a=alpha();var p=lifted()
	f.prop("emerald",p,112,u*.15,a,Vector2(1+.1*sin(u*PI),1))
	for i in range(4):
		var angle=PI/4+i*PI/2;var v=f.smooth(.25+i*.055,.8+i*.04,u);var q=p+Vector2.from_angle(angle)*(24+62*v)
		f.little_card(q,angle+PI/2,.95,a*v)
		f.stream(p,q,1,8,Color("74c4a0"),a*.5,0)
func transfer():
	var u=progress();var a=alpha();var recipient=int(f.event.get("recipient",f.target_ids[0]));var end=f.landing(recipient);var v=f.smooth(.17,.92,u)
	var p=f.bezier(f.source,end,v,-62)
	f.prop(f.key,p,lerpf(87,55,v),sin(v*PI)*.24,a,Vector2(.92+.08*cos(v*TAU),1))
	if f.key in ["holy_amulet","attack_amulet","magic_amulet"]:
		for h in [-1,1]:f.stream(f.source+Vector2(h*12,0),p+Vector2(h*12,0),1,8,f.accent,a*.45,-32)
	else:f.stream(f.source,p,1,13,f.accent,a*.6,-40)
func volley():
	var tick=float(f.event.timeline_ms)+minf(f.t*1000,float(f.event.slice_ms))
	var count=f.event.destinations.size()
	for i in range(count):
		var start=points[i] if i<points.size() else f.hand(f.actor)+Vector2(i*33,0)
		var end=f.pawn(f.event.destinations[i]);var age=tick-i*Timing.STEP_MS
		var morph=f.smooth(0,Timing.MORPH_MS,age);var v=clampf((age-Timing.MORPH_MS)/Timing.FLIGHT_MS,0,1)
		if age<Timing.MORPH_MS:f.little_card(start+Vector2(0,-24*morph),-.16*morph,1.8,1-morph,faces[i] if i<faces.size() else "")
		if age>=0 and age<Timing.MORPH_MS+Timing.FLIGHT_MS:
			var p=f.bezier(start+Vector2(0,-24),end,pow(v,1.65),-56)
			f.stream(start+Vector2(0,-24),p,1,12,Color("df8495"),morph*.7,-36)
			f.prop("triple_strike",p,91,(end-start).angle()+PI/2,morph)
		var hit_age=(tick-Timing.arrival(i))/1000.0
		if hit_age>=0 and hit_age<.70:
			f.slash(end,-.6 if i%2==0 else .8,83,hit_age,Color("df8495"));f.flash(end,hit_age,.85,Color("df8495"))
			if i<f.event.hits.size():f.label_at(end+Vector2(58,-40),"-"+str(f.event.hits[i].amount),Color("ffeed5"),1-f.smooth(.25,.65,hit_age),23)

