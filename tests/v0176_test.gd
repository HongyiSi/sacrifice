extends SceneTree
const H=preload("res://tests/helpers.gd")
const S=preload("res://tests/v011_scenarios.gd")
var checks:=0
var failures:=0
func _initialize()->void:_run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("V0176_FAIL "+label)
func activate(g,owner:int,key:String,target:int=-1)->void:
	var id:int=H.give_death(g,owner,key);g._activate({"actor":owner,"card":id},owner if target<0 else target)
func drain(g,phases:Array=["review","ended"])->void:
	for _i in range(400):
		if g.animation.is_empty() and g.phase in phases:return
		check(S.step(g).is_empty(),"legal continuation")
	check(false,"job limit")
func draw(g,id:int,n:int)->void:
	g._push([{"op":"draw","target":id,"count":n}]);g._pump()
func _run()->void:
	var g=H.fixture(8)
	check(g.catalog.size()==107 and g.death_catalog.size()==20,"current physical counts")
	var definitions:Dictionary={};var priorities:Dictionary={}
	for c in g.catalog.values():
		definitions[c.key]=true;var rank:String=str(c.main)+"/"+str(c.secondary)
		check(not priorities.has(rank),"unique priority "+rank);priorities[rank]=true
	check(definitions.size()==43,"43 ordinary card types")
	check(g.death_catalog[113].priority==4 and g.death_catalog[113].type=="持续性","greed rework definition")
	check(g.death_catalog[112].priority==13 and g.death_catalog[104].priority==5,"death priorities synchronized")
	# Precision is one attack with two distinct declared targets, not two single attacks.
	g=H.fixture(8);g.presentation_enabled=true;H.begin(g,{0:H.give(g,0,"precise_strike")})
	g.characters[3].shield=1;g.characters[3].shield_sources=[3]
	check(g.target(0,3)=="" and g.characters[3].hp==8,"first target does not deal early damage")
	check(g.target(0,3)!="" and g.request.options.size()==5,"duplicate target rejected")
	check(g.target(0,4)=="","second target accepted")
	g.advance_animation()
	check(g.characters[3].hp==7 and g.characters[4].hp==7 and g.characters[3].shield==1,"two targets; single-target defense not consumed")
	g=H.fixture(8);activate(g,3,"blessing",3);H.begin(g,{0:H.give(g,0,"precise_strike")});g.target(0,3);g.target(0,4)
	check(g.characters[3].hp==8 and g.characters[4].hp==7,"blessing applies only to protected target")
	g=H.fixture(8);var guard:int=H.give(g,3,"attack_amulet");var hit:int=H.give(g,0,"precise_strike")
	g.submit(0,[hit,0,0]);g.submit(1,[{"cards":[guard],"guards":{guard:4}},0,0]);g.target(0,3)
	check(g.phase=="targeting","amulet waits for both declared targets");g.target(0,4)
	check(g.phase=="responding","amulet protects second target");g.respond(1,g.request.options[0])
	check(g.characters[3].hp==8 and g.characters[4].hp==8,"amulet cancels whole precision attack")
	g=H.fixture(8);H.begin(g,{0:H.give(g,0,"precise_strike")});g.target(0,0);g.skip_effect(0)
	check(g.characters.all(func(c):return c.hp==8),"precision skip cancels before both hits")
	# Warcry stacks for next round only and adds damage once per attack target.
	g=H.fixture(8);var w:int=H.give(g,0,"warcry");var action:Dictionary=g._add_action(0,w)
	g._run_job(g._job("warcry",action));g._run_job(g._job("warcry",action))
	check(g.characters[0].warcry_bonus==6,"warcry stacks")
	var a:Dictionary=g._add_action(0,H.give(g,0,"strike"));g._damage(a,3,1)
	check(g.characters[3].hp==7,"no bonus on casting round")
	g.round_number+=1;g._damage(a,4,1);check(g.characters[4].hp==1,"next round attack gains six once")
	var spell:Dictionary=g._add_action(0,H.give(g,0,"magic_strike"));g._damage(spell,5,2)
	check(g.characters[5].hp==6,"warcry does not buff skills")
	g.round_number+=1;g._damage(a,5,1);check(g.characters[5].hp==5,"warcry expires after next round")
	g=H.fixture(8);g.characters[0].warcry_round=g.round_number;g.characters[0].warcry_bonus=3;g.presentation_enabled=true
	H.begin(g,{0:H.give(g,0,"precise_strike")});g.target(0,3);g.target(0,4)
	check(g.animation.targets.size()==2 and g.animation.targets[0].damage==4,"buffed two-target animation uses actual damage")
	g.advance_animation();check(g.characters[3].hp==4 and g.characters[4].hp==4,"both boosted hits at impact")
	# Greed activation is once-only and starts at later planning phases.
	g=H.fixture(8);activate(g,0,"greed")
	check(g.play_limit(g.characters[1])==1,"greed not active in same planning phase")
	g.characters[0].hp=0;g.phase="review";g.advance_round()
	check(g.characters[0].hand.size()==0 and g.characters[1].hand.size()==2 and g.characters[2].hand.size()==2,"greed only draws for living allies")
	check(g.characters[3].hand.size()==1 and g.play_limit(g.characters[1])==2,"greed ally extra play")
	g.characters[1].extra_round=g.round_number;g.characters[1].extra_count=2;g.characters[1].overload_round=g.round_number
	check(g.play_limit(g.characters[1])==6,"greed heart and overload stack")
	g._lose_death(0,113);check(g.play_limit(g.characters[1])==5,"greed immediately stops when source lost")
	g=H.fixture(8);activate(g,1,"privilege")
	for id in range(6):check(g._bonus(id)==(100 if id<3 else 0),"team privilege")
	g._lose_death(1,101)
	for id in range(6):check(g._bonus(id)==0,"team privilege removal")
	# Ghost samples card types, including the new precision attack and magic skill.
	g=H.fixture(8);var random_types:Dictionary={}
	for _i in range(500):
		var c:Dictionary=g.catalog[g._random_strike_id()];random_types[c.key]=true;check("打击" in c.name,"ghost pool excludes non-strikes")
	check(random_types.has("precise_strike") and random_types.has("magic_strike"),"new and skill strikes in ghost pool")
	activate(g,0,"ghost");g.characters[0].hp=0;H.begin(g,{})
	var ghost:Dictionary=H.action_for(g,0,true);check(ghost.secondary==100 and ghost.origin=="ghost","ghost retains unique virtual priority")
	g=H.fixture(8);var heart:int=H.give_death(g,0,"heart");var ha:Dictionary={"actor":0,"card":heart,"id":1,"death":true,"status":"active"}
	g._push(g._target_jobs(ha,1));g._pump()
	check(g.characters[1].hand.size()==3 and g.characters[1].extra_count==2 and g.characters[1].deathrattles.has(heart),"heart draws three and grants two extra plays")
	g=H.fixture(8);H.give_death(g,0,"life_steal");g.characters[0].hp=0;g.characters[0].death_round=g.round_number;g.characters[3].hp=3;H.begin(g,{});g.target(0,3)
	check(g.characters[3].hp==0 and g.characters[0].hp==5,"life steal three damage triggers revival")
	# Draw presentation is private, finite and covers ordinary/round/replacement gains.
	for target in range(6):
		g=H.fixture(8);g.presentation_enabled=true;draw(g,target,3)
		check(g.animation.kind=="draw_cards" and g.animation.draws[0].count==3,"every pawn has batch draw flight")
		for viewer in [0,1]:
			var d:Dictionary=g.snapshot(viewer).animation.draws[0]
			check(d.has("ids")== (target/3==viewer),"draw identities redacted by recipient team")
		drain(g,["planning"]);check(g.characters[target].hand.size()==3,"gain preserved")
	g=H.Rules.new();g.presentation_enabled=true;g.start(333)
	check(g.animation.is_empty() and g.phase=="planning","opening hand immediately ready");drain(g,["planning"])
	check(g.characters.all(func(c):return c.hand.size()==4),"opening and round draws end at four each")
	g=H.fixture(8);activate(g,0,"prison",1);H.give(g,1,"strike");g.presentation_enabled=true;draw(g,1,3)
	check(g.animation.get("kind","")!="draw_cards" and g.characters[1].hand.size()==1,"blocked draw has no phantom flight")
	g=H.fixture(8);g.presentation_enabled=true;g.deck=g.deck.slice(0,1);g.discard=[];draw(g,0,3)
	check(g.animation.draws[0].count==1,"empty deck animates actual one card only")
	g=H.fixture(8);g.presentation_enabled=true;g.discard=g.deck.slice(1,5);g.deck=g.deck.slice(0,1);draw(g,0,3)
	check(g.animation.draws[0].pile_steps==[0,3,2],"deck counter handles mid-batch shuffle")
	g=H.fixture(8);activate(g,0,"divinity");g.characters[0].hp=0;g.presentation_enabled=true;draw(g,4,3)
	while not g.animation.is_empty():g.advance_animation()
	check(g.request.type=="deck","divinity waits for actual choices");var chosen:Array=g.request.options.slice(0,3);g.pick(0,chosen)
	check(g.animation.kind=="draw_cards" and g.characters[4].hand==chosen,"chosen cards use same pile animation")
	check(not g.snapshot(0).animation.draws[0].has("ids"),"divinity source does not expose receiver hand in animation")
	g=H.fixture(8);g._draw(g.characters[0],7);g.presentation_enabled=true;draw(g,0,3)
	check(g.animation.kind=="draw_cards" and g.request.is_empty(),"overflow waits for visible gain")
	while not g.animation.is_empty():g.advance_animation()
	check(g.request.type=="hand_limit" and g.request.count==2,"owner chooses excess only after all arrivals")
	print("V0176_RESULT checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
