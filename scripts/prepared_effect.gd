extends Control
const Art=preload("res://scripts/cinema/atlas.gd")
const Layout=preload("res://scripts/board_layout.gd")
const Card=preload("res://scripts/card_widget.gd")
const Bag=preload("res://scripts/prepared_backpack.gd")
const Timing=preload("res://scripts/prepared_timing.gd")
var board
var event={}
var context={}
var actor=0
var mine=0
var mode=""
var bag
var source
var origin=Vector2.ZERO
var dock=Vector2.ZERO
var chest_dock=Vector2(235,377)
var chest
var elapsed=0.0
var clock_started=-1
var age=0.
var incoming=[]
var outgoing=[]
var nodes=[]
var positions={}
var order=[]
var pile_count=0
var before_count=0
var rejected=false
var speech
func walk(n):
	var out=[]
	for c in n.get_children():out.append(c);out.append_array(walk(c))
	return out
func center(n):return board.canvas.get_global_transform().affine_inverse()*(n.get_global_transform()*(n.size*.5))
func initialize(table,waiting=false):
	board=table;mine=board.mine;event=board.view.animation;context=board.view.get("prepared_backpack",{})
	actor=int(context.get("actor",event.get("action",{}).get("actor",0)))
	mode="wait" if waiting else "draw" if event.get("prepared_draw",false) else event.get("op","").trim_prefix("prepared_")
	z_index=6 if waiting else 90;mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if not waiting:
		var stamp="%d/%d/%s"%[board.view.match,event.id,event.stage]
		if board.ui.effect_key!=stamp:board.ui.effect_key=stamp;board.ui.effect_started=Time.get_ticks_msec()
		clock_started=board.ui.effect_started
	set_meta("prepared_effect",mode)
	for n in walk(board.canvas):
		if n.get_meta("played_action_id",-999)==context.get("action_id",event.get("action",{}).get("id",-998)) and n is Card:source=n
		if n.has_meta("draw_chest"):chest=n;pile_count=n.count
		if n.get_meta("hand_actor",n.get_meta("enemy_hand_actor",-1))==actor:
			for c in n.get_children():
				if c is Card:nodes.append(c);positions[c]=c.position
	if source==null:source=board._active_widget()
	origin=Layout.pawn_center(actor,actor/3==mine)+Vector2(65,-20)
	if source!=null:origin=board.canvas.get_global_transform().affine_inverse()*(source.get_global_transform()*source.emblem_center())
	dock=Timing.hand_dock(actor,mine)
	bag=Bag.new();add_child(bag)
	if mode=="draw":setup_draw()
	if mode=="pack" and event.stage=="travel":
		var motion=event.hand_motion
		var slots=motion.get("owner_slots",motion.slots) if actor/3==mine or board.view.omniscient else motion.slots
		for i in range(slots.size()):
			var n=nodes[slots[i]] if slots[i]>=0 and slots[i]<nodes.size() else null
			if n!=null:outgoing.append(flight(n))
	present(maxf(0,(Time.get_ticks_msec()-clock_started)/1000.) if clock_started>=0 else 0.)
func setup_draw():
	var ids=[];var accepted=0
	for d in event.draws:
		if d.target!=actor:continue
		if accepted==0:before_count=d.before_count
		rejected=rejected or d.returned.has(true)
		for i in range(d.count):
			if d.returned[i]:continue
			accepted+=1
			if d.has("ids"):ids.append(d.ids[i])
	pile_count=event.pile_before
	if actor/3==mine or board.view.omniscient:
		for n in nodes:
			if not ids.has(n.card.get("id",-1)):order.append(n)
		for id in ids:
			for n in nodes:
				if n.card.get("id",-1)==id:order.append(n);incoming.append(flight(n))
	else:
		order=nodes.duplicate()
		for n in nodes.slice(before_count,before_count+accepted):incoming.append(flight(n))
	if rejected:
		speech=preload("res://scripts/pawn_speech.gd").new();add_child(speech)
		speech.configure(actor,"我的手牌满了！",Layout.pawn_rect(actor,actor/3==mine),Color("355f89") if actor/3==mine else Color("a95138"),1.9)
		speech.set_process(false)
func flight(original):
	var n=Card.new();n.card=original.card.duplicate(true);n.hidden_card=original.hidden_card
	n.size=Layout.CARD_SIZE;n.pivot_offset=n.size*.5;n.mouse_filter=Control.MOUSE_FILTER_IGNORE;n.disabled=true
	add_child(n);n.set_process(false);n.hide()
	return {"node":n,"original":original,"from":center(original)}
func smooth(a,b,x):return smoothstep(a,b,x)
func arc(a,b,u,bend):return a.lerp(b,u)+Vector2(0,-bend*sin(u*PI))
func pose(n,p,s,angle=0.,alpha=1.,front=true):
	n.visible=alpha>.001;n.position=p-n.pivot_offset;n.scale=Vector2.ONE*s;n.rotation=angle;n.modulate=Color(1,1,1,alpha);n.z_index=15 if front else 3;n.queue_redraw()
func present(seconds):
	elapsed=seconds
	var local=seconds
	if mode!="wait" and event.stage=="impact":local=float(event.travel_ms)/1000.
	var offsets={"depart":0.,"draw":2.,"arrive":3.60,"pack":8.72,"finish":10.42}
	age=local+offsets.get(mode,0.)
	if mode=="wait":age=2. if context.get("stage","")=="chest" else 7.0
	var t=age;var fly=smooth(.6,1.55,t);var carry=smooth(3.95,4.75,t)
	var p=arc(origin,chest_dock,fly,68)
	if t>=3.95:p=arc(chest_dock,dock,carry,58)
	var angle=-.12*sin(fly*PI)+.085*sin(carry*PI)
	if t>4.75:angle=sin((t-4.75)*1.8)*.009*(1-smooth(8.5,8.7,t))
	var opening=smooth(1.55,1.95,t)*(1-smooth(3.60,3.95,t))+smooth(4.80,5.11,t)*(1-smooth(10.42,10.78,t))
	bag.present(p,opening,1-smooth(10.94,11.55,t),angle,lerpf(62,150,fly)*(1-.14*smooth(10.95,11.55,t)))
	bag.visible=t>=.6
	if is_instance_valid(source):source.motif_alpha=1-smooth(.59,.63,t);source.queue_redraw()
	if is_instance_valid(chest) and (mode!="wait" or context.get("stage","")=="chest"):
		chest.present(smooth(1.60,2.,t)*(1-smooth(3.22,3.63,t)))
		if mode=="draw":
			var taken=0
			for i in range(incoming.size()):
				if t>=2.05+i*.50:taken+=1
			chest.set_count(pile_count-taken)
	if mode=="draw":draw_cards(t)
	if mode=="pack":pack_cards(t)
	if is_instance_valid(speech):speech.present(local-3.10)
	queue_redraw()
func draw_cards(t):
	var friendly=actor/3==mine;var final_scale=Layout.hand_scale(friendly)
	for i in range(order.size()):
		var n=order[i];n.show();n.position=Layout.hand_slot(i,friendly).lerp(positions[n],smooth(6.62,6.97,t))
	for i in range(incoming.size()):
		var f=incoming[i];var n=f.node;var out_start=5.15+i*.43;var out_end=out_start+1.04
		f.original.visible=t>=out_end;n.hide();var a=t-(2.05+i*.50);var mouth=bag.mouth()
		if a>=0 and a<1.03 and t<3.7:
			n.hidden_card=true
			if a<.64:
				var u=smooth(0,.64,a);pose(n,arc(Vector2(100,368),mouth+Vector2(0,-55),u,39),lerpf(.45,.56,u),-.25*sin(u*PI),smooth(0,.09,a))
			else:pose(n,(mouth+Vector2(0,-55)).lerp(mouth+Vector2(0,49),smooth(.64,1.03,a)),.56,0,1,false)
		elif t>=out_start and t<out_end:
			var u=t-out_start;var target=center(f.original)
			if u<.36:pose(n,(mouth+Vector2(0,48)).lerp(mouth+Vector2(0,-60),smooth(0,.36,u)),.56,0,1,false)
			else:
				var k=smooth(.36,1.04,u);pose(n,arc(mouth+Vector2(0,-60),target,k,31),lerpf(.56,final_scale,k),.13*sin(k*PI))
			n.hidden_card=n.card.is_empty() or u<.48
			if not n.card.is_empty():n.scale.x*=maxf(.035,absf(cos(PI*smooth(.40,.56,u))))
			n.queue_redraw()
func pack_cards(t):
	for i in range(outgoing.size()):
		var f=outgoing[i];var n=f.node;n.hide();var a=t-(8.72+i*.48)
		f.original.visible=a<0
		if a>=0 and a<1.1:
			var mouth=bag.mouth()
			if a<.73:
				var u=smooth(0,.73,a);pose(n,arc(f.from,mouth+Vector2(0,-60),u,30),lerpf(Layout.hand_scale(actor/3==mine),.56,u),-.12*sin(u*PI))
			else:pose(n,(mouth+Vector2(0,-60)).lerp(mouth+Vector2(0,49),smooth(.73,1.10,a)),.56,0,1,false)
func _draw():
	var q=smooth(10.90,11.58,age);var a=sin(q*PI)*.24
	if a<.001:return
	for i in range(14):
		var ang=i*2.39996;var r=18+31*q+7*sin(i*3.7)
		draw_circle(dock+Vector2(cos(ang)*r,sin(ang)*r*.7-25*q),1.1,Color(1,.86,.59,a*(.65+.35*sin(i))))
func _process(_delta):
	present(maxf(0,(Time.get_ticks_msec()-clock_started)/1000.) if clock_started>=0 else elapsed)
func _exit_tree():
	if is_instance_valid(source):source.motif_alpha=1;source.queue_redraw()
	for n in nodes:
		if is_instance_valid(n):n.show();n.position=positions[n]
	if is_instance_valid(chest):chest.present(0);chest.set_count(board.view.deck_count)
