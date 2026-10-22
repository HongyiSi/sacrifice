extends RefCounted
## A deterministic lesson using the production rules and presentation queue.
## Only the starting position and the opponent's choices are scripted.
const Rules = preload("res://scripts/rules.gd")
const Checkpoint = preload("res://scripts/ai_checkpoint.gd")
const PANEL_RECT := Rect2(790,300,500,194)
const PLANNING_PANEL_RECT := Rect2(670,300,500,194)
const HEAL_PANEL_RECT := Rect2(380,300,500,194)
enum Step { WELCOME, BOARD, HAND, DEATH_CARD, CARD, PLAY, UNDO, REPLAY, REPLACE, DEFENSE,
	CONFIRM, UNLOCK, RECONFIRM, ORDER, RESOLVING, GUARD_TARGET, GUARD_REACT,
	ATTACK_TARGET, DEATH, DEATH_PLAY, ROUND_END, NEXT_DRAW, HEAL_PLAY,
	HEAL_CONFIRM, HEAL_RESOLVE, HEAL_TARGET, COMPLETE }
var step := Step.WELCOME:
	set(value):
		if value != step:
			step = value
			acknowledged = false
var acknowledged := false
var playing := false
var last_boundary := 0
var history: Array[Dictionary] = []
var cards: Dictionary = {}
var hint := ""
var opponent_at := 0

func create_game():
	var g = PracticeGame.new()
	g.start(721,1)
	# Start in a prepared first-round position, with five cards per pawn.
	# Rebuild ownership so every physical card still exists exactly once.
	g.deck = g.catalog.keys(); g.discard.clear()
	g.death_deck = g.death_catalog.keys(); g.death_discard.clear()
	g.effects.clear(); g.death_revealed.clear(); g.triggered_deaths.clear()
	var hands := [
		["strike","double_strike","heal","defense","strike"],
		["defense","heal","strike","double_strike","heal_other"],
		["heal_other","defense","strike","double_strike","heal"],
		["strike","double_strike","defense","heal","quick_strike"],
		["strike","defense","heal","quick_strike","magic_strike"],
		["strike","defense","double_strike","heal_other","magic_strike"]]
	var deaths := [109,110,107,106,119,117]
	for i in range(6):
		var c: Dictionary = g.characters[i]
		c.hp = Rules.MAX_HP; c.max_hp = Rules.MAX_HP; c.hand = []
		c.deathrattles = [deaths[i]]; g.death_deck.erase(deaths[i])
		for key in hands[i]:
			var id := _take(g,key)
			c.hand.append(id)
			if not cards.has("%d/%s" % [i,key]): cards["%d/%s" % [i,key]] = id
	g.characters[3].hp = 2
	# The next round draws ordinary cards without introducing extra mechanics.
	var draws: Array = g.deck.filter(func(id): return g.catalog[id].key in ["strike","magic_strike","precision_strike","quick_strike"])
	for id in draws.slice(0,6): g.deck.erase(id); g.deck.append(id)
	g.presentation_enabled = true
	g.log_lines.clear()
	g._note("新手教程：预设练习局面，敌方棋子1剩余2点生命；其余棋子满血。")
	return g

func _take(g, key: String) -> int:
	for id in g.deck:
		if g.catalog[id].key == key:
			g.deck.erase(id)
			return id
	assert(false,"Missing tutorial card: "+key)
	return 0

func card(actor: int, key: String) -> int:
	return int(cards.get("%d/%s" % [actor,key],0))

func expected_plan() -> Array:
	if step == Step.HEAL_CONFIRM: return [[],[],[card(2,"heal_other")]]
	return [[card(0,"double_strike")],[card(1,"defense")],[]]

func accept_local_plan(actor: int, selected: Array) -> bool:
	var expected := {}
	match step:
		Step.PLAY, Step.REPLAY: expected = {"actor":0,"cards":[card(0,"strike")]}
		Step.UNDO: expected = {"actor":0,"cards":[]}
		Step.REPLACE: expected = {"actor":0,"cards":[card(0,"double_strike")]}
		Step.DEFENSE: expected = {"actor":1,"cards":[card(1,"defense")]}
		Step.HEAL_PLAY: expected = {"actor":2,"cards":[card(2,"heal_other")]}
	if expected.is_empty() or actor != expected.actor or selected != expected.cards:
		hint = "先完成本步提示的操作；红色边框标出了操作位置。"
		return false
	hint = ""
	step = {Step.PLAY:Step.UNDO,Step.UNDO:Step.REPLAY,Step.REPLAY:Step.REPLACE,
		Step.REPLACE:Step.DEFENSE,Step.DEFENSE:Step.CONFIRM,Step.HEAL_PLAY:Step.HEAL_CONFIRM}[step]
	return true

func allows(kind: String, payload: Array) -> bool:
	match step:
		Step.CONFIRM, Step.RECONFIRM, Step.HEAL_CONFIRM:
			return kind == "plan" and payload == expected_plan()
		Step.UNLOCK: return kind == "unlock"
		Step.GUARD_TARGET: return kind == "target" and payload == [2]
		Step.GUARD_REACT: return kind == "defend" and payload == [1]
		Step.ATTACK_TARGET: return kind == "target" and payload == [3]
		Step.HEAL_TARGET: return kind == "target" and payload == [0]
	return false

func action_done() -> void:
	hint = ""
	step = {Step.CONFIRM:Step.UNLOCK,Step.UNLOCK:Step.RECONFIRM,Step.RECONFIRM:Step.ORDER,
		Step.GUARD_TARGET:Step.RESOLVING,Step.GUARD_REACT:Step.RESOLVING,
		Step.ATTACK_TARGET:Step.RESOLVING,Step.HEAL_CONFIRM:Step.HEAL_RESOLVE,
		Step.HEAL_TARGET:Step.HEAL_RESOLVE}.get(step,step)

func observe(g) -> void:
	playing = not g.animation.is_empty() or (step == Step.HEAL_RESOLVE and g.phase == "planning" and g.plans[0] != null and g.plans[1] == null)
	if g.lesson_boundary_id != last_boundary:
		last_boundary = g.lesson_boundary_id
		acknowledged = false
		if step == Step.RESOLVING and g.characters[3].hp == 0 and not g.death_phase and not g.queue.any(func(a): return a.status == "pending"):
			step = Step.DEATH
	if holds_animation(): return
	if step == Step.RESOLVING:
		if g.phase == "targeting" and g.request.get("team",-1) == 0:
			step = Step.GUARD_TARGET if g.catalog[g.input_action.card].key == "defense" else Step.ATTACK_TARGET
		elif g.phase == "reacting": step = Step.GUARD_REACT
		elif g.turn_stage == "death": step = Step.DEATH
	elif step == Step.DEATH_PLAY and g.phase == "review": step = Step.ROUND_END
	elif step == Step.NEXT_DRAW and g.phase == "planning": step = Step.HEAL_PLAY
	elif step == Step.HEAL_RESOLVE:
		if g.phase == "targeting" and g.request.get("team",-1) == 0: step = Step.HEAL_TARGET
		elif g.phase == "review": step = Step.COMPLETE

func holds_animation() -> bool:
	return not playing and not acknowledged and step in [Step.RESOLVING,Step.DEATH,Step.DEATH_PLAY,Step.NEXT_DRAW,Step.HEAL_RESOLVE]

func can_confirm() -> bool:
	return not playing and not acknowledged and step in [Step.WELCOME,Step.BOARD,Step.HAND,Step.DEATH_CARD,Step.CARD,
		Step.ORDER,Step.RESOLVING,Step.DEATH,Step.DEATH_PLAY,Step.ROUND_END,Step.NEXT_DRAW,Step.HEAL_RESOLVE]

func remember(g, choices: Array) -> void:
	# Save only settled pages: returning to one must not restore a half-played effect.
	if playing: return
	if not history.is_empty() and history.back().step == step and history.back().boundary == last_boundary: return
	# In-memory only. Preserve aliases shared by requests and queued jobs; omit
	# immutable catalogs so page history stays small, including on mobile.
	var fields := {}
	for p in g.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.name not in ["rng","catalog","death_catalog"]:
			fields[p.name] = g.get(p.name)
	var graph := Checkpoint.Graph.new()
	var root = graph.encode({"fields":fields,"choices":choices,"seed":g.rng.seed,"rng":g.rng.state})
	history.append({"step":step,"boundary":last_boundary,"data":var_to_bytes({"root":root,"nodes":graph.nodes})})

func previous(g) -> Array:
	if history.size() < 2: return []
	history.pop_back()
	var saved: Dictionary = history.back()
	var restored: Dictionary = Checkpoint.Graph.new().decode(bytes_to_var(saved.data))
	for key in restored.fields: g.set(key,restored.fields[key])
	g.rng.seed = restored.seed; g.rng.state = restored.rng
	step = saved.step; acknowledged = false; hint = ""; opponent_at = 0
	last_boundary = g.lesson_boundary_id; playing = false
	return restored.choices

func next(g) -> void:
	if not can_confirm(): return
	hint = ""
	match step:
		Step.WELCOME: step = Step.BOARD
		Step.BOARD: step = Step.HAND
		Step.HAND: step = Step.DEATH_CARD
		Step.DEATH_CARD: step = Step.CARD
		Step.CARD: step = Step.PLAY
		Step.RESOLVING, Step.DEATH_PLAY, Step.NEXT_DRAW, Step.HEAL_RESOLVE:
			acknowledged = true
			g.resume_lesson()
		Step.ORDER:
			step = Step.RESOLVING
			g.submit(1,[[],[card(4,"strike")],[card(5,"strike")]])
		Step.DEATH:
			step = Step.DEATH_PLAY
			g.resume_lesson()
		Step.ROUND_END:
			step = Step.NEXT_DRAW
			g.advance_round()
	observe(g)

func tick(g, now: int) -> bool:
	if holds_animation(): return false
	# Let the real animations finish, then make the opponent's fixed choice.
	if not g.animation.is_empty(): opponent_at = 0; return false
	if step == Step.HEAL_RESOLVE and g.phase == "planning" and g.plans[0] != null and g.plans[1] == null:
		g.submit(1,[[],[],[]]); return true
	if step != Step.RESOLVING or g.request.get("team",-1) != 1: opponent_at = 0; return false
	if opponent_at == 0: opponent_at = now+650
	if now < opponent_at: return false
	opponent_at = 0
	if g.phase == "targeting":
		g.target(1,2 if g.input_action.actor == 4 else 0)
		return true
	return false

func panel_rect() -> Rect2:
	if step >= Step.HEAL_PLAY: return HEAL_PANEL_RECT
	return PLANNING_PANEL_RECT if step < Step.ORDER else PANEL_RECT

class PracticeGame extends "res://scripts/rules.gd":
	# Pause only after completion and all queued visuals, never between travel,
	# impact, discard, or healing stages. This hook exists solely in the tutorial.
	var lesson_boundary := false
	var lesson_boundary_id := 0
	var lesson_allow_advance := false
	func _advance_step() -> void:
		if not lesson_allow_advance and (current_id >= 0 or death_current_id >= 0):
			lesson_boundary = true
			lesson_boundary_id += 1
			# The target request has been consumed; the settled board is no
			# longer in a targeting/reacting input phase while the reader waits.
			phase = "deathrattle" if death_phase else "preparing"
			revision += 1
			return
		lesson_allow_advance = false
		super._advance_step()
	func resume_lesson() -> void:
		if not lesson_boundary: return
		lesson_boundary = false
		lesson_allow_advance = true
		_push([{"op":"advance"}])
		_pump()

func lesson() -> Dictionary:
	# Basic rules intentionally omit special-card exceptions and card-name lists.
	var lessons := {
		Step.WELCOME:["从一场练习开始","这是一段两回合的模拟对战。下方是你的队伍，上方是对手的队伍。","开始学习",1],
		Step.BOARD:["认识棋子与胜利目标","双方各有3个棋子，生命上限是7，心形表示剩余生命。\n击败全部对方棋子，或集齐4枚胜利徽章即可获胜。","认识手牌",1],
		Step.HAND:["每个棋子有自己的手牌","开局每个棋子有4张手牌；每回合出牌前，存活的棋子摸1张牌。手牌上限为8张牌。","认识卡牌",1],
		Step.DEATH_CARD:["棋子旁边的独立牌","每个棋子开局还有1张亡语牌，放在棋子旁边。阵亡后如何触发，稍后练习。\n你能查看自己的手牌与亡语牌；敌方尚未公开的牌只能看见牌背。","认识普通牌",1],
		Step.CARD:["先读效果，再决定出牌","普通牌分为攻击牌和技能牌。悬停可查看说明，点击空白处可收起提示。左上角的数字是主优先级，右上角是次优先级。\n红框内的示范牌：对一个棋子造成1点伤害。","动手试试",2],
		Step.PLAY:["点击手牌，就能打出","每个存活棋子每回合可打出1张手牌，也可以不出。\n点击我方棋子1手中红框标出的牌，将它放到棋子前方。","",2],
		Step.UNDO:["出牌后仍能撤回","现在还没有确认。点击棋子前方红框内的已出牌，将它收回手中。","",2],
		Step.REPLAY:["再选一次","刚才的牌已回到手中。\n再次点击红框内的手牌，接下来练习直接换牌。","",2],
		Step.REPLACE:["直接点击另一张牌来替换","点击手中新的红框牌：它可以造成2点伤害。\n棋子已经出过1张牌，因此旧牌会收回，改为打出新牌。","",2],
		Step.DEFENSE:["为队友准备保护","再点击我方棋子2手中红框标出的技能牌。\n它可以为一个棋子挡住一次以它为唯一目标的攻击；结算时再选保护目标。","",2],
		Step.CONFIRM:["确认全队出牌","两枚棋子已出牌，棋子3这回合不出牌。\n点击右侧“确认出牌”。未选择牌的棋子会自动视为不出牌。","",3],
		Step.UNLOCK:["对方确认前，可以取消","按钮已经变成“取消确认”。对方尚未确认时，你仍可取消并修改出牌。\n现在点击“取消确认”试一次。双方都确认后就不能更改了。","",3],
		Step.RECONFIRM:["准备完成","你的选择仍然保留。再次点击“确认出牌”。\n你能看见自己的出牌，但对手只能看到牌背；你也看不到对手尚未翻开的牌。","",3],
		Step.ORDER:["优先级决定结算顺序","双方确认后，先翻开主优先级最大的一批牌，再按次优先级从大到小结算。\n这一批结束，再处理下一批。本次依次演示主优先级6、5、4。","开始结算",3],
		Step.RESOLVING:["观察结算","现在按优先级依次处理打出的牌，轮到你选择时会停下来。\n攻击和技能都以卡面描述为准；指定目标后，动画和效果会自动结算。","",4],
		Step.GUARD_TARGET:["点击红框选择目标","需要选择棋子时，红框会标出本步需要选择的棋子。\n这次请点击我方棋子3，为它提供保护；此时不需要再点击手牌。","",4],
		Step.GUARD_REACT:["在被攻击时作出响应","对手正在攻击刚刚受保护的我方棋子3。\n请点击下方“确认”使用防御，取消这次攻击的效果。","",4],
		Step.ATTACK_TARGET:["轮到你的攻击了","请点击敌方棋子1。它还剩2点生命，本次攻击造成2点伤害。\n生命降到0，棋子就会阵亡；阵亡棋子未结算的普通牌不能继续发动。","",4],
		Step.DEATH:["阵亡之后，还有亡语","普通牌结算结束后，处理本回合阵亡棋子的亡语牌。\n亡语按优先级从大到小结算；轮到它时，棋子仍需处于死亡状态。","观看亡语",5],
		Step.DEATH_PLAY:["观察亡语的影响","敌方刚阵亡的棋子正在触发亡语。\n击败棋子也可能让对方获得收益，因此进攻前也要留意亡语牌。","",5],
		Step.ROUND_END:["击败一个棋子，不等于获胜","上方敌方亮起了2枚徽章，这是刚才的亡语效果。集齐4枚即可获胜。\n一次性亡语会留下“已触发”标记。还有敌人存活，继续下一回合。","进入下一回合",5],
		Step.NEXT_DRAW:["下一回合开始","存活棋子正在摸牌。阵亡棋子不能正常出牌。\n如果本回合没有需要处理的亡语，亡语阶段会直接跳过。","",6],
		Step.HEAL_PLAY:["练习一次回复","我方棋子1刚才受到另一名敌人的攻击，现在剩6点生命。\n点击我方棋子3手中红框标出的技能牌，这次练习为队友回复生命。","",6],
		Step.HEAL_CONFIRM:["只出需要的牌","这次只有棋子3出牌，其他棋子都不出。\n点击“确认出牌”，继续结算。练习对手本回合也不会出牌。","",6],
		Step.HEAL_RESOLVE:["等待技能结算","先等待翻牌与结算动画。\n需要你选择目标时，红框会再次标出操作位置。","",6],
		Step.HEAL_TARGET:["把回复给受伤的队友","点击我方棋子1，为它回复生命。\n回复后最多回到生命上限7，多余的回复不会变成额外生命。","",6],
		Step.COMPLETE:["教程完成","恭喜你已经学会了《牺牲》的基本玩法！现在可以返回大厅，进行一场酣畅的战斗了。","",6]
	}
	var row: Array = lessons[step]
	return {"title":row[0],"body":row[1],"next":"确认" if can_confirm() else "","chapter":row[3],"hint":hint}

func focus() -> Dictionary:
	match step:
		Step.CARD, Step.PLAY, Step.REPLAY: return {"card_id":card(0,"strike")}
		Step.UNDO: return {"staged_card_id":card(0,"strike")}
		Step.REPLACE: return {"card_id":card(0,"double_strike")}
		Step.DEFENSE: return {"card_id":card(1,"defense")}
		Step.CONFIRM, Step.UNLOCK, Step.RECONFIRM, Step.HEAL_CONFIRM: return {"planning_lock_button":true}
		Step.GUARD_TARGET: return {"target_character_id":2}
		Step.ATTACK_TARGET: return {"target_character_id":3}
		Step.HEAL_PLAY: return {"card_id":card(2,"heal_other")}
		Step.HEAL_TARGET: return {"target_character_id":0}
		Step.GUARD_REACT: return {"tutorial_defend_button":true}
	return {}
