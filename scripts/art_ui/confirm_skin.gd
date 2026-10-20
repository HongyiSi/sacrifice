extends Control
const B=preload("res://scripts/art_ui/back_design.gd")
const P=preload("res://scripts/art_ui/priority_style.gd")
const CN=preload("res://assets/fonts/NotoSansCJKsc-GameSubset.otf")
const Shine=preload("res://scripts/art_ui/button_shine.gdshader")
static var time=0.0
var target:Button
var caption="确认出牌"
var forced=-1
var hover_amount=0.0
var pressed_amount=0.0
var locked_amount=0.0
var plate:TextureRect
var font:FontVariation
static func install(button):
	var skin=load("res://scripts/art_ui/confirm_skin.gd").new();skin.target=button;skin.caption=button.text
	for state in ["font_color","font_hover_color","font_pressed_color","font_disabled_color","font_focus_color","font_hover_pressed_color"]:button.add_theme_color_override(state,Color.TRANSPARENT)
	for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.add_child(skin);skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);skin.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return skin
func _ready():
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	font=FontVariation.new();font.base_font=CN;font.variation_embolden=.45
	plate=TextureRect.new();plate.texture=B.texture("button");plate.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;plate.stretch_mode=TextureRect.STRETCH_SCALE;plate.show_behind_parent=true;plate.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(plate)
	plate.material=ShaderMaterial.new();plate.material.shader=Shine
	var origin=plate.texture.region.position/plate.texture.atlas.get_size();var extent=plate.texture.region.size/plate.texture.atlas.get_size()
	plate.material.set_shader_parameter("atlas_rect",Vector4(origin.x,origin.y,extent.x,extent.y))
func _process(dt):advance(dt)
func advance(dt):
	time=Time.get_ticks_msec()/1000.0;caption=target.text
	var hot=forced==1 or forced==2 if forced>=0 else target.is_hovered() or target.has_focus()
	var down=forced==2 if forced>=0 else target.is_pressed()
	var locked=forced==3 if forced>=0 else caption=="取消确认" or target.disabled
	hover_amount=move_toward(hover_amount,1.0 if hot else 0.0,dt*5.0)
	pressed_amount=move_toward(pressed_amount,1.0 if down else 0.0,dt*15.0)
	locked_amount=move_toward(locked_amount,1.0 if locked else 0.0,dt*6.0)
	var s=size.x/152.0;var shrink=pressed_amount*.012
	plate.position=Vector2(size.x*shrink*.5,size.y*shrink*.5+pressed_amount*1.65*s)
	plate.size=size*(1-shrink)
	plate.material.set_shader_parameter("hover",hover_amount);plate.material.set_shader_parameter("press",pressed_amount);plate.material.set_shader_parameter("locked",locked_amount);plate.material.set_shader_parameter("clock",time)
	queue_redraw()
func _draw():
	if not is_instance_valid(plate):return
	var s=size.x/152.0
	var r=Rect2(Vector2.ZERO,size).grow(-1.8*s);var edge=P.outline(r,9*s)
	if hover_amount>0:
		for i in range(4,0,-1):draw_polyline(edge,Color("e6b765",hover_amount*.024*(1-pressed_amount*.7)),s*(2+i*1.5),true)
	var pixels=roundi(17*s)
	var width=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x
	var baseline=size.y*.5+(font.get_ascent(pixels)-font.get_descent(pixels))*.5+pressed_amount*1.65*s
	var ink=Color("554430") if locked_amount>.5 else Color("382719")
	draw_string(font,Vector2((size.x-width)*.5,baseline),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,ink)
