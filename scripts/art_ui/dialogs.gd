extends RefCounted
const UI=preload("res://scripts/art_ui/ui_chrome.gd")
class RuleBook extends HBoxContainer:
	var sections=[]
	var buttons=[]
	var body:RichTextLabel
	func setup(source):
		custom_minimum_size=Vector2(760,460);add_theme_constant_override("separation",24)
		sections=source.sections
		var nav=VBoxContainer.new();nav.custom_minimum_size.x=196;nav.add_theme_constant_override("separation",12);add_child(nav)
		var label=Label.new();label.text="规则索引";nav.add_child(label)
		for i in range(sections.size()):
			var b=Button.new();b.text="%02d  %s" % [i+1,sections[i].title];b.custom_minimum_size=Vector2(196,52);b.set_meta("rules_tab",i);nav.add_child(b);UI.style_button(b);b.pressed.connect(show_section.bind(i));buttons.append(b)
		body=RichTextLabel.new();body.bbcode_enabled=true;body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_font_size_override("normal_font_size",18);body.add_theme_constant_override("line_separation",6);body.set_meta("rules_body",true);add_child(body)
		show_section(0)
	func format_body(value:String)->String:
		var parts=value.replace("[","[lb]").split("**")
		var result=""
		for i in range(parts.size()):
			result += ("[b]"+parts[i]+"[/b]") if i%2==1 else parts[i]
		return result
	func show_section(index):
		body.text="[font_size=26][color=#4a2e17]"+sections[index].title+"[/color][/font_size]\n\n"+format_body(sections[index].text)
		body.scroll_to_line(0)
		for i in range(buttons.size()):
			buttons[i].add_theme_stylebox_override("normal",UI.style("header" if i==index else "panel",14,12))
			buttons[i].add_theme_color_override("font_color",UI.CREAM if i==index else UI.INK)
static func nodes(n):
	var result=[n]
	for child in n.get_children():result.append_array(nodes(child))
	return result
static func install(main):
	main.get_viewport().gui_embed_subwindows=true
	for d in [main.tooltip_dialog,main.battle_dialog,main.music_dialog,main.death_dialog,main.eye_dialog,main.confirmation,main.guard_dialog]:
		if d!=main.confirmation and d!=main.guard_dialog:d.get_ok_button().text="关闭"
		UI.style_button(d.get_ok_button())
		for state in ["normal","hover","pressed"]:
			var s=UI.style("panel",34,14);s.content_margin_top=8;s.content_margin_bottom=8;d.get_ok_button().add_theme_stylebox_override(state,s)
	main.confirmation.get_ok_button().text="确定";main.confirmation.get_cancel_button().text="取消";UI.style_button(main.confirmation.get_cancel_button())
	var source=JSON.parse_string(FileAccess.get_file_as_string("res://data/game_rules.json"))
	main.tooltip_dialog.title=source.title
	var book=RuleBook.new();main.tooltip_dialog.add_child(book);book.setup(source)
	main.battle_text.bbcode_enabled=true;main.battle_text.add_theme_constant_override("line_separation",7)
	for n in nodes(main.music_dialog):
		if n is HSlider:
			n.custom_minimum_size.y=40
			var v=Label.new();n.add_child(v);v.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);v.offset_left=-70;v.offset_top=-32;v.offset_right=0;v.offset_bottom=-7;v.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;v.mouse_filter=Control.MOUSE_FILTER_IGNORE;v.text="%d%%"%roundi(n.value)
			n.value_changed.connect(func(value):v.text="%d%%"%roundi(value))
		if n is RichTextLabel:n.add_theme_font_size_override("normal_font_size",16)
static func update_log(main):
	if main.session.state.is_empty():main.battle_text.text="";return
	var lines=[]
	for entry in main.session.state.log:
		var value=str(entry).replace("[","[lb]")
		if value.begins_with("第") and value.contains("回合"):value="[font_size=23][color=#674326]"+value+"[/color][/font_size]"
		lines.append(value)
	main.battle_text.text="\n\n".join(lines)
