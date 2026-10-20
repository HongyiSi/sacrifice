extends "res://tests/v018_test.gd"
const Model=preload("res://scripts/ai_learning_model.gd")
const Policy=preload("res://scripts/ai_learning_policy.gd")
const Rules=preload("res://scripts/rules.gd")
func _initialize():
	var previous=load("D:/Godot projects/sacrifice/work/learning-ai-retrain-oct17/backup/ai_learning_model.gd")
	var weights=JSON.parse_string(FileAccess.get_file_as_string("D:/Godot projects/sacrifice/work/learning-ai-retrain-oct17/backup/ai_learning_weights.json")).weights
	for seed_value in range(1,25):
		var g=Rules.new();g.presentation_enabled=false;g.resolution_presentation_enabled=false;g.stage_presentation_enabled=false;g.start(seed_value)
		g.badges=[seed_value%4,(seed_value+1)%4]
		for c in g.characters:c.hp=(seed_value+c.id)%8
		var p=Policy.new(1);p.configure(weights)
		for side in [0,1]:check(Model.evaluate(g,side,p.weights)==previous.evaluate(g,side,weights),"old checkpoint retains exact evaluation")
		var left=Model.material_features(g,0);var right=Model.material_features(g,1)
		check(left.keys().all(func(key):return is_equal_approx(left[key],-right[key])),"material features are side symmetric")
	var g=H.fixture(7);g.presentation_enabled=false
	var p=Policy.new(1);p.configure({"board_alive":2.8,"board_badges":.35,"board_hp":2.8})
	g.phase="ended";g.winner=0
	check(Model.evaluate(g,0,p.weights)==250. and Model.evaluate(g,1,p.weights)==-250.,"trained preferences never override terminal wins")
	g.winner=-1;check(Model.evaluate(g,0,p.weights)==0.,"draw remains zero")
	g.phase="planning";g.characters[0].hp=0
	var f=Model.material_features(g,0)
	check(is_equal_approx(f.board_alive,-22.) and is_equal_approx(f.board_hp,-15.4),"lost living pawn represented separately from HP")
	print("LEARNING_VALUE_RESULT checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
