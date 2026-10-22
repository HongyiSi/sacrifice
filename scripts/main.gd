extends Control

const Rules = preload("res://scripts/rules.gd")
const TableUI = preload("res://scripts/table_ui.gd")
const Music = preload("res://scripts/music.gd")
const AttackAudio = preload("res://scripts/attack_audio.gd")
const INK := Color("3e332c")
const MUTED := Color("806c53")
const TEAL := Color("355f89")
const EMBER := Color("a95138")
const GOLD := Color("927039")
const PANEL := Color("f1e3c8")
const EDGE := Color("ac8c5c")
@onready var session = $Session
var page: Control
var board: RefCounted
var table_scrolls: Dictionary = {}
var battle_dialog: AcceptDialog
var battle_text: RichTextLabel
var choices: Array = [0, 0, 0]
var selection_round := ""
var nickname: LineEdit
var address: LineEdit
var room_port: SpinBox
var saved_name := ""
var saved_code := ""
var room_code_input: LineEdit
var local_lobby := false
var online_url := ""
var guard_targets: Dictionary = {}
var guard_dialog: AcceptDialog
var saved_address := "127.0.0.1"
var saved_port := 24771
var notice := ""
var render_pending := false
var submitting := false
var tooltip_dialog: AcceptDialog
var death_dialog: AcceptDialog
var confirmation: ConfirmationDialog
var pending_target := -1
var preview := false
var inspected_card := 0
var hand_focus: Dictionary = {}
var hand_lift: Dictionary = {}
var planning_motions: Dictionary = {}
var effect_key := ""
var effect_started := 0
var music: Node
var attack_audio: Node
var reverse_tablecloth: Control
var music_dialog: AcceptDialog
var pick_cards: Array = []
var pick_revision := -1
var picker_collapsed := false
var picker_query := ""
var card_hover_state: Dictionary = {}
var card_pointer := Vector2.INF
var card_hover_blocked := false
var phase_title_value := ""
var phase_detail_value := ""
var phase_title_changed := false
var phase_detail_changed := false
var phase_banner_key := ""
var phase_banner_started := 0
var reveal_states: Dictionary = {}
var reveal_times: Dictionary = {}
var resolution_times: Dictionary = {}
var resolution_focus: Dictionary = {}
var resolution_returns: Dictionary = {}
var eye_dialog: AcceptDialog
var eye_text: RichTextLabel

func _ready() -> void:
	_setup_theme()
	guard_dialog = AcceptDialog.new()
	guard_dialog.title = "指定护符保护的棋子"
	guard_dialog.get_ok_button().hide()
	add_child(guard_dialog)
	resized.connect(_schedule_render)
	_load_preferences()
	if OS.has_feature("web"):
		saved_code = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('room') || window.sacrificeLastRoom?.() || ''",true)).to_upper()
	music = Music.new()
	add_child(music)
	attack_audio = AttackAudio.new()
	add_child(attack_audio)
	music_dialog = AcceptDialog.new()
	music_dialog.title = "声音设置与鸣谢"
	var music_column := VBoxContainer.new()
	music_column.custom_minimum_size = Vector2(660,330)
	music_column.add_theme_constant_override("separation",12)
	music_dialog.add_child(music_column)
	_label(music_column,"背景音乐音量",20)
	var music_slider := HSlider.new()
	music_slider.min_value = 0; music_slider.max_value = 100; music_slider.step = 1
	music_slider.value = music.level*100
	music_slider.value_changed.connect(func(value): music.set_level(value/100.0))
	music_column.add_child(music_slider)
	_label(music_column,"卡牌音效音量",20)
	var sound_slider := HSlider.new()
	sound_slider.min_value = 0; sound_slider.max_value = 100; sound_slider.step = 1
	sound_slider.value = attack_audio.level*100
	sound_slider.set_meta("sound_volume",true)
	sound_slider.value_changed.connect(func(value): attack_audio.set_level(value/100.0))
	music_column.add_child(sound_slider)
	_label(music_column,"大厅：The Old Tower Inn — RandomMind\n对局：Woodland Fantasy — Matthew Pablo",18,MUTED)
	var credits := RichTextLabel.new()
	credits.custom_minimum_size = Vector2(630,150)
	credits.bbcode_enabled = true
	credits.text = "Woodland Fantasy © Matthew Pablo\n[url=https://www.matthewpablo.com]www.matthewpablo.com[/url]\n[url=https://creativecommons.org/licenses/by/3.0/]Creative Commons Attribution 3.0[/url]\n[url=https://opengameart.org/content/woodland-fantasy]对局音乐来源[/url] · 播放最初选用的原曲，整场对局循环播放。\n[url=https://opengameart.org/content/medieval-the-old-tower-inn]大厅音乐来源[/url] · [url=https://creativecommons.org/publicdomain/zero/1.0/]CC0[/url]，使用作者提供的循环版。"
	credits.meta_clicked.connect(func(url): OS.shell_open(str(url)))
	credits.text += "\n攻击音效：[url=https://mixkit.co/free-sound-effects/sword/]Mixkit 金属撞击[/url]、[url=https://mixkit.co/free-sound-effects/fire/]火焰素材[/url]（[url=https://mixkit.co/license/modal/sfxFree/]Sound Effects Free License[/url]）；辅助拟音：[url=https://opengameart.org/content/fantasy-sound-effects-tinysized-sfx]Jan Schupke / Vehicle · Tinysized SFX[/url]（CC0）。"
	credits.text += "\n回血音效：[url=https://mixkit.co/free-sound-effects/magic/]Mixkit · Light spell（E）[/url]（Sound Effects Free License）；防御展开与格挡：Tinysized SFX 金属拟音（CC0）。"
	music_column.add_child(credits)
	add_child(music_dialog)
	session.changed.connect(_on_state)
	var diagnostics := preload("res://scripts/client_diagnostics.gd").new()
	diagnostics.session = session; add_child(diagnostics)
	session.problem.connect(func(message): notice = message; submitting = false; _schedule_render())
	tooltip_dialog = AcceptDialog.new()
	tooltip_dialog.title = "游戏规则"
	add_child(tooltip_dialog)
	death_dialog = AcceptDialog.new()
	death_dialog.title = "亡语牌"
	death_dialog.dialog_autowrap = true
	add_child(death_dialog)
	eye_dialog = AcceptDialog.new()
	eye_dialog.title = "天眼 · 查看所有卡牌"
	eye_text = RichTextLabel.new()
	eye_text.custom_minimum_size = Vector2(780,460)
	eye_text.add_theme_font_size_override("normal_font_size",18)
	eye_dialog.add_child(eye_text)
	add_child(eye_dialog)
	battle_dialog = AcceptDialog.new()
	battle_dialog.title = "战况记录"
	var battle_column := VBoxContainer.new()
	battle_column.custom_minimum_size = Vector2(760,460)
	battle_text = RichTextLabel.new()
	battle_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_text.scroll_following = true
	battle_column.add_child(battle_text)
	_button(battle_column,"导出战况记录",_export_log)
	battle_dialog.add_child(battle_column)
	add_child(battle_dialog)
	confirmation = ConfirmationDialog.new()
	confirmation.title = "确认友方目标"
	confirmation.confirmed.connect(func():
		if pending_target >= 0:
			_send_target(pending_target)
		pending_target = -1)
	add_child(confirmation)
	preload("res://scripts/art_ui/dialogs.gd").install(self)
	var capture_path := ""
	var auto_host := false
	var auto_join := ""
	for arg in OS.get_cmdline_user_args():
		if arg == "--host": auto_host = true
		if arg.begins_with("--join="): auto_join = arg.trim_prefix("--join=")
		if arg.begins_with("--port="): saved_port = int(arg.trim_prefix("--port="))
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		if arg == "--preview": preview = true
	if preview:
		var example = Rules.new()
		example.start(42)
		session.team = 0
		session.state = example.snapshot(0)
		session.state.names = ["玩家一", "玩家二"]
	elif auto_host:
		session.host_room("玩家一", saved_port)
	elif not auto_join.is_empty():
		session.join_room("玩家二", auto_join, saved_port)
	_render()
	if not preview and not auto_host and auto_join.is_empty(): _resume_saved_match.call_deferred()
	if not capture_path.is_empty():
		_capture.call_deferred(capture_path)

func _capture(path: String) -> void:
	for _i in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE ", path, " result=", error)
	get_tree().quit(0 if error == OK else 1)

func _setup_theme() -> void:
	var ui := Theme.new()
	var font = load("res://assets/fonts/NotoSansCJKsc-GameSubset.otf")
	ui.default_font = font
	ui.default_font_size = 18
	ui.set_color("font_color", "Label", INK)
	ui.set_color("font_color", "Button", INK)
	ui.set_color("font_hover_color", "Button", TEAL)
	ui.set_color("font_disabled_color", "Button", Color("8b7c68"))
	ui.set_stylebox("normal", "Button", _box(Color("ead9b8"), EDGE, 8, 10))
	ui.set_stylebox("hover", "Button", _box(Color("f7edda"), TEAL, 8, 10))
	ui.set_stylebox("pressed", "Button", _box(Color("d7c6a3"), TEAL, 8, 10))
	ui.set_stylebox("disabled", "Button", _box(Color("deceb2"), Color("bdab8c"), 8, 10))
	ui.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), GOLD, 8, 0))
	ui.set_stylebox("normal", "LineEdit", _box(Color("fff2da"), EDGE, 8, 14))
	ui.set_stylebox("focus", "LineEdit", _box(Color("fff2da"), TEAL, 8, 14))
	ui.set_color("caret_color", "LineEdit", INK)
	ui.set_color("default_color", "RichTextLabel", INK)
	ui.set_stylebox("panel", "AcceptDialog", _box(PANEL, EDGE, 10, 18))
	ui.set_stylebox("panel", "PopupPanel", _box(PANEL, EDGE, 8, 14))
	ui.set_stylebox("panel", "TooltipPanel", _box(PANEL, EDGE, 8, 14))
	ui.set_color("font_color", "TooltipLabel", INK)
	ui.set_stylebox("scroll", "HScrollBar", _box(Color("ddceb1"),Color(0,0,0,0),4,3))
	ui.set_stylebox("grabber", "HScrollBar", _box(Color("ab9168"),Color(0,0,0,0),4,3))
	ui.set_stylebox("grabber_highlight", "HScrollBar", _box(Color("866a45"),Color(0,0,0,0),4,3))
	ui.set_color("font_color", "LineEdit", INK)
	ui.set_color("font_placeholder_color", "LineEdit", MUTED)
	ui.set_constant("separation", "VBoxContainer", 10)
	ui.set_constant("separation", "HBoxContainer", 12)
	theme = ui
	preload("res://scripts/art_ui/ui_chrome.gd").apply_theme(self)

func _box(fill: Color, border: Color = EDGE, radius: int = 12, margin: int = 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style

func _draw() -> void:
	var background := TableUI.texture("table")
	if background: draw_texture_rect(background,Rect2(Vector2.ZERO,size),false)
	else: draw_rect(Rect2(Vector2.ZERO,size),PANEL)

func _show_battle_log() -> void:
	if session.state.is_empty(): return
	preload("res://scripts/art_ui/dialogs.gd").update_log(self)
	battle_dialog.popup_centered(Vector2i(820,560))

func _on_state() -> void:
	if session.online_mode and not session.room_code.is_empty():
		saved_code = session.room_code
	_sync_web_status()
	if guard_dialog != null: guard_dialog.hide()
	submitting = false
	if not session.state.is_empty():
		if battle_dialog.visible: preload("res://scripts/art_ui/dialogs.gd").update_log(self)
		if pick_revision != session.state.revision:
			pick_cards = []
			picker_collapsed = false
			picker_query = ""
			pick_revision = session.state.revision
		if eye_dialog.visible:
			if session.state.get("omniscient",false): _update_eye_text()
			else:
				eye_dialog.hide()
				eye_text.text = ""
		var key := "%s:%s:%s" % [session.team,session.state.match, session.state.round]
		if selection_round != key:
			if selection_round.get_slice(":",1) != key.get_slice(":",1) or selection_round.get_slice(":",0) != key.get_slice(":",0):
				hand_focus.clear()
				card_hover_state.clear()
				card_hover_blocked = false
			picker_query = ""
			planning_motions.clear()
			selection_round = key
			reveal_states.clear()
			reveal_times.clear()
			resolution_times.clear()
			resolution_focus.clear()
			resolution_returns.clear()
			table_scrolls.clear()
			choices = [0, 0, 0]
			var restored: Dictionary = session.ai_local_plan
			if session.ai_mode and restored.get("match",-1)==session.state.match and restored.get("round",-1)==session.state.round:
				choices = restored.get("choices",[0,0,0]).duplicate(true)
			guard_targets.clear()
			inspected_card = 0
			notice = ""
		if session.state.ready[session.team]:
			choices = session.state.my_plan.duplicate(true)
			for item in choices:
				if item is Dictionary: guard_targets.merge(item.get("guards",{}),true)
		if session.state.phase != "planning": planning_motions.clear()
	elif eye_dialog != null:
		hand_focus.clear()
		card_hover_state.clear()
		card_hover_blocked = false
		picker_query = ""
		planning_motions.clear()
		selection_round = ""
		phase_banner_key = ""
		phase_title_value = ""
		phase_detail_value = ""
		reveal_states.clear()
		reveal_times.clear()
		resolution_focus.clear()
		resolution_returns.clear()
		choices = [0,0,0]
		pick_cards.clear()
		table_scrolls.clear()
		eye_dialog.hide()
		eye_text.text = ""
		battle_dialog.hide()
		battle_text.text = ""
		death_dialog.hide()
	if confirmation != null and confirmation.visible:
		confirmation.hide()
		pending_target = -1
	_schedule_render()

func _schedule_render() -> void:
	if not render_pending:
		render_pending = true
		_render.call_deferred()

func _render() -> void:
	render_pending = false
	hand_lift.clear()
	music.sync_view(session.state,session.team)
	if is_instance_valid(page):
		remove_child(page)
		page.queue_free()
	page = Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	if session.state.is_empty():
		var lobby_canvas=Control.new();lobby_canvas.size=Vector2(1440,960);lobby_canvas.scale=size/Vector2(1440,960);page.add_child(lobby_canvas)
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_" + side,28)
		lobby_canvas.add_child(margin)
		var outer := VBoxContainer.new()
		outer.add_theme_constant_override("separation",18)
		margin.add_child(outer)
		_header(outer)
		_lobby(outer)
	else:
		if session.tutorial != null: session.tutorial.remember(session.game,choices)
		board = TableUI.new(self)
		board.build(page)
		if session.tutorial != null: preload("res://scripts/tutorial_ui.gd").build(board)
		if session.peer_missing or session.reconnecting:
			board.canvas.process_mode = Node.PROCESS_MODE_DISABLED
			_disconnected_overlay()
	if session.peer_missing or session.reconnecting: attack_audio.reset()
	else: attack_audio.sync_view(session.state,effect_started)
	if not is_instance_valid(reverse_tablecloth):
		reverse_tablecloth = preload("res://scripts/reverse_tablecloth.gd").new()
		add_child(reverse_tablecloth)
		move_child(reverse_tablecloth,0)
	reverse_tablecloth.sync_view(session.state,effect_started)
	queue_redraw()

func _disconnected_overlay() -> void:
	var cover := CenterContainer.new()
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.z_index = 2000
	cover.set_meta("room_waiting",true)
	page.add_child(cover)
	var column := _panel(cover,PANEL,EDGE,24)
	column.get_parent().custom_minimum_size.x = 480
	_label(column,"正在自动重连" if session.reconnecting else "对方已离线",26,TEAL).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(column,"房间号：" + session.room_code,22).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paragraph(column,session.status+"\n连接恢复后自动回到原对局。" if session.reconnecting else "对局已暂停。等待对方重新连接。\n双方都离开后，房间才会关闭。",17)
	var buttons := HBoxContainer.new(); column.add_child(buttons)
	_button(buttons,"复制房间号",func(): _copy_invitation(false)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(buttons,"离开房间",func(): session.leave()).size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _label(parent: Node, text_value: String, font_size: int = 18, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _paragraph(parent: Node, text_value: String, font_size: int = 18, color: Color = MUTED) -> Label:
	var label := _label(parent, text_value, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(parent: Node, text_value: String, callback: Callable, disabled: bool = false, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 44
	button.disabled = disabled
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		button.add_theme_stylebox_override("normal", _box(TEAL, Color("284965"), 8, 10))
		button.add_theme_stylebox_override("pressed", _box(Color("274864"), GOLD, 8, 10))
		button.add_theme_stylebox_override("hover", _box(Color("4879a0"), GOLD, 8, 10))
		button.add_theme_color_override("font_color", Color("fff1d6"))
		button.add_theme_color_override("font_hover_color", Color("fff1d6"))
		button.add_theme_color_override("font_pressed_color", Color("fff1d6"))
	button.pressed.connect(callback)
	parent.add_child(button)
	preload("res://scripts/art_ui/ui_chrome.gd").style_button(button)
	return button

func _panel(parent: Node, fill: Color = PANEL, border: Color = EDGE, margin: int = 18) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",preload("res://scripts/art_ui/ui_chrome.gd").panel_style(margin))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	return column

func _spacer(parent: Node) -> Control:
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(space)
	return space

func _header(parent: Node) -> void:
	preload("res://scripts/art_ui/ui_chrome.gd").lobby_header(self,parent)

func _lobby(parent: VBoxContainer) -> void:
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(center)
	var columns := HBoxContainer.new()
	columns.custom_minimum_size = Vector2(1130, 550)
	columns.add_theme_constant_override("separation", 24)
	center.add_child(columns)
	var intro := _panel(columns, Color("eaddbf"), EDGE, 32)
	intro.get_parent().custom_minimum_size.x = 570
	_label(intro, "一人统领三枚棋子，胜负系于每次出牌。", 16, TEAL)
	_label(intro, "谁先出手\n谁能活到最后", 40)
	_paragraph(intro, "暗选你的行动，同时揭晓。\n在对手出手之前，击倒关键棋子。", 22, MUTED)
	var portraits := HBoxContainer.new()
	portraits.alignment = BoxContainer.ALIGNMENT_CENTER
	intro.add_child(portraits)
	for figure in ["blue_sword","blue_shield","blue_mage"]:
		var portrait := TextureRect.new()
		portrait.texture = TableUI.texture(figure)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		portrait.custom_minimum_size = Vector2(125,136)
		portraits.add_child(portrait)
	var metrics := HBoxContainer.new()
	intro.add_child(metrics)
	for metric in [["2", "玩家"], ["3", "每方棋子"], [str(Rules.MAX_HP), "初始生命"]]:
		var metric_column := VBoxContainer.new()
		metric_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		metrics.add_child(metric_column)
		_label(metric_column, metric[0], 36, GOLD)
		_label(metric_column, metric[1], 16, MUTED)
	var flex := Control.new()
	flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	intro.add_child(flex)
	_paragraph(intro, "组合普通牌与亡语，寻找你的制胜策略。\n死后化为幽灵，借不死重返战场，或以神化掌控摸牌。", 16)
	var form := _panel(columns, PANEL, EDGE, 28)
	form.get_parent().custom_minimum_size.x = 535
	if not local_lobby or session.online_mode:
		_online_lobby(form)
		_label(parent, "每人控制三个棋子  /  房间号邀请好友  /  双方加入后自动开始", 15, Color("e9d2a9")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return
	_label(form, "本地对战", 28)
	if session.active:
		_paragraph(form, session.status, 20, TEAL)
		_label(form, "端口  %d" % session.port, 20)
		if session.hosting:
			_paragraph(form, "同一台电脑：在另一个窗口加入 127.0.0.1。\n局域网：对方输入本机的局域网地址。", 17)
			var ips: Array = []
			for ip in IP.get_local_addresses():
				if ":" not in ip and not ip.begins_with("127.") and not ip.begins_with("169.254."):
					ips.append(ip)
			_paragraph(form, "本机地址：" + (" / ".join(ips) if not ips.is_empty() else "127.0.0.1"), 16, GOLD)
			_button(form, "打开第二个游戏窗口", _open_second)
		_button(form, "取消", func(): session.leave())
	else:
		_label(form, "昵称", 16, MUTED)
		nickname = LineEdit.new()
		nickname.placeholder_text = "输入昵称（可留空）"
		nickname.text = saved_name
		nickname.max_length = 16
		form.add_child(nickname)
		_label(form, "房主地址 / 本机使用 127.0.0.1", 16, MUTED)
		address = LineEdit.new()
		address.text = saved_address
		form.add_child(address)
		var port_row := HBoxContainer.new()
		form.add_child(port_row)
		_label(port_row, "房间端口", 16, MUTED)
		room_port = SpinBox.new()
		room_port.min_value = 1024
		room_port.max_value = 65535
		room_port.value = saved_port
		room_port.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		port_row.add_child(room_port)
		var buttons := HBoxContainer.new()
		form.add_child(buttons)
		_button(buttons, "创建房间", _host, false, true).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button(buttons, "加入房间", _join).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button(form, "本机双开测试", func():
			_save_preferences()
			if session.host_room(saved_name, saved_port) == OK:
				_open_second())
		_paragraph(form, "双开测试会打开两个游戏窗口，你可以切换窗口，分别操作双方。", 16)
		if not session.status.is_empty():
			_paragraph(form, session.status, 16, EMBER)
	if not session.active: _button(form, "返回线上对战", func(): local_lobby=false; _schedule_render())
	if not session.active: _button(form,"新手教程",_start_tutorial).set_meta("tutorial_start",true)
	if not notice.is_empty():
		_paragraph(form, notice, 16, EMBER)
	_label(parent, "每个棋子拥有独立手牌与亡语  /  可以攻击友方  /  亡语结束后判定全灭", 15, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _choose_target(id: int, displayed_revision: int = -1) -> void:
	if submitting or session.state.is_empty() or (displayed_revision >= 0 and displayed_revision != session.state.revision):
		return
	if session.state.phase not in ["targeting", "death_targeting"] or not session.state.input.options.has(id): return
	if session.tutorial != null and not session.tutorial.allows("target",[id]):
		session.act("target",[id])
		return
	var c: Dictionary = session.state.characters[id]
	var card: Dictionary = session.state.active_card
	if c.team == session.team and card.key not in ["resurrection","raise_dead","heal_other","heart","blessing","privilege","greed","defense","gift","sapphire","ruby","amethyst"]:
		pending_target = id
		confirmation.dialog_text = "将「我方 · %s」指定为%s的目标？\n当前生命：%d / %d。\n%s" % [c.name, card.name, c.hp, c.max_hp, card.text]
		confirmation.get_label().add_theme_color_override("font_color",TableUI.BLUE)
		confirmation.popup_centered(Vector2i(540, 200))
	else:
		_send_target(id)

func _selected_cards(actor: int) -> Array:
	var value = choices[actor % 3]
	if value is Dictionary: return value.get("cards",[]).duplicate()
	if value is Array: return value.duplicate()
	return [] if value == 0 else [value]

func _inspect_hand(actor: int, card: int) -> void:
	if session.state.is_empty(): return
	if session.state.phase == "targeting" and session.state.input.team == session.team and session.state.active_card.get("key","") == "gift":
		hand_focus.clear()
		notice = "馈赠第1步：先点击金色边框的接收棋子，再选两张牌。"
		_schedule_render()
		return
	var c: Dictionary = session.state.characters[actor]
	if not c.hand.has(card): return
	if c.team != session.team and not session.state.omniscient: return
	if hand_focus.get("actor",-1) == actor and hand_focus.get("card",0) == card:
		_close_hand()
		return
	else:
		hand_focus = {"actor":actor,"card":card,"saved_info":session.state.catalog[card].duplicate(true)}
		inspected_card = card
	_schedule_render()

func _inspect_visible(source: Control, actor: int) -> void:
	var key: String = source.get_meta("inspect_key","")
	if hand_focus.get("source_key","missing") == key:
		_close_hand()
		return
	hand_focus = {"actor":actor,"card":int(source.card.id),"source_key":key,"readonly":true,"saved_info":source.card.duplicate(true),"bonus":source.priority_bonus}
	_schedule_render()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not event.position.is_equal_approx(card_pointer):
		card_pointer = event.position
		card_hover_blocked = false
		if board != null and is_instance_valid(board.canvas): board.refresh_card_hover.call_deferred()
	var pressed_at := Vector2.INF
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed_at = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pressed_at = event.position
	if not pressed_at.is_finite(): return
	card_pointer = pressed_at
	card_hover_blocked = false
	if hand_focus.is_empty() and card_hover_state.is_empty(): return
	for key in ["card","details","controls"]:
		var region = hand_lift.get(key)
		if key == "controls" and is_instance_valid(region) and region.get_child_count() == 0: continue
		if is_instance_valid(region) and region.get_global_rect().has_point(pressed_at): return
	# Hit-test the actual press, including touch. The hovered widget can still
	# describe a previous pointer position when _input runs before GUI dispatch.
	if board != null and is_instance_valid(board.canvas) and _hint_control_at(board.canvas,pressed_at): return
	card_hover_blocked = true
	if board != null: board.clear_card_hover()
	if not hand_focus.is_empty(): _close_hand()

func _hint_control_at(node: Node, point: Vector2) -> bool:
	if node is Control:
		if not node.is_visible_in_tree(): return false
		if node.get_global_rect().has_point(point) and (node is BaseButton or node is ScrollContainer or node is LineEdit or node is Range or node.has_meta("status_description") or node.has_meta("card_description")):
			return true
	for child in node.get_children():
		if _hint_control_at(child,point): return true
	return false

func _can_edit_plan(actor: int) -> bool:
	if submitting or session.state.is_empty() or session.state.phase != "planning": return false
	if actor < 0 or actor >= session.state.characters.size(): return false
	var c: Dictionary = session.state.characters[actor]
	return c.team == session.team and c.hp > 0 and c.play_limit > 0 and not session.state.ready[session.team]

func _close_hand() -> void:
	if hand_lift.is_empty() or not is_instance_valid(hand_lift.get("card")):
		hand_focus.clear()
		_schedule_render()
		return
	var lifted: Dictionary = hand_lift
	if lifted.get("closing",false): return
	lifted.closing = true
	if is_instance_valid(lifted.tween): lifted.tween.kill()
	var card: Control = lifted.card
	card.disabled = true
	var back := card.create_tween().set_parallel(true)
	back.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	back.tween_property(card,"position",lifted.origin,0.2)
	back.tween_property(card,"scale",lifted.scale,0.2)
	back.tween_property(lifted.details,"modulate:a",0.0,0.1)
	back.tween_property(lifted.controls,"modulate:a",0.0,0.1)
	back.chain().tween_callback(func(): hand_focus.clear(); _schedule_render())

func _play_hand(actor: int, card: int, displayed_revision: int) -> void:
	if not _can_edit_plan(actor) or session.state.revision != displayed_revision: return
	var c: Dictionary = session.state.characters[actor]
	if not c.hand.has(card) or not session.state.catalog[card].get("playable",true): return
	_toggle_plan(actor,card)

func _click_hand(actor: int, card: int, displayed_revision: int) -> void:
	if session.state.is_empty() or session.state.revision != displayed_revision: return
	if session.state.phase == "planning": _play_hand(actor,card,displayed_revision)
	# Outside planning, hand clicks have no action. Hover remains available;
	# effect-specific pickers have their own selection callbacks.

func _set_local_plan(actor: int, selected: Array) -> void:
	var previous := _selected_cards(actor)
	if selected == previous: return
	if session.tutorial != null and not session.tutorial.accept_local_plan(actor,selected):
		_schedule_render()
		return
	card_hover_blocked = true
	if board != null: board.clear_card_hover()
	# Capture the current visible position, including an interrupted flight.
	var positions: Dictionary = board.plan_positions(actor) if board != null and is_instance_valid(board.canvas) else {}
	for id in planning_motions.keys():
		if planning_motions[id].actor == actor: planning_motions.erase(id)
	var now := Time.get_ticks_msec()
	attack_audio.plan_changed(actor,previous,selected,now)
	for id in positions:
		planning_motions[id] = {"actor":actor,"from":positions[id],"started":now}
	choices[actor%3] = selected.duplicate()
	session.remember_ai_plan(choices)
	hand_focus.clear()
	_schedule_render()

func _plan_payload() -> Array:
	var result: Array = []
	for slot in range(3): result.append(_selected_cards(session.team*3+slot).duplicate())
	return result

func _return_planned(actor: int, card: int, displayed_revision: int) -> void:
	if not _can_edit_plan(actor) or session.state.revision != displayed_revision: return
	var selected := _selected_cards(actor)
	selected.erase(card)
	_set_local_plan(actor,selected)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not hand_focus.is_empty():
		_close_hand()
		get_viewport().set_input_as_handled()

func _toggle_plan(actor: int, card: int) -> void:
	var limit: int = session.state.characters[actor].play_limit
	var selected := _selected_cards(actor)
	if selected.has(card): selected.erase(card)
	else:
		if selected.size() >= limit: selected.pop_back()
		selected.append(card)
	_set_local_plan(actor,selected)

func _send_pick(values: Array, displayed_revision: int) -> void:
	if submitting or session.state.is_empty() or session.state.revision != displayed_revision: return
	submitting = true
	session.act("pick",values)
	_schedule_render()

func _update_eye_text() -> void:
	var s: Dictionary = session.state
	var lines: Array = ["天眼只提供查看，不会使暗牌实际翻开。\n"]
	for c in s.characters:
		lines.append(c.name + "：")
		for id in c.hand: lines.append("  手牌 · %s [%d/%d]" % [s.catalog[id].name,s.catalog[id].main,s.catalog[id].secondary])
		for id in c.deathrattles: lines.append("  亡语 · %s [%d]" % [s.death_catalog[id].name,s.death_catalog[id].priority])
	if not s.seen_plans.is_empty():
		lines.append("\n已提交的出牌：")
		for t in range(2):
			if s.seen_plans[t] == null: continue
			for slot in range(3):
				var value = s.seen_plans[t][slot]
				var ids: Array = value if value is Array else ([] if value == 0 else [value])
				for id in ids: lines.append("  %s · %s" % [s.characters[t*3+slot].name,s.catalog[id].name])
	lines.append("\n普通抽牌堆（列表末尾为牌顶）：")
	for id in s.deck_view: lines.append("  %s [%d/%d]" % [s.catalog[id].name,s.catalog[id].main,s.catalog[id].secondary])
	lines.append("\n普通弃牌堆：")
	for id in s.discard_view: lines.append("  %s [%d/%d]" % [s.catalog[id].name,s.catalog[id].main,s.catalog[id].secondary])
	lines.append("\n本回合已打出的牌：")
	for a in s.queue:
		if a.card != 0: lines.append("  %s · %s [%d/%d] %s" % [s.characters[a.actor].name,s.catalog[a.card].name,a.main,a.secondary,"已翻开" if a.revealed else "未翻开"])
	lines.append("\n未分配的亡语牌：")
	for id in s.death_deck_view: lines.append("  %s [%d]" % [s.death_catalog[id].name,s.death_catalog[id].priority])
	lines.append("\n亡语弃牌堆：")
	for id in s.death_discard: lines.append("  %s [%d]" % [s.death_catalog[id].name,s.death_catalog[id].priority])
	eye_text.text = "\n".join(lines)

func _show_eye() -> void:
	if not session.state.get("omniscient",false): return
	_update_eye_text()
	eye_dialog.popup_centered(Vector2i(850,590))

func _send_target(id: int) -> void:
	if notice.begins_with("馈赠第1步："): notice = ""
	submitting = true
	session.act("target", [id])
	_schedule_render()

func _skip_effect(displayed_revision: int) -> void:
	if session.state.is_empty() or session.state.revision != displayed_revision or submitting: return
	submitting = true
	confirmation.hide()
	pending_target = -1
	session.act("skip_effect")
	_schedule_render()

func _end_round_early(displayed_revision: int) -> void:
	if session.state.is_empty() or session.state.revision != displayed_revision or submitting or not session.state.get("can_end_round_early",false): return
	submitting = true
	confirmation.hide()
	pending_target = -1
	if board != null: board.clear_card_hover()
	session.act("end_round_early")
	_schedule_render()

func _reselect_targets(displayed_revision: int) -> void:
	if session.state.is_empty() or session.state.revision != displayed_revision or submitting: return
	submitting = true
	pending_target = -1
	session.act("reselect_targets")
	_schedule_render()

func _send_choice(kind: String, value: int, displayed_revision: int) -> void:
	if session.state.is_empty() or session.state.revision != displayed_revision or submitting: return
	submitting = true
	session.act(kind, [value])
	_schedule_render()

func _host() -> void:
	_save_preferences()
	session.host_room(saved_name, saved_port)

func _join() -> void:
	_save_preferences()
	if saved_address.strip_edges().is_empty():
		notice = "请输入房主地址。"
		_schedule_render()
		return
	session.join_room(saved_name, saved_address, saved_port)

func _open_second() -> int:
	var args := PackedStringArray()
	if OS.has_feature("editor"):
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--log-file", ProjectSettings.globalize_path(_data_dir().path_join("guest-%d.log" % Time.get_ticks_msec())), "--", "--join=127.0.0.1", "--port=%d" % session.port])
	var pid := OS.create_instance(args)
	if pid == -1:
		notice = "未能自动打开窗口，请再次运行游戏并选择加入房间。"
		_schedule_render()
	return pid

func _data_dir() -> String:
	var folder := "res://local-data" if OS.has_feature("editor") else "user://"
	DirAccess.make_dir_recursive_absolute(folder)
	return folder

func _load_preferences() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_data_dir().path_join("preferences.cfg")) == OK:
		saved_name = str(cfg.get_value("room", "name", ""))
		saved_address = str(cfg.get_value("room", "address", "127.0.0.1"))
		saved_port = clampi(int(cfg.get_value("room", "port", 24771)), 1024, 65535)

func _save_preferences() -> void:
	if is_instance_valid(nickname): saved_name = nickname.text
	if is_instance_valid(address): saved_address = address.text.strip_edges()
	if is_instance_valid(room_port): saved_port = int(room_port.value)
	var cfg := ConfigFile.new()
	cfg.set_value("room", "name", saved_name)
	cfg.set_value("room", "address", saved_address)
	cfg.set_value("room", "port", saved_port)
	var error := cfg.save(_data_dir().path_join("preferences.cfg"))
	if error != OK:
		notice = "昵称和地址未能保存，本次仍可继续游戏。"

func _export_log() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.sacrificeDownloadLog("+JSON.stringify("牺牲 Sacrifice · 对局记录\n"+"\n".join(session.state.log))+")",true)
		return
	var folder := _data_dir().path_join("battle_logs")
	DirAccess.make_dir_recursive_absolute(folder)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := folder.path_join("sacrifice-" + stamp + ".txt")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		notice = "记录保存失败，请检查磁盘空间。"
	else:
		file.store_string("牺牲 Sacrifice · 对局记录\n" + "\n".join(session.state.log))
		file.close()
		notice = "记录已保存。"
		OS.shell_open(ProjectSettings.globalize_path(folder))
	_schedule_render()

func _online_lobby(form: VBoxContainer) -> void:
	_label(form,"线上对战",28)
	if session.active:
		_paragraph(form,session.status,20,TEAL)
		if not session.room_code.is_empty():
			_label(form,session.room_code,42,GOLD).set_meta("online_room_code",true)
			_paragraph(form,"把房间号或邀请链接发给好友。\n两人到齐后自动开始对局。",17)
			_button(form,"复制房间号",func(): _copy_invitation(false))
			_button(form,"复制邀请链接",func(): _copy_invitation(true))
		_button(form,"取消",func(): session.leave())
	else:
		_label(form,"昵称",16,MUTED)
		nickname = LineEdit.new(); nickname.text = saved_name; nickname.max_length = 16
		nickname.placeholder_text = "输入昵称（可留空）"; nickname.custom_minimum_size.y = 44
		nickname.set_meta("online_name",true); form.add_child(nickname)
		nickname.text_changed.connect(func(value): saved_name=value)
		_label(form,"房间号 · 加入好友时填写",16,MUTED)
		room_code_input = LineEdit.new(); room_code_input.text = saved_code; room_code_input.max_length = 6
		room_code_input.placeholder_text = "6 位房间号"; room_code_input.custom_minimum_size.y = 44
		room_code_input.set_meta("online_code",true); form.add_child(room_code_input)
		room_code_input.text_changed.connect(func(value): saved_code=value.to_upper())
		var buttons := HBoxContainer.new(); form.add_child(buttons)
		_button(buttons,"创建房间",func(): _connect_online(true),false,true).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button(buttons,"加入房间",func(): _connect_online(false)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button(form,"本地 AI 对战",func(): _save_preferences(); notice=""; session.start_ai(saved_name)).set_meta("local_ai_start",true)
		_button(form,"新手教程",_start_tutorial).set_meta("tutorial_start",true)
		_button(form,"自学习 AI 对战（实验）",func(): _save_preferences(); notice=""; session.start_ai(saved_name,0,true)).set_meta("learning_ai_start",true)
		var resume_hint := "用同一浏览器重新打开" if OS.has_feature("web") else "在本机重新打开游戏"
		_paragraph(form,"AI 对局意外中断后，30 分钟内%s即可继续。\n房间号仅用于好友对战。" % resume_hint,16)
		if not OS.has_feature("web"):
			_button(form,"本机 / 局域网测试",func(): local_lobby=true; _schedule_render())
		if not session.status.is_empty(): _paragraph(form,session.status,16,EMBER)
	if not notice.is_empty(): _paragraph(form,notice,16,EMBER)

func _start_tutorial() -> void:
	_save_preferences()
	notice = ""
	session.start_tutorial(saved_name)

func _tutorial_previous() -> void:
	if session.tutorial == null or session.tutorial.history.size() < 2: return
	var restored: Array = session.tutorial.previous(session.game)
	# Rebuild presentation clocks and selection state for the restored page.
	# No old flight, hover, or animation can keep driving the rewound position.
	if board != null: board.clear_card_hover()
	hand_focus.clear(); card_hover_state.clear(); planning_motions.clear()
	selection_round = ""; effect_key = ""; phase_banner_key = ""
	attack_audio.reset()
	session.animation_key = ""
	session._broadcast()
	choices = restored
	_schedule_render()

func _connect_online(create: bool) -> void:
	_save_preferences()
	if not create and not session.Online.Rooms.valid_code(saved_code):
		notice = "请输入有效的 6 位房间号。"; _schedule_render(); return
	notice = ""; session.connect_online(saved_name,create,saved_code,online_url)

func _copy_invitation(link: bool) -> void:
	var content: String = session.room_code
	if link:
		var base := "https://sacrifice.shytomato.top/"
		if OS.has_feature("web"): base = str(JavaScriptBridge.eval("location.origin + location.pathname",true))
		content = base+"?room="+session.room_code
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.sacrificeCopy("+JSON.stringify(content)+")",true)
	else: DisplayServer.clipboard_set(content)

func _sync_web_status() -> void:
	if not OS.has_feature("web"): return
	var info := {"room":session.room_code,"team":session.team,"names":session.names,"status":session.status,"peer_missing":session.peer_missing,"reconnecting":session.reconnecting,"phase":session.state.get("phase","lobby"),"round":session.state.get("round",0),"version":ProjectSettings.get_setting("application/config/version")}
	info["revision"] = session.state.get("revision",0)
	var event: Dictionary = session.state.get("animation",{})
	info["animation"] = {"id":event.get("id",0),"kind":event.get("kind",""),"stage":event.get("stage",""),"style":event.get("style","")}
	# Diagnostics contain only visible room/phase metadata, never cards or server rules.
	JavaScriptBridge.eval("window.sacrificeStatus="+JSON.stringify(info),true)
	if not session.room_code.is_empty(): JavaScriptBridge.eval("window.sacrificeRememberRoom?.("+JSON.stringify(session.room_code)+")",true)

func _resume_saved_match() -> void:
	if session.active or preview: return
	if OS.has_feature("web"):
		_resume_web_room()
	if not session.active: session.resume_ai()

func _resume_web_room() -> void:
	if session.active or preview: return
	var value = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.sacrificeResumeCandidate?.() || null)",true)))
	if not value is Dictionary: return
	saved_name = str(value.get("name",saved_name)); saved_code = str(value.get("room",""))
	session.resume_online(saved_name,saved_code,online_url,int(value.get("team",-1)))
