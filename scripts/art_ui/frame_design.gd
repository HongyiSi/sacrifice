extends RefCounted
const Priority=preload("res://scripts/art_ui/priority_style.gd")
const Art=preload("res://scripts/cinema/atlas.gd")
const NUM=preload("res://assets/fonts/Nunito-Variable.ttf")
const CN=preload("res://assets/fonts/NotoSansCJKsc-GameSubset.otf")
static var style="parchment"
static var regions={}
static var textures={}
static var bold_num:FontVariation
static var bold_cn:FontVariation
static var measurements=[]
static func init():
	if regions.is_empty():regions=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art_ui/cards/regions.json"))
	if bold_num==null:
		bold_num=FontVariation.new();bold_num.base_font=NUM;bold_num.variation_opentype={2003265652:740.0};bold_num.variation_embolden=.1
		bold_cn=FontVariation.new();bold_cn.base_font=CN;bold_cn.variation_embolden=.32
static func texture(key,death):
	init();var id=key+str(death)
	if not textures.has(id):
		var t=AtlasTexture.new();t.atlas=load("res://assets/art_ui/cards/"+key+".png")
		var r=regions[key]["death" if death else "normal"];t.region=Rect2(r[0],r[1],r[2],r[3]);t.filter_clip=true;textures[id]=t
	return textures[id]
static func layout(key):
	if key=="parchment":return {"main":Rect2(.116,.074,.336,.083),"secondary":Rect2(.60,.074,.272,.083),"art":Rect2(.14,.235,.72,.535),"name":Rect2(.16,.827,.68,.103)}
	if key=="enamel":return {"main":Rect2(.125,.143,.327,.092),"secondary":Rect2(.57,.143,.316,.092),"art":Rect2(.155,.295,.69,.485),"name":Rect2(.14,.846,.72,.086)}
	return {"main":Rect2(.118,.13,.168,.172),"secondary":Rect2(.118,.44,.168,.172),"art":Rect2(.385,.125,.464,.611),"name":Rect2(.16,.817,.69,.076)}
static func scaled(r,body):return Rect2(body.position+r.position*body.size,r.size*body.size)
static func text(c,font,value,r,fs,ink,record=false):
	var px=maxi(7,roundi(fs));var length=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x
	while length>r.size.x and px>6:px-=1;length=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x
	var baseline=r.position.y+r.size.y*.5+(font.get_ascent(px)-font.get_descent(px))*.5
	# Font line metrics include unused ascent. Keep the visible glyph optical centre stable.
	var at=Vector2(r.get_center().x-length*.5,baseline)
	c.draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,ink)
	if record and measurements.size()<1000:measurements.append({"text":value,"font_size":px,"width":length,"zone_width":r.size.x,"style":style,"inside_horizontal":length<=r.size.x+.01})
static func icon(c,key,r,alpha=1.0):
	var tex=Art.texture(key)
	if tex==null:return
	if key in ["double_strike","triple_strike","area_strike","precise_strike","cards_to_blades","sacrifice_badges","death_sentence","obstruct"]:
		Art.draw_card(c,key,r,alpha);return
	if key in preload("res://scripts/strike_timing.gd").SINGLE_CARD:
		var angle=preload("res://scripts/strike_timing.gd").CARD_ANGLE
		var d=tex.get_size()
		var bounds=Vector2(absf(cos(angle))*d.x+absf(sin(angle))*d.y,absf(sin(angle))*d.x+absf(cos(angle))*d.y)
		var scaled=d*minf(r.size.x/bounds.x,r.size.y/bounds.y)
		c.draw_set_transform(r.get_center(),angle)
		c.draw_texture_rect(tex,Rect2(-scaled*.5,scaled),false,Color(1,1,1,alpha))
		c.draw_set_transform(Vector2.ZERO)
		return
	var d=tex.get_size();var ratio=minf(r.size.x/d.x,r.size.y/d.y)
	var s=d*ratio
	c.draw_texture_rect(tex,Rect2(r.get_center()-s*.5,s),false,Color(1,1,1,alpha))
static func draw_card(c,info,death=false,hidden=false,selected=false,bonus=0):
	init()
	var w=c.size.x;var h=c.size.y;var scale_value=w/76.0
	var body=Rect2(scale_value,0,w-scale_value*2,h-scale_value*4)
	Priority.install_frame(c,texture(style,death),body,info,death,hidden)
	var zones=layout(style)
	var dark=death or style in ["enamel","grimoire"]
	var num_ink=Color("fff0cc") if dark else Color("392619")
	var main=str(int(info.get("priority",0))+bonus) if death else str(int(info.get("main",0))+bonus)
	var secondary="—" if death or int(info.get("main",0))<0 else str(int(info.get("secondary",info.get("ranks",[1])[0]))+bonus)
	if not death and int(info.get("main",0))<0:main="—"
	var primary=scaled(zones.main,body);var second=scaled(zones.secondary,body)
	if style=="grimoire":
		var f=6.7*scale_value
		text(c,CN,"主",Rect2(primary.position+Vector2(0,-2*scale_value),Vector2(primary.size.x,7*scale_value)),f,Color("d9c4a0"))
		text(c,CN,"次",Rect2(second.position+Vector2(0,-2*scale_value),Vector2(second.size.x,7*scale_value)),f,Color("d9c4a0"))
		primary.position.y+=6*scale_value;primary.size.y-=6*scale_value;second.position.y+=6*scale_value;second.size.y-=6*scale_value
	text(c,bold_num,main,primary,(13 if style=="parchment" else 15)*scale_value,num_ink,true)
	text(c,bold_num,secondary,second,(12 if style=="parchment" else 14)*scale_value,num_ink,true)
	var name_ink=Color("fff0d4") if death else Color("352419")
	text(c,bold_cn,str(info.get("name","")),scaled(zones.name,body),11.3*scale_value,name_ink,true)
	icon(c,str(info.get("key","strike")),scaled(zones.art,body),c.get("motif_alpha") if c.get("motif_alpha")!=null else 1.0)
	if selected:preload("res://scripts/art_ui/ui_chrome.gd").selection(c,body)
