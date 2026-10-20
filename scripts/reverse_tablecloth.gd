extends Control
## Lives below the rebuilt board, driven by the same public event clock as audio.
const Timing = preload("res://scripts/reverse_timing.gd")
const BASE := Vector2(1440,960)
var cloth: TextureRect
var particles: Control
var event: Dictionary = {}
var clock_started := -1
var elapsed := 0.0
var mode := "idle"
var progress := 0.0
var active := false
var round_key := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = BASE
	cloth = TextureRect.new()
	cloth.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cloth.stretch_mode = TextureRect.STRETCH_SCALE
	cloth.texture = preload("res://assets/art/table.png")
	cloth.size = BASE
	cloth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://scripts/shaders/reverse_cloth.gdshader")
	shader.set_shader_parameter("purple_texture",preload("res://assets/art/reverse_purple_cloth.png"))
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/reverse_cloth_rows.json"))
	var bounds := Image.create(1,1024,false,Image.FORMAT_RGBF)
	for y in range(1024): bounds.set_pixel(0,y,Color(rows[y][0]/1536.0,rows[y][1]/1536.0,0))
	shader.set_shader_parameter("cloth_row_bounds",ImageTexture.create_from_image(bounds))
	cloth.material = shader
	add_child(cloth)
	particles = preload("res://scripts/reverse_magic_front.gd").new()
	add_child(particles)
	set_meta("reverse_tablecloth",true)
	hide()
	set_process(false)

func sync_view(view: Dictionary, started: int) -> void:
	scale = get_parent().size/BASE
	if view.is_empty():
		round_key = "";event = {};mode = "idle";active = false
		_apply(0,0,false,false);hide();set_process(false)
		return
	var key := "%s/%s" % [view.match,view.round]
	if key != round_key:
		round_key = key;mode = "idle";elapsed = 0
	event = view.get("animation",{}).duplicate(true)
	active = view.get("reverse_cloth_active",false)
	clock_started = started
	show()
	if Timing.is_reverse(event): mode = "dye"
	elif event.get("kind","") == "reverse_restore": mode = "restore"
	else: mode = "idle"
	set_process(mode != "idle")
	present(maxf(0,(Time.get_ticks_msec()-clock_started)/1000.0))

func present(seconds: float) -> void:
	elapsed = seconds
	if mode == "restore":
		_apply(smoothstep(0,Timing.RESTORE_MS/1000.0,seconds),seconds,true,true)
	elif mode == "dye":
		var age := Timing.age(event,seconds)
		var already_purple: bool = event.get("cloth_was_active",false)
		_apply(1.0 if already_purple else smoothstep(Timing.DYE_START,Timing.DYE_END,age),maxf(0,age-Timing.DYE_START),false,not already_purple)
	else:
		_apply(1.0 if active else 0.0,0,false,false)

func _process(_delta: float) -> void:
	present(elapsed if clock_started < 0 else maxf(0,(Time.get_ticks_msec()-clock_started)/1000.0))

func _apply(value: float, seconds: float, restoring: bool, moving: bool) -> void:
	progress = value
	cloth.material.set_shader_parameter("progress",value)
	cloth.material.set_shader_parameter("restoring",restoring)
	cloth.material.set_shader_parameter("magic_clock",seconds)
	cloth.material.set_shader_parameter("magic_amount",1.0 if moving and value>0 and value<1 else 0.0)
	particles.present(value,seconds,restoring,moving)
