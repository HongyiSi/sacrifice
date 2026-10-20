extends SceneTree
const H = preload("res://tests/helpers.gd")
var main
func _initialize() -> void: _run.call_deferred()
func shot(name: String) -> void:
	await create_timer(.32).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/v0141-"+name+".png")
func display(g) -> void:
	main.session.team = 0; main.session.state = g.snapshot(0)
	main.session.state.names = ["流光预览","对手"]
	main.session.changed.emit()
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate(); root.add_child(main)
	await create_timer(.5).timeout
	var g = H.fixture(8)
	for id in range(6): H.give_death(g,id,["immortal","pain","life_steal","ghost","eye","blessing"][id])
	var a: int = H.give(g,0,"hasty_spell")
	var b: int = H.give(g,1,"quick_strike")
	var c: int = H.give(g,2,"holy_strike")
	for id in range(3):
		H.give(g,id,"strike"); H.give(g,id,"heal"); H.give(g,id,"attack_amulet" if id<2 else "feign")
	for id in range(3,6):
		H.give(g,id,"strike"); H.give(g,id,"heal"); H.give(g,id,"magic_strike")
	display(g); await shot("hand-gold"); await shot("hand-gold-motion")
	main._inspect_hand(0,a); await shot("gold-inspect")
	main._close_hand(); await create_timer(.3).timeout
	H.begin(g,{0:a,1:b,2:c,3:H.give(g,3,"hasty_spell"),4:H.give(g,4,"quick_strike")})
	display(g); await shot("played-gold")
	root.size = Vector2i(960,640); await shot("small-window")
	print("V0141_PREVIEW_RESULT hand/inspect/played/small rendered")
	quit()
