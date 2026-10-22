extends RefCounted
const CN=preload("res://assets/fonts/NotoSansCJKsc-GameSubset.otf")
const B=preload("res://scripts/art_ui/back_design.gd")
const Art=preload("res://scripts/cinema/atlas.gd")
const Tint=preload("res://scripts/art_ui/heart_tint.gdshader")
static var regions={}
static var textures={}
static var time=0.0
static var measurements=[]
const INK=Color("3c291c")
const MUTED=Color("806348")
const CREAM=Color("fae9c8")
const PAWN_TEXTURES=["blue_mage","blue_shield","blue_sword","red_archer","red_axe","red_spear"]
static func texture(key):
	if regions.is_empty():regions=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art_ui/chrome/regions.json"))
	if not textures.has(key):
		# Pawns share the board's identical image instead of exporting a second copy.
		var folder="res://assets/art/" if key in PAWN_TEXTURES else "res://assets/art_ui/chrome/"
		var t=AtlasTexture.new();t.atlas=load(folder+key+".png");var r=regions[key];t.region=Rect2(r[0],r[1],r[2],r[3]);t.filter_clip=true;textures[key]=t
	return textures[key]
static func style(key="panel",margin=20,edge=22,tint=Color.WHITE):
	var s=StyleBoxTexture.new();s.texture=virtual_texture(key,edge/.16)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		s.set_texture_margin(side,edge);s.set_content_margin(side,margin);s.set_expand_margin(side,0)
	s.axis_stretch_horizontal=StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH;s.axis_stretch_vertical=StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	s.modulate_color=tint
	return s
static func virtual_texture(key,short_side):
	var id=key+"@"+str(short_side)
	if not textures.has(id):
		var src=texture(key)
		# AtlasTexture.get_image() crops via blit_rect, which cannot read a
		# compressed atlas. Decompress the source before taking the region.
		var img=src.atlas.get_image()
		if img.is_compressed():img.decompress()
		img=img.get_region(src.region)
		# Nine-slice copies used to keep the full-resolution pixels for every
		# logical border size. Match a 2x UI sampling density before uploading.
		var ratio=minf(1.0,short_side*2.0/minf(img.get_width(),img.get_height()))
		if ratio<1.0:img.resize(maxi(1,roundi(img.get_width()*ratio)),maxi(1,roundi(img.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
		var tex=ImageTexture.create_from_image(img)
		tex.set_size_override(Vector2i(src.get_size()*short_side/minf(src.get_width(),src.get_height())))
		textures[id]=tex
	return textures[id]
static func panel_style(margin=20):return style("panel",margin,20)
static func plaque(parent,rect,dark=false,edge=13):
	var visual=Plate.new();visual.key="header" if dark else "panel";visual.edge=edge;visual.position=rect.position;visual.size=rect.size;visual.mouse_filter=Control.MOUSE_FILTER_IGNORE;visual.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;parent.add_child(visual)
	return visual
class Plate extends Control:
	var key="panel"
	var edge=20.0
	func _draw():preload("res://scripts/art_ui/ui_chrome.gd").nine(self,preload("res://scripts/art_ui/ui_chrome.gd").texture(key),Rect2(Vector2.ZERO,size),edge)
static func nine(c,tex,r,edge=20.0,tint=Color.WHITE):
	var size=tex.get_size();var cut=minf(size.x,size.y)*.16
	var e=minf(edge,minf(r.size.x,r.size.y)*.45)
	var xs=[0.0,cut,size.x-cut,size.x];var ys=[0.0,cut,size.y-cut,size.y]
	var dx=[r.position.x,r.position.x+e,r.end.x-e,r.end.x];var dy=[r.position.y,r.position.y+e,r.end.y-e,r.end.y]
	for y in range(3):
		for x in range(3):
			c.draw_texture_rect_region(tex,Rect2(dx[x],dy[y],dx[x+1]-dx[x],dy[y+1]-dy[y]),Rect2(xs[x],ys[y],xs[x+1]-xs[x],ys[y+1]-ys[y]),tint)
static func text(parent,value,r,fs=18,color=INK,center=false,wrap=false):
	var n=Label.new();n.text=value;n.position=r.position;n.size=r.size;n.add_theme_font_override("font",CN);n.add_theme_font_size_override("font_size",fs);n.add_theme_color_override("font_color",color);n.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;n.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT;n.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if wrap:n.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(n)
	if not wrap and measurements.size()<1000:measurements.append({"text":value,"width":CN.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x,"zone":r.size.x})
	return n
static func sprite(parent,tex,r,modulate=Color.WHITE):
	var n=TextureRect.new();n.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;n.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;n.texture=tex;n.position=r.position;n.size=r.size;n.modulate=modulate;n.mouse_filter=Control.MOUSE_FILTER_IGNORE;n.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;parent.add_child(n);return n
static func label_backing(label):
	var p=Plate.new();p.key="panel";p.edge=7;p.size=label.size;p.position=Vector2.ZERO;p.show_behind_parent=true;p.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.add_child(p)
static func style_button(b):
	# Keep actual button behavior; its background uses the same generated copper frame.
	for state in ["normal","hover","pressed","disabled","focus"]:
		var s=style("panel",12,14);s.content_margin_top=5;s.content_margin_bottom=5
		if state=="hover":s.modulate_color=Color(1.07,1.04,.98)
		if state=="pressed":s.modulate_color=Color(.86,.80,.71)
		if state=="disabled":s.modulate_color=Color(.75,.71,.64)
		if state=="focus":
			var focus=StyleBoxFlat.new();focus.bg_color=Color.TRANSPARENT;focus.border_color=Color("bf843e");focus.set_border_width_all(2);focus.set_corner_radius_all(7);b.add_theme_stylebox_override(state,focus);continue
		b.add_theme_stylebox_override(state,s)
	b.add_theme_font_override("font",CN)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:b.add_theme_color_override(state,INK)
static func apply_theme(root):
	root.theme.default_font=CN;root.theme.default_font_size=18
	for state in ["normal","hover","pressed","disabled"]:root.theme.set_stylebox(state,"Button",panel_style(10))
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:root.theme.set_color(state,"Button",INK)
	var window_frame=style("header",8,15);window_frame.set_expand_margin(SIDE_TOP,40)
	root.theme.set_stylebox("embedded_border","Window",window_frame)
	root.theme.set_color("title_color","Window",CREAM);root.theme.set_font("title_font","Window",CN);root.theme.set_font_size("title_font_size","Window",20);root.theme.set_constant("title_height","Window",36)
	root.theme.set_color("font_placeholder_color","LineEdit",Color("957b58"));root.theme.set_color("font_color","LineEdit",INK)
	root.theme.set_color("selection_color","LineEdit",Color("baa47e"))
	for type in ["Panel","PanelContainer","AcceptDialog","PopupPanel","TooltipPanel"]:root.theme.set_stylebox("panel",type,panel_style())
	for state in ["normal","focus","read_only"]:root.theme.set_stylebox(state,"LineEdit",panel_style(14))
	for kind in ["HSlider","VSlider","HScrollBar","VScrollBar"]:
		for name in ["slider","scroll"]:root.theme.set_stylebox(name,kind,style("header",4,5))
		for name in ["grabber_area","grabber_area_highlight","grabber","grabber_highlight","grabber_pressed"]:root.theme.set_stylebox(name,kind,style("panel",2,5))
	for k in ["HSlider","VSlider"]:
		root.theme.set_icon("grabber",k,virtual_texture("medal",24))
		root.theme.set_icon("grabber_highlight",k,virtual_texture("medal",27))
static func header(board):
	var parent=board.canvas;var view=board.view;var mine=board.mine
	plaque(parent,Rect2(330,8,786,78),true,20)
	var stage=view.get("turn_stage","planning");var main=int(view.get("stage_main",-1));var event=view.get("animation",{})
	if event.get("kind","")=="phase_change":stage=event.turn_stage;main=event.main
	var title="对局结束" if view.phase=="ended" else board.Layout.PHASE_TITLES.get(stage,"出牌阶段")
	var detail="第 %d 回合"%view.round
	if stage=="resolution" and main>=0 and view.phase!="ended":detail+=" · 主优先级 %d"%main
	text(parent,title,Rect2(530,16,380,32),26,CREAM,true).set_meta("phase_title",true)
	text(parent,detail,Rect2(530,51,380,23),15,Color("cbb38b"),true).set_meta("phase_label",true)
	for team in [1-mine,mine]:
		var friendly=team==mine;var x=932 if friendly else 351
		var label=text(parent,("我方" if friendly else "敌方")+" · "+str(view.names[team]),Rect2(x,18,166,22),15,Color("a3c7dc") if friendly else Color("e7ac90"),true)
		label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;label.tooltip_text=label.text;label.mouse_filter=Control.MOUSE_FILTER_PASS
		for i in range(4):sprite(parent,texture("medal"),Rect2(x+29.5+i*28,45,23,23),Color.WHITE if i<view.badges[team] else Color(.52,.43,.32,.65))
	board._button(parent,"规则",Rect2(1157,15,75,33),func():board.ui.tooltip_dialog.popup_centered(Vector2i(840,600)))
	board._button(parent,"战况",Rect2(1241,15,75,33),board.ui._show_battle_log)
	board._button(parent,"音乐",Rect2(1330,15,83,33),func():board.ui.music_dialog.popup_centered(Vector2i(720,440)))
	board._button(parent,"退出教程" if board.ui.session.tutorial != null else "退出对战" if board.ui.session.ai_mode else "离开房间",Rect2(1184,57,174,31),func():board.ui.session.leave();board.ui.choices=[0,0,0];board.ui.notice="")
static func nameplate(board,value,r,friendly,id):
	var label=text(board.canvas,value,r,16,Color("365978") if friendly else Color("914831"),true);label.set_meta("pawn_title",id)
	label.add_theme_color_override("font_outline_color",Color("f7e8ce"));label.add_theme_constant_override("outline_size",3)
	label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
class StatusRack extends Control:
	var statuses=[]
static func health_and_status(board,c,pawn_rect,friendly):
	var health=Control.new();health.position=pawn_rect.position+Vector2(-30 if not friendly else 0,129);health.size=Vector2(185,24);health.mouse_filter=Control.MOUSE_FILTER_IGNORE;board.canvas.add_child(health)
	health.set_meta("health_actor",c.id);health.set_meta("max_hp",c.max_hp)
	if c.max_hp<=16:
		for i in range(c.max_hp):
			var step=minf(23,185.0/maxi(1,c.max_hp));var n=sprite(health,texture("heart"),Rect2(Vector2(step*i+1,0),Vector2(step-2,21)))
			n.material=ShaderMaterial.new();n.material.shader=Tint;n.material.set_shader_parameter("friendly",friendly);n.material.set_shader_parameter("filled",i<c.hp)
	else:
		plaque(health,Rect2(0,-1,175,26),false,7)
		sprite(health,texture("heart"),Rect2(6,1,23,22))
		text(health,"生命 %d / %d"%[c.hp,c.max_hp],Rect2(32,0,138,24),15,INK,true)
	var statuses=c.get("ongoing_effects",[])
	if statuses.is_empty():return
	var rack=StatusRack.new();rack.statuses=statuses.duplicate(true);rack.mouse_filter=Control.MOUSE_FILTER_IGNORE;rack.position=pawn_rect.position+Vector2(-42,8);rack.size=Vector2(35,111);rack.set_meta("status_actor",c.id);board.canvas.add_child(rack)
	var descriptions=[]
	for status in statuses:descriptions.append(board.StatusAnimation.description(status))
	for i in range(mini(3,statuses.size())):
		var aggregate=statuses.size()>3 and i==2;var s=statuses[i];var pos=Vector2(0,i*38)
		var b=Button.new();b.position=pos;b.size=Vector2(35,35);rack.add_child(b);style_button(b)
		board.bind_status_hover(b,"\n".join(descriptions) if aggregate else board.StatusAnimation.description(s),"%d/%s"%[c.id,"all" if aggregate else s.key])
		b.pressed.connect(func():board.ui.death_dialog.title=c.name+" · 持续状态";board.ui.death_dialog.dialog_text="\n".join(descriptions);board.ui.death_dialog.popup_centered(Vector2i(440,340)))
		if aggregate:text(b,"+%d"%(statuses.size()-2),Rect2(0,0,35,35),14,INK,true);continue
		var art=Art.texture(s.key)
		if art:sprite(b,art,Rect2(5,4,25,25),Color(1,1,1,.55) if s.get("dormant",false) else Color.WHITE)
		var caption="待" if s.get("waiting",false) or s.get("dormant",false) else str(s.count) if s.count>1 else ""
		if caption!="":
			plaque(b,Rect2(20,21,17,17),false,4);text(b,caption,Rect2(20,21,17,17),11,INK,true)

static func danger_button(b):
	for state in ["normal","hover","pressed","disabled"]:
		var s=style("panel",10,9);s.modulate_color=Color("f5cebd") if state=="hover" else Color("e6b5a2")
		b.add_theme_stylebox_override(state,s)
	b.add_theme_font_size_override("font_size",14)
static func selection(c,r):
	var w=c.size.x/76.0
	for p in [r.position,r.position+Vector2(r.size.x,0),r.end,r.position+Vector2(0,r.size.y)]:
		var d=Vector2(1 if p.x<r.get_center().x else -1,1 if p.y<r.get_center().y else -1)
		c.draw_polyline(PackedVector2Array([p+Vector2(0,d.y*13*w),p,p+Vector2(d.x*13*w,0)]),Color("fceec0"),3.8*w,true)
		c.draw_polyline(PackedVector2Array([p+Vector2(0,d.y*13*w),p,p+Vector2(d.x*13*w,0)]),Color("4785a1"),1.7*w,true)
	c.draw_texture_rect(texture("medal"),Rect2(Vector2(r.get_center().x-5*w,r.end.y),Vector2(10*w,10*w)),false)
static func result_panel(board):
	var view=board.view;var mine=board.mine;var p=plaque(board.canvas,Rect2(446,297,548,201),false,22)
	p.z_index=120;p.mouse_filter=Control.MOUSE_FILTER_STOP
	p.set_meta("match_result_panel",true)
	text(p,"你赢得了对局" if view.winner==mine else "平局" if view.winner<0 else "本局落败",Rect2(30,13,488,42),30,INK,true).set_meta("match_result_title",true)
	var earned=int(view.badges[mine]);p.set_meta("result_badges",earned)
	for i in range(4):sprite(p,texture("medal"),Rect2(181+i*47,61,38,38),Color.WHITE if i<earned else Color(.52,.43,.32,.5))
	text(p,("本局结果：" if view.winner<0 else "获胜方式：")+view.win_reason,Rect2(36,110,270,67),16,MUTED,false,true).set_meta("match_result_reason",true)
	var b=board._button(p,"等待对方" if view.confirmed[mine] else "再来一局",Rect2(338,127,168,48),func():board.ui.session.act("confirm"),view.confirmed[mine]);b.set_meta("rematch_button",true)
	preload("res://scripts/art_ui/confirm_skin.gd").install(b)

static func lobby_header(ui,parent):
	var holder=Control.new();holder.custom_minimum_size.y=78;parent.add_child(holder)
	plaque(holder,Rect2(176,-17,1112,78),true,20)
	sprite(holder,texture("medal"),Rect2(207,-2,46,46))
	text(holder,"牺 牲",Rect2(271,-7,195,42),30,CREAM)
	text(holder,"S A C R I F I C E",Rect2(273,32,280,18),12,Color("c8b18d"))
	text(holder,"双人对战  ·  暗选行动  ·  同时揭晓",Rect2(539,5,480,37),18,CREAM,true)
	for i in range(2):
		var callback=func():ui.tooltip_dialog.popup_centered(Vector2i(840,600))
		if i==1:callback=func():ui.music_dialog.popup_centered(Vector2i(720,440))
		var b=ui._button(holder,["规则","音乐"][i],callback);b.position=Vector2(1067+i*93,0);b.size=Vector2(79,42)

	if ui.session.active:
		var leave=ui._button(holder,"退出对战" if ui.session.ai_mode else "离开房间",func():ui.session.leave());leave.position=Vector2(12,0);leave.size=Vector2(145,42)
