extends RefCounted
## Host-owned, resumable rules. Jobs pause at player choices without losing the parent effect.
const MAX_HP := 7
const HAND_LIMIT := 8
const TEAM_SIZE := 3
const BADGE_GOAL := 4
const NAMES := ["棋子1", "棋子2", "棋子3", "棋子1", "棋子2", "棋子3"]
const StrikeStyles = preload("res://scripts/strike_styles.gd")
const CardEffectStyles = preload("res://scripts/card_effect_styles.gd")
var rng := RandomNumberGenerator.new()
var catalog: Dictionary = {}
var death_catalog: Dictionary = {}
var characters: Array = []
var deck: Array = []
var discard: Array = []
var death_deck: Array = []
var death_discard: Array = []
var death_revealed: Array = []
var triggered_deaths: Dictionary = {}
var effects: Array = []
var plans: Array = [null, null]
var confirmed: Array = [false, false]
var badges: Array = [0, 0]
var queue: Array = []
var death_queue: Array = []
var mirrors: Array = []
var skipped: Array = []
var request: Dictionary = {}
var input_action: Dictionary = {}
var pending_attack: Dictionary = {}
var jobs: Array = []
var pumping := false
var current_id := -1
var death_current_id := -1
var next_action_id := 1
var next_death_id := 1
var round_number := 0
var phase := "planning"
var death_phase := false
var winner := -2
var win_reason := ""
var log_lines: Array = []
var revision := 0
var match_id := 0
var death_events := 0
const AMULETS := ["holy_amulet", "attack_amulet", "magic_amulet"]
const BASIC_CARDS := ["anticipation", "gift", "cards_to_heart", "cards_to_blades", "frenzy", "bloodletting", "gold_panning", "search", "sapphire", "ruby", "amethyst", "rally", "defile", "obstruct", "final_strike", "poisoning", "poison", "prepared"]
const GEMS := ["sapphire", "ruby", "amethyst"]
const PASSING_GEMS := ["topaz", "emerald", "amber"]
const DISCARD_CARDS := ["spare_food", "spare_supplies"]
const BOULDER := {"key":"boulder","name":"巨石","main":-1,"secondary":0,"type":"诅咒","text":"这张牌不能被打出或弃置。","short":"不可打出或弃置","playable":false,"discardable":false}
const POISON := {"key":"poison","name":"毒药","main":0,"secondary":0,"type":"诅咒","text":"失去1点生命。\n在手牌中时，这个棋子不能打出攻击牌。\n这张牌不能被弃置。","short":"失去1生命 · 禁攻击","playable":true,"discardable":false}
var defiled_cards: Dictionary = {}
var final_strike_damage: Dictionary = {}
var discard_triggers: Array = []
var next_generated_card_id := 1000
var reveal_locked_teams: Array = [false, false]
var normal_type_count := 0
var reversed_order := false
var reverse_cloth_active := false
var reverse_restore_queued := false
var reverse_after: Array = []
var current_main := -1
var skip_death_phase := false
var skip_death_actor := 0
var staged_discards: Array = []
var discard_batch_pending: Array = []
var early_end_team := -1
var next_forced_batch := 1
## Live sessions pause at presentation boundaries; rules-only simulations stay instant.
var presentation_enabled := false
var resolution_presentation_enabled := true
var animation: Dictionary = {}
var animation_jobs: Array = []
var animation_serial := 0
var animation_resume_phase := ""
var visual_queue: Array = []
# The broad turn stage survives interactive requests and nested immediate effects.
var turn_stage := "planning"
var stage_main := -1
var stage_presentation_enabled := true
var initial_deal := false
var divinity_choice_chain := false
# Public prop state only: no hand identities or private choices.
var prepared_backpack: Dictionary = {}

func _init() -> void:
	# Normal cards and the curse-in-hand share one ID namespace in snapshots.
	# Reserve deathrattle IDs before expanding the ordinary deck past 100 cards.
	for definition in JSON.parse_string(FileAccess.get_file_as_string("res://data/deathrattles.json")):
		definition.id = int(definition.id)
		definition.priority = int(definition.priority)
		death_catalog[definition.id] = definition
	var definitions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json"))
	normal_type_count = definitions.size()
	var id := 1
	for definition in definitions:
		for rank in definition.ranks:
			while death_catalog.has(id): id += 1
			var card: Dictionary = definition.duplicate(true)
			card.erase("ranks")
			card.main = int(card.main)
			card.secondary = int(rank)
			card.id = id
			catalog[id] = card
			id += 1

func start(seed_value: int = 0, serial: int = 1) -> void:
	for id in catalog.keys():
		if catalog[id].get("generated",false): catalog.erase(id)
	defiled_cards.clear()
	final_strike_damage.clear()
	discard_triggers.clear()
	staged_discards.clear();discard_batch_pending.clear()
	next_generated_card_id = 1000
	prepared_backpack.clear()
	initial_deal = true
	turn_stage = "planning"
	stage_main = -1
	visual_queue = []
	animation = {}
	animation_jobs = []
	if seed_value == 0: rng.randomize()
	else: rng.seed = seed_value
	match_id = serial
	death_events = 0
	characters = []
	deck = catalog.keys()
	discard = []
	death_deck = death_catalog.keys()
	death_discard = []
	death_revealed = []
	triggered_deaths.clear()
	effects = []
	queue = []
	jobs = []
	log_lines = []
	badges = [0, 0]
	round_number = 0
	revision = 0
	winner = -2
	win_reason = ""
	_shuffle(death_deck)
	for id in range(6):
		characters.append({"id":id, "team":id / 3, "name":NAMES[id], "hp":MAX_HP, "max_hp":MAX_HP,
			"hand":[], "death_round":-1, "deathrattles":[death_deck.pop_back()],
			"revealed":false, "shield":0, "shield_sources":[], "prediction":0, "extra_round":-1, "extra_count":0})
	_shuffle(deck)
	for _n in range(4):
		for c in characters: _draw(c)
	_note("双方各控制三个棋子，初始生命与生命上限 7，手牌上限 %d；普通牌 %d 种、%d 张，亡语 20 种，每个棋子随机获得 1 张亡语。" % [HAND_LIMIT,normal_type_count,catalog.size()])
	if presentation_enabled and stage_presentation_enabled:
		turn_stage = "start"
		visual_queue.append(_stage_event("start",-1,true))
	_begin_round()
	initial_deal = false

func _shuffle(cards: Array) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var saved = cards[i]
		cards[i] = cards[j]
		cards[j] = saved

func _refill() -> void:
	if deck.is_empty() and not discard.is_empty():
		deck = discard.duplicate()
		discard.clear()
		_shuffle(deck)
		_note("普通弃牌重新洗入牌库。")

func _draw(character: Dictionary, count: int = 1, source_action: Dictionary = {}) -> void:
	# Primitive draw; interactive draws enter through the draw job.
	if _draw_blocked(character):
		_note("%s 因禁锢且持有可打出的手牌，本次摸牌被取消。" % character.name)
		return
	var before_hand: Array = character.hand.duplicate()
	var pile_before := deck.size()
	var received: Array = []
	var pile_steps: Array = []
	var drawn := 0
	for _n in range(count):
		_refill()
		if deck.is_empty(): break
		var card_id: int = deck.pop_back()
		received.append(card_id)
		pile_steps.append(deck.size())
		drawn += 1
	if drawn < count: _note("%s 实际摸到 %d 张牌（牌库不足）。" % [character.name,drawn])
	_receive_drawn_cards(character,received,before_hand,pile_before,source_action,pile_steps)

func _receive_drawn_cards(character: Dictionary, ids: Array, before_hand: Array, pile_before: int, source_action: Dictionary, pile_steps: Array = []) -> void:
	# IDs have left the pile, but rejected cards never enter the hand. Return
	# the rejected batch in draw order, so its first card is back on top.
	var returned: Array = []
	var rejected: Array = []
	for id in ids:
		var full: bool = character.hand.size() >= HAND_LIMIT
		returned.append(full)
		if full: rejected.append(id)
		else: character.hand.append(id)
	for i in range(rejected.size()-1,-1,-1): deck.append(rejected[i])
	if not rejected.is_empty(): _note("%s：我的手牌满了！%d 张摸牌返回抽牌堆。" % [character.name,rejected.size()])
	_queue_draw_visual(character.id,ids,before_hand,pile_before,source_action,pile_steps,returned)

func _queue_draw_visual(target: int, ids: Array, before_hand: Array, pile_before: int, source_action: Dictionary = {}, pile_steps: Array = [], returned: Array = []) -> void:
	if not presentation_enabled or initial_deal or ids.is_empty(): return
	var e: Dictionary
	if not visual_queue.is_empty() and visual_queue[-1].kind == "draw_cards": e = visual_queue[-1]
	else:
		e = {"kind":"draw_cards","stage":"travel","style":"draw","action":source_action.duplicate(true),"targets":[],"draws":[],"impact_ms":160,"travel_ms":0,"caption":"卡牌从抽牌堆飞入手牌","pile_before":pile_before,"pile_after":deck.size()}
		visual_queue.append(e)
	var order: int = 0
	for d in e.draws: order += d.count
	var start_at: int = order*160 if round_number == 0 else int(e.get("last_start",-420))+420
	# One logical gain can contain several cards; the draw order is retained.
	var entry := {"target":target,"ids":ids.duplicate(),"before_hand":before_hand.duplicate(),"before_count":before_hand.size(),"count":ids.size(),"start_ms":start_at,"step_ms":400,"flight_ms":1650,"source_key":_info(source_action).key if not source_action.is_empty() else "round"}
	entry.returned = returned.duplicate()
	if entry.returned.is_empty():
		for _i in range(ids.size()): entry.returned.append(false)
	entry.speech_ms = 1900
	# Returning backs reveal no identity, even to the owner of the full hand.
	for i in range(ids.size()):
		if entry.returned[i]: entry.ids[i] = 0
	entry.pile_before = pile_before
	entry.pile_steps = pile_steps.duplicate()
	if entry.pile_steps.is_empty():
		for i in range(ids.size()): entry.pile_steps.append(pile_before-i-1)
	var ordinal := 0
	for d in e.draws:
		if d.target == target: ordinal += d.count-d.returned.count(true)
	entry.starts = []; entry.durations = []
	var next_start := start_at
	var last_arrival := start_at
	for i in range(ids.size()):
		if entry.returned[i]:
			entry.starts.append(-1); entry.durations.append(0)
			continue
		var duration: int = preload("res://scripts/draw_timing.gd").flight(ordinal)
		entry.starts.append(next_start); entry.durations.append(duration)
		e.last_start = next_start
		last_arrival = next_start+duration
		next_start += preload("res://scripts/draw_timing.gd").gap(ordinal)
		ordinal += 1
	e.travel_ms = maxi(e.travel_ms,last_arrival+200)
	if entry.returned.has(true):
		entry.speech_start = last_arrival
		e.travel_ms = maxi(e.travel_ms,last_arrival+entry.speech_ms)
	entry.pile_after = deck.size()
	e.draws.append(entry)
	if entry.source_key == "prepared":
		preload("res://scripts/prepared_timing.gd").configure_draw(e)
		prepared_backpack.draw_seen = true
	e.pile_after = deck.size()
	e.targets.append({"id":target,"amount":ids.size()-entry.returned.count(true)})

func _queue_hand_limit(target: int) -> void:
	if characters[target].hand.size() <= HAND_LIMIT: return
	# Check after this gain, before remaining jobs such as Pain's bonus play.
	# Never discard randomly for players.
	_push([{"op":"hand_limit","target":target}])

func _put_in_hand(target: int, id: int, source: Dictionary = {}, origin: Dictionary = {}) -> bool:
	# Placement differs from drawing: reject the incoming card, without ever
	# exceeding the cap or asking the recipient to discard an existing card.
	if characters[target].hand.size() >= HAND_LIMIT:
		if death_catalog.has(id): death_discard.append(id)
		else: discard.append(id)
		_note("%s 的手牌已满，放入失败的牌被弃置（包括不可弃置牌）。" % characters[target].name)
		if not source.is_empty(): _queue_placement_full(source,target)
		return false
	var before_hand: Array = characters[target].hand.duplicate()
	characters[target].hand.append(id)
	if presentation_enabled and not source.is_empty() and _info(source).key in ["gift","poisoning","obstruct","search","plunder"]:
		var key: String = _info(source).key
		var pile_before: int = deck.size()+(1 if key == "search" else 0)
		_queue_draw_visual(target,[id],before_hand,pile_before,_visual_event(source,key,target).action,[deck.size()])
		var receipt: Dictionary = visual_queue[-1]
		var entry: Dictionary = receipt.draws[-1]
		entry.placement = true
		if key != "search":
			entry.origin = origin.duplicate(true) if not origin.is_empty() else {"kind":"emblem","actor":source.actor}
			receipt.caption = "卡牌放入手牌"
		if key in ["poisoning","obstruct"]:
			var ordinal=receipt.draws.size()-1
			entry.emblem_direct=true;entry.prop_index=ordinal
			entry.start_ms=120+ordinal*260;entry.starts=[entry.start_ms];entry.durations=[1180]
			receipt.last_start=entry.start_ms;receipt.travel_ms=entry.start_ms+1180+520
		if key=="plunder":
			entry.hook_return=true;entry.start_ms=0;entry.starts=[0];entry.durations=[1450]
			receipt.travel_ms=1750;receipt.last_start=0
		if key=="gift":
			entry.origin={"kind":"gift_box","actor":target}
			entry.placement=false
			var ordinal=receipt.draws.size()-1
			entry.start_ms=100+ordinal*340;entry.starts=[entry.start_ms];entry.durations=[1120]
			receipt.last_start=entry.start_ms;receipt.travel_ms=entry.start_ms+1120+560
		return true
	# These effects currently place cards immediately. Publish only the public
	# receipt count for their sound; never the chosen/generated card identity.
	if presentation_enabled and not source.is_empty() and _info(source).key in ["gift","poisoning","obstruct","search","plunder"]:
		if not visual_queue.is_empty() and visual_queue[-1].kind == "hand_place" and visual_queue[-1].recipient == target and visual_queue[-1].action.actor == source.actor and visual_queue[-1].action.card == source.card:
			visual_queue[-1].card_count += 1
		else:
			# Keep one short display interval so burst-arriving network snapshots
			# cannot skip this receipt before the client has rendered its sound.
			_queue_visual(source,_info(source).key,target,"",{"kind":"hand_place","recipient":target,"card_count":1,"travel_ms":80,"impact_ms":0})
	return true

func _queue_placement_full(a: Dictionary, target: int) -> void:
	if not presentation_enabled: return
	# A partially successful batch keeps its original single full-hand bubble.
	# Attach the accepted receipt sound to that bubble, without another pause.
	for e in visual_queue:
		if e.kind == "hand_place" and e.recipient == target and e.action.actor == a.actor and e.action.card == a.card:
			e.merge({"kind":"pawn_speech","placed_count":e.card_count,"message":"它的手牌满了！" if a.actor != target else "我的手牌满了！","travel_ms":1900,"impact_ms":0},true)
			return
	# Multiple rejected cards in one effect produce one line, without exposing IDs.
	if visual_queue.any(func(e): return e.kind == "pawn_speech" and e.action.actor == a.actor and e.recipient == target): return
	_queue_visual(a,_info(a).key,a.actor,"",{"kind":"pawn_speech","recipient":target,
		"message":"它的手牌满了！" if a.actor != target else "我的手牌满了！","travel_ms":1900,"impact_ms":0})

func _effect_owner(key: String, dead_only: bool = false) -> int:
	for e in effects:
		if death_catalog[e.card].key == key and characters[e.owner].deathrattles.has(e.card):
			if not dead_only or characters[e.owner].hp == 0: return e.owner
	return -1

func _has_effect(key: String, target: int) -> bool:
	for e in effects:
		if (e.target == target or (key in ["greed","privilege"] and characters[e.owner].team == characters[target].team)) and death_catalog[e.card].key == key and characters[e.owner].deathrattles.has(e.card):
			return true
	return false

func _activate(a: Dictionary, target: int) -> void:
	effects = effects.filter(func(e): return e.card != a.card)
	effects.append({"card":a.card,"owner":a.actor,"target":target,"round":round_number})
	_note("%s 的%s生效，作用于 %s；失去来源牌时停止。" % [characters[a.actor].name,death_catalog[a.card].name,characters[target].name])
	_refresh_priorities()

func _bonus(actor: int) -> int:
	return 100 if _has_effect("privilege",actor) else 0

func _refresh_priorities() -> void:
	for a in queue:
		a.main = a.base_main + _bonus(a.actor)
		a.secondary = a.base_secondary + _bonus(a.actor)
	for a in death_queue: a.main = death_catalog[a.card].priority + _bonus(a.actor)

func _greed_bonus(c: Dictionary) -> int:
	if c.hp <= 0: return 0
	for e in effects:
		if death_catalog[e.card].key == "greed" and characters[e.owner].deathrattles.has(e.card) and characters[e.owner].team == c.team and e.round < round_number: return 1
	return 0

func _attack_damage(a: Dictionary, amount: int) -> int:
	if a.get("death",false) or _info(a).type != "攻击": return amount
	var c: Dictionary = characters[a.actor]
	return amount + (int(c.get("warcry_bonus",0)) if c.get("warcry_round",-1) == round_number else 0)

func play_limit(c: Dictionary) -> int:
	if c.get("silenced_round",-1) == round_number: return 0
	return (3 if c.get("overload_round",-1) == round_number else 1) + _greed_bonus(c) + (int(c.extra_count) if c.extra_round == round_number else 0) + (int(c.get("rally_count",0)) if c.get("rally_round",-1) == round_number else 0)

func _plan_cards(value) -> Array:
	if value is Dictionary: return value.get("cards",[]).duplicate()
	if value is Array: return value.duplicate()
	return [] if value == 0 else [value]

func _begin_round() -> void:
	divinity_choice_chain = false
	round_number += 1
	plans = [null,null]
	confirmed = [false,false]
	queue = []
	death_queue = []
	mirrors = []
	skipped = []
	reveal_locked_teams = [false,false]
	request = {}
	input_action = {}
	pending_attack = {}
	current_id = -1
	death_current_id = -1
	next_action_id = 1
	next_death_id = 1
	death_phase = false
	reversed_order = false
	reverse_cloth_active = false
	reverse_restore_queued = false
	reverse_after = []
	current_main = -1
	skip_death_phase = false
	early_end_team = -1
	next_forced_batch = 1
	jobs = []
	phase = "preparing"
	_announce_stage("planning")
	_note("—— 第 %d 回合：处理凋萎，再由存活棋子摸牌 ——" % round_number)
	for c in characters:
		c.revealed = false
		c.shield = 0
		c.shield_sources = []
		c.prediction = 0
		if c.hand.has(104):
			c.curse_exposed = true
			var curse := {"actor":c.id,"card":104,"death":true,"id":-1,"status":"active","environment":true}
			jobs.append({"op":"damage","a":curse,"target":c.id,"amount":3})
			jobs.append({"op":"curse_after","a":curse,"target":c.id})
	# Each held sapphire offers its extra draw, including at the hand limit.
	for c in characters:
		for id in c.hand:
			if catalog.has(id) and catalog[id].key == "sapphire": jobs.append({"op":"gem_trigger","target":c.id,"card":id})
	for c in characters: jobs.append({"op":"round_draw","target":c.id})
	jobs.append({"op":"planning"})
	revision += 1
	_pump()

func submit(team: int, choices: Array) -> String:
	if team not in [0,1] or phase != "planning": return "当前不能提交出牌。"
	if plans[team] != null: return "本回合已经锁定。"
	if choices.size() != TEAM_SIZE: return "必须为三个棋子分别选择出牌或跳过。"
	for slot in range(3):
		if not (choices[slot] is Array) and not (choices[slot] is Dictionary) and typeof(choices[slot]) != TYPE_INT: return "无效的卡牌。"
		if choices[slot] is Dictionary:
			if not (choices[slot].get("cards") is Array) or not (choices[slot].get("guards") is Dictionary): return "无效出牌数据。"
		var c: Dictionary = characters[team * 3 + slot]
		var cards := _plan_cards(choices[slot])
		if cards.size() > play_limit(c): return "该棋子本回合出牌数量超出上限。"
		var unique := {}
		for id in cards:
			if typeof(id) != TYPE_INT or c.hp == 0 or not _can_play_hand_card(c,id) or unique.has(id):
				return "棋子不能使用这张牌（请检查卡牌限制、毒药或玷污）。"
			unique[id] = true
	plans[team] = choices.duplicate(true)
	revision += 1
	if plans[0] != null and plans[1] != null:
		for t in range(2):
			for slot in range(3):
				var c: Dictionary = characters[t * 3 + slot]
				var cards := _plan_cards(plans[t][slot])
				for id in cards:
					c.hand.erase(id)
					_add_action(c.id,id)
				if c.hp == 0 and cards.is_empty() and play_limit(c) > 0 and _has_effect("ghost",c.id):
					var ghost := _add_action(c.id,_random_strike_id(c.id),true,"ghost")
					ghost.revealed = false
					_note("%s 因幽灵视为打出一张随机打击牌，次优先级 100。" % c.name)
		_note("双方已锁定，按当前优先级逐批翻牌。")
		if _announce_stage("resolution"):
			# Public action IDs identify slots; hidden card identities remain private.
			visual_queue[-1].conceal_actions = queue.filter(func(a):return not a.virtual).map(func(a):return a.id)
		var ruby_jobs: Array = []
		for c in characters:
			# Played cards have already left the hand. Growth belongs to this
			# physical card and survives transfers, discards and reshuffling.
			if c.hp > 0:
				for id in c.hand:
					if catalog.has(id) and catalog[id].key == "final_strike":
						final_strike_damage[id] = int(final_strike_damage.get(id,0))+1
			for id in c.hand:
				if catalog.has(id) and catalog[id].key == "ruby":
					ruby_jobs.append({"op":"gem_trigger","target":c.id,"card":id})
		_push(ruby_jobs+[{"op":"advance"}])
		_pump()
	return ""

func unlock(team: int) -> String:
	if team not in [0,1] or phase != "planning": return "双方已开始结算，不能取消锁定。"
	if plans[team] == null: return "当前尚未锁定。"
	if plans[1-team] != null: return "对方已锁定，不能取消锁定。"
	plans[team] = null
	revision += 1
	return ""

func _random_strike_id(actor: int = -1) -> int:
	var types: Dictionary = {}
	for id in catalog:
		if actor >= 0 and _has_poison(characters[actor]) and catalog[id].type == "攻击": continue
		if "打击" in catalog[id].name: types[catalog[id].key] = id
	var choices: Array = types.values()
	return choices[rng.randi_range(0,choices.size()-1)]

func _strike_id() -> int:
	for id in catalog:
		if catalog[id].key == "strike": return id
	return 0

func _add_action(actor: int, card: int, virtual: bool = false, origin: String = "mirror") -> Dictionary:
	var secondary: int = 100 if origin == "ghost" else (0 if virtual else catalog[card].secondary)
	var a := {"id":next_action_id,"actor":actor,"card":card,"base_main":catalog[card].main,
		"base_secondary":secondary,"main":catalog[card].main + _bonus(actor),
		"secondary":secondary + _bonus(actor),"status":"pending","target":-1,
		"revealed":virtual,"virtual":virtual,"origin":origin if virtual else "physical","discarded":false}
	if catalog[card].key == "final_strike":
		# Mirror/Ghost create a new same-name card, not the physical card's growth.
		a.damage = 0 if virtual else int(final_strike_damage.get(card,0))
	next_action_id += 1
	queue.append(a)
	return a

func _outranks(a: Dictionary, b: Dictionary) -> bool:
	return a.main > b.main or (a.main == b.main and a.secondary > b.secondary)

func _normal_before(a: Dictionary, b: Dictionary) -> bool:
	# Privilege resolves before ordinary priorities, in either direction.
	if _bonus(a.actor) != _bonus(b.actor): return _bonus(a.actor) > _bonus(b.actor)
	if a.main != b.main: return a.main < b.main if reversed_order else a.main > b.main
	return _higher(a,b)

func _higher(a: Dictionary, b: Dictionary) -> bool:
	if a.main != b.main: return a.main > b.main
	if a.secondary != b.secondary: return a.secondary > b.secondary
	return a.id < b.id

func _action(id: int) -> Dictionary:
	for a in queue:
		if a.id == id: return a
	return {}

func _death_action() -> Dictionary:
	for a in death_queue:
		if a.id == death_current_id: return a
	return {}

func _info(a: Dictionary) -> Dictionary:
	if a.get("death",false): return death_catalog[a.card]
	if catalog[a.card].key == "final_strike":
		return preload("res://scripts/card_state.gd").final_strike_info(catalog[a.card],int(a.get("damage",final_strike_damage.get(a.card,0))))
	return catalog[a.card]

func _frame(a: Dictionary) -> String:
	return ("D" if a.get("death",false) else "N") + str(a.id)

func _job(op: String, a: Dictionary, fields: Dictionary = {}) -> Dictionary:
	var j := {"op":op,"a":a,"frame":_frame(a)}
	j.merge(fields)
	return j

func _push(sequence: Array) -> void:
	jobs = sequence + jobs

func _pump() -> void:
	if pumping: return
	pumping = true
	while animation.is_empty():
		# Resolve discard reactions after the entire discard batch, before the
		# parent card continues. Newly drawn cards are not in that discard batch.
		if request.is_empty() and (not discard_triggers.is_empty() or not discard_batch_pending.is_empty()):
			var batch=discard_batch_pending.duplicate(true)
			discard_batch_pending.clear()
			_push(discard_triggers.duplicate()+([{"op":"flush_discards","batch":batch}] if not batch.is_empty() else []))
			discard_triggers.clear()
		# Complete adjacent divinity choices before replaying their draw batch.
		# Stop at gameplay boundaries such as discarding, damage or another effect.
		if divinity_choice_chain:
			if request.get("type","") == "deck": break
			if request.is_empty() and not jobs.is_empty() and jobs[0].op in ["draw","round_draw"] and visual_queue.all(func(e): return e.kind == "draw_cards"):
				_run_job(jobs.pop_front())
				continue
			divinity_choice_chain = false
		# Visual follow-ups never postpone an immediate rules effect. They replay
		# its public result before exposing the next decision (even a winning one).
		if presentation_enabled and not visual_queue.is_empty():
			# Coalesce uninterrupted draw jobs, while stopping for limits, choices,
			# damage or any other effect. Round draws still follow the rules order.
			if visual_queue[0].kind == "draw_cards":
				while request.is_empty() and not jobs.is_empty() and jobs[0].op in ["round_draw","draw"] and not _needs_collect_intro(jobs[0]) and not _needs_draw_emblem(jobs[0]):
					_run_job(jobs.pop_front())
			_show_visual(visual_queue.pop_front())
			break
		if not request.is_empty() or jobs.is_empty() or phase == "ended": break
		var job: Dictionary = jobs.pop_front()
		if presentation_enabled and _present_job(job): continue
		_run_job(job)
	pumping = false

func _needs_collect_intro(j: Dictionary) -> bool:
	var a: Dictionary = j.get("a",{})
	return j.op == "draw" and not a.is_empty() and _info(a).key == "collect" and not j.get("collect_intro_shown",false) and a.get("status","") not in ["blocked","declined","removed"]

func _needs_draw_emblem(j: Dictionary) -> bool:
	var a: Dictionary = j.get("a",{})
	return j.op == "draw" and not a.is_empty() and _info(a).key in ["emerald","legacy","spare_food","spare_supplies"] and not a.get("draw_emblem_shown",false) and a.get("status","") not in ["blocked","declined","removed"]

func _present_job(j: Dictionary) -> bool:
	if j.op in ["prepared_depart","prepared_arrive","prepared_pack","prepared_finish"]:
		if j.op=="prepared_arrive" and prepared_backpack.get("draw_seen",false):return false
		if j.op=="prepared_finish" and prepared_backpack.is_empty():return false
		if j.op=="prepared_depart":prepared_backpack={"actor":j.a.actor,"action_id":j.a.id,"stage":"depart","draw_seen":false}
		var e=_visual_event(j.a,"prepared",j.a.actor)
		e.merge({"op":j.op,"travel_ms":{"prepared_depart":2000,"prepared_arrive":3370,"prepared_pack":2880,"prepared_finish":1220}[j.op],"impact_ms":0},true)
		if j.op=="prepared_pack":e.hand_motion=_hand_motion(j.a.actor,j.values)
		animation_jobs=[j];_show_visual(e);return true
	if j.op=="flush_discards":
		if j.batch.any(func(d):return d.key in DISCARD_CARDS):
			var a=_visual_action(j.batch[0].key,j.batch[0].actor)
			var e=_visual_event(a,j.batch[0].key,j.batch[0].actor)
			e.merge({"op":"discard_finish","suite_batch":j.batch,"travel_ms":1000,"impact_ms":120},true)
			animation_jobs=[j];_show_visual(e);return true
		return false
	if j.op=="skip_death_echo":
		var a=_visual_action("skip_death",skip_death_actor)
		var e=_visual_event(a,"skip_death",skip_death_actor)
		e.merge({"op":"skip_death_echo","travel_ms":1100,"impact_ms":180},true)
		animation_jobs=[];_show_visual(e);return true
	if j.op=="elegy_pack":
		var e=_visual_event(j.a,"elegy",j.a.actor)
		e.merge({"op":"elegy_pack","hand_motion":_hand_motion(j.a.actor,j.values),"travel_ms":1800,"impact_ms":150},true)
		animation_jobs=[j];_show_visual(e);return true
	if j.op=="elegy_cost":
		if _discardable_hand(characters[j.a.actor]).size()<2:return false
		var e=_visual_event(j.a,"elegy",j.a.actor)
		e.merge({"op":"elegy_cost","travel_ms":1100,"impact_ms":100},true)
		animation_jobs=[j];_show_visual(e);return true
	if j.op == "gem_trigger": return _present_gem_job(j)
	if not j.get("a",{}).is_empty() and _info(j.a).key in PASSING_GEMS and j.op in ["heal","draw","badges"] and j.a.get("status","") not in ["blocked","declined","removed"]:
		return _present_passing_gem(j)
	if j.op == "activate" and _info(j.a).key == "divinity" and j.a.status not in ["blocked","declined","removed"]:
		_run_job(j)
		var awakening := _visual_event(j.a,"divinity",j.a.actor)
		awakening.merge({"kind":"divinity_awaken","travel_ms":2000,"impact_ms":0},true)
		animation_jobs=[];_show_visual(awakening)
		return true
	# The physical card's relocation presents these effects after ownership changes.
	if j.op in ["gem_transfer","curse_move"]: return false
	if j.op == "draw":
		if _needs_draw_emblem(j):
			j.a.draw_emblem_shown = true
			_push([j])
			var key: String = _info(j.a).key
			var intro := _visual_event(j.a,key,j.a.actor)
			intro.merge({"op":"draw_invocation","travel_ms":1500,"impact_ms":180,"card_count":j.count},true)
			if j.a.has("discard_pose"):intro.discard_pose=j.a.discard_pose.duplicate(true)
			if key == "legacy":
				intro.targets = []
				for c in characters:
					if c.team == characters[j.a.actor].team and c.hp > 0: intro.targets.append({"id":c.id,"amount":0})
			animation_jobs = [];_show_visual(intro)
			return true
		if _needs_collect_intro(j):
			# Keep the real draw queued until the printed emblem reaches the deck.
			j.collect_intro_shown = true
			_push([j])
			var intro := _visual_event(j.a,"collect",j.a.actor)
			intro.merge({"op":"collect_launch","travel_ms":1700,"impact_ms":120,"card_count":3,"caption":"收集 · 唤出三张牌"},true)
			# Public presentation metadata: interrupted draws close before a picker.
			intro.draw_mode = "blocked" if _draw_blocked(characters[j.target]) else "empty" if deck.is_empty() and discard.is_empty() else "divinity" if _effect_owner("divinity") >= 0 else "ready"
			animation_jobs = []
			_show_visual(intro)
			return true
		return false
	if j.op != "card_start" and not j.get("a",{}).is_empty() and _info(j.a).key in BASIC_CARDS+PASSING_GEMS+DISCARD_CARDS and _info(j.a).key not in CardEffectStyles.NEW_CARDS+["final_strike"]: return false
	if j.op == "card_start":
		if not resolution_presentation_enabled or j.a.get("status", "") in ["blocked","declined","removed"]: return false
		_show_card_start(j.a)
		return true
	if (CardEffectStyles.OPS.has(j.op) or CardEffectStyles.NEW_OPS.has(j.op)) and not (j.op == "activate" and _info(j.a).key == "blessing"):
		return _present_card_job(j)
	if j.op not in ["heal","shield","shield_block","cancel_card","activate","damage","judgment_miss"]: return false
	var a: Dictionary = j.get("a",{})
	if a.is_empty() or (a.get("status","") in ["blocked","declined","removed"] and j.op != "shield_block"): return false
	var attack: bool = j.op in ["damage","judgment_miss"]
	var key: String = _info(a).key
	if attack and not StrikeStyles.PROFILES.has(key) and key not in ["death_sentence","last_dance","life_steal","curse"]: return false
	if j.op == "activate" and _info(a).key != "blessing": return false
	var batch: Array = [j]
	# A team heal is one visual event, with simultaneous impact on living allies.
	if j.op == "heal":
		while not jobs.is_empty() and jobs[0].op == "heal" and jobs[0].get("frame","") == j.get("frame",""):
			batch.append(jobs.pop_front())
	elif j.op == "damage" and key in ["area_strike","precise_strike"]:
		# One sweeping visual, while _damage still runs in its original target order.
		# Immediate resurrection is evaluated after EACH target, never after the batch.
		while not jobs.is_empty() and jobs[0].op == "damage" and jobs[0].get("frame","") == j.get("frame",""):
			batch.append(jobs.pop_front())
	var targets: Array = []
	for item in batch:
		var id: int = item.get("target",a.actor)
		if j.op == "heal" and characters[id].hp == 0 and not item.get("max_bonus",0): continue
		var before: int = characters[id].hp
		if attack:
			targets.append({"id":id,"before":before,"after":before,"amount":0,"damage":_attack_damage(a,int(item.get("amount",0))),"miss":j.op == "judgment_miss"})
		else:
			var heal_blocked: bool = j.op == "heal" and before > 0 and _has_effect("blessing",id)
			if item.get("max_bonus",0) > 0:
				var new_max: int = characters[id].max_hp+item.max_bonus
				targets.append({"id":id,"before":before,"after":new_max if before > 0 and not heal_blocked else before,"amount":new_max-before if before > 0 and not heal_blocked else 0,"max_bonus":item.max_bonus,"heal_blocked":heal_blocked})
				continue
			targets.append({"id":id,"before":before,"after":before if heal_blocked else mini(characters[id].max_hp,before+item.get("amount",0)),"amount":0 if heal_blocked else mini(characters[id].max_hp-before,item.get("amount",0)),"heal_blocked":heal_blocked})
	if targets.is_empty():
		for item in batch: _run_job(item)
		return true
	animation_serial += 1
	animation_resume_phase = phase
	animation_jobs = batch
	var kind: String = "shield_block" if j.op == "cancel_card" else ("blessing" if j.op == "activate" else j.op)
	animation = {"id":animation_serial,"kind":kind,"stage":"travel","style":key,"action":a.duplicate(true),"targets":targets}
	if j.has("guard_style"): animation.guard_style = j.guard_style
	animation.merge({"travel_ms":850,"impact_ms":700,"color":preload("res://scripts/card_palette.gd").glow(key).to_html(false)})
	if kind in ["heal","shield"] and key in ["heal","defense"]:
		animation.merge({"travel_ms":850,"impact_ms":700},true)
	elif kind == "shield_block" and StrikeStyles.PROFILES.has(key):
		animation.merge({"travel_ms":StrikeStyles.PROFILES[key].travel_ms,"impact_ms":646,"color":StrikeStyles.PROFILES[key].color},true)
	if j.op == "cancel_card":
		animation.guard_target = int(a.get("guard_target",a.actor))
		animation.cancelled_style = _info(j.source).key
		animation.cancelled_actor = int(j.source.actor)
		animation.target_action = int(j.source.id)
		var amulet_timing = preload("res://scripts/amulet_timing.gd")
		animation.travel_ms = amulet_timing.TRAVEL_MS
		animation.impact_ms = amulet_timing.IMPACT_MS
		animation.affected_targets = j.get("affected_targets",[animation.guard_target]).duplicate()
		if a.get("hand_response",false):
			var hand: Array = characters[a.actor].hand
			var ordered := hand.duplicate()
			ordered.sort_custom(func(left,right):
				var ca: Dictionary = catalog.get(left,{"main":0,"secondary":0})
				var cb: Dictionary = catalog.get(right,{"main":0,"secondary":0})
				return ca.main > cb.main if ca.main != cb.main else ca.secondary > cb.secondary)
			animation.merge({"hand_response":true,"hand_index":hand.find(a.card),"owner_slot":ordered.find(a.card),"discard_ms":amulet_timing.DISCARD_MS})
	if a.has("discard_pose"):
		animation.discard_pose=a.discard_pose.duplicate(true)
		if key=="spare_food":animation.travel_ms=1050;animation.impact_ms=550
	if kind=="heal" and key=="cards_to_heart":
		animation.travel_ms=120
		animation.impact_ms=preload("res://scripts/heart_conversion_timing.gd").release_ms(int(a.get("convert_count",1)))
	if attack:
		animation.kind = "death_strike" if a.get("death",false) else "strike"
		animation.style = key
		animation.merge(CardEffectStyles.profile(key) if a.get("death",false) else StrikeStyles.PROFILES[key],true)
		if key == "last_dance": animation.caption = "终舞 · 第 %d / 5 次" % a.hits
	phase = "animating"
	revision += 1
	return true

func advance_animation() -> void:
	if animation.is_empty(): return
	if animation.get("hand_response",false) and animation.stage == "impact":
		var guard := _action(animation.action.id)
		_discard_action(guard)
		if guard.discarded:
			animation.stage = "discard"
			revision += 1
			return
	if animation.kind == "blade_volley":
		_advance_blade_volley()
		return
	if animation.get("gem_polished",false):
		_advance_polished_gem()
		return
	if animation.kind == "gem_trigger" and animation.has("return_ms"):
		_advance_healing_gem()
		return
	if animation.kind in ["card_reveal","divinity_pulse","divinity_awaken","pawn_speech","hand_place","reverse_restore"]:
		if animation.kind == "reverse_restore": reverse_cloth_active = false
		animation = {}
		animation_jobs = []
		phase = animation_resume_phase
		revision += 1
		_pump()
		return
	if animation.stage == "travel":
		phase = animation_resume_phase
		for i in range(animation_jobs.size()):
			var j: Dictionary = animation_jobs[i]
			if animation.kind in ["strike","death_strike"]:
				var result: Dictionary = animation.targets[i]
				var c: Dictionary = characters[j.target]
				var a: Dictionary = j.a
				result.blocked = not a.get("death",false) and _info(a).type == "攻击" and _has_effect("blessing",c.id)
				result.pain = not result.blocked and result.damage > 0 and c.hp == 0 and a.actor != c.id and characters[a.actor].team == c.team and _has_effect("pain",c.id)
				result.amount = 0 if result.blocked or result.miss else mini(c.hp,result.damage)
				_run_job(j)
				result.after = c.hp
				result.died = a.get("killed",false) and not result.miss and not result.blocked
				result.revived = result.died and c.hp > 0
				result.reward = animation.style if result.died and c.team != characters[a.actor].team and animation.style in ["bounty","glory"] else ""
			elif animation.kind == "card_effect":
				var result: Dictionary = animation.targets[i]
				var before := _visual_counts(result.id)
				var extra := {"count":j.get("count",1),"value":j.get("value",0),"values":j.get("values",[]),"immediate":death_phase,"prison":j.get("draw_was_blocked",false),"divinity":_effect_owner("divinity") >= 0}
				_run_job(j)
				var after := _visual_counts(result.id)
				result.label = CardEffectStyles.outcome(j.op,animation.style,before,after,extra)
				result.amount = absi(after.hand-before.hand)
				result.before = before.hp
				result.after = after.hp
				if j.op == "anticipation": animation.succeeded = reveal_locked_teams[1-characters[j.a.actor].team]
				if j.op == "lose_hp": result.amount = maxi(0,before.hp-after.hp)
				if j.op in ["discard_all","strip","curse_after"]: animation.flow = "out"
			elif animation.kind == "gem_trigger":
				var c: Dictionary = characters[j.target]
				var before: int = c.hp
				_run_job(j)
				animation.consumed = not c.hand.has(j.card)
				animation.hp_gain = c.hp-before
				if animation.style == "ruby": animation.caption = "红宝石 · 恢复 %d 点生命 · 留在手中" % (c.hp-before)
				elif animation.style == "amethyst": animation.caption = "紫宝石 · 复活至 1 点生命 · "+("弃置" if animation.consumed else "留在手中")
			else: _run_job(j)
		animation_resume_phase = phase
		phase = "animating"
		animation_jobs = []
		animation.stage = "impact"
		revision += 1
	else:
		animation = {}
		phase = animation_resume_phase
		revision += 1
		_pump()

func _show_blade_volley(a: Dictionary) -> void:
	var timing = preload("res://scripts/blade_volley_timing.gd")
	var event := _visual_event(a,"cards_to_blades",a.actor)
	event.merge({"kind":"blade_volley","stage":"travel","style":"cards_to_blades","color":"ed9bad",
		"source_hand":a.blade_source.duplicate(true),"destinations":a.blade_targets.duplicate(),"hits":[],
		"timeline_ms":0,"slice_ms":timing.arrival(0)},true)
	animation_jobs = [{"a":a}]
	_show_visual(event)

func _advance_blade_volley() -> void:
	var a: Dictionary = animation_jobs[0].a
	var index: int = animation.hits.size()
	if index >= animation.destinations.size():
		animation = {}; animation_jobs = []
		phase = animation_resume_phase
		revision += 1
		_pump()
		return
	var target: int = animation.destinations[index]
	var before: int = characters[target].hp
	var blocked: bool = not a.get("death",false) and _info(a).type == "攻击" and _has_effect("blessing",target)
	var amount := 0 if blocked else _attack_damage(a,1)
	var pain: bool = not blocked and before == 0 and a.actor != target and characters[a.actor].team == characters[target].team and _has_effect("pain",target)
	phase = animation_resume_phase
	var died := _damage(a,target,1)
	a.blade_hits += 1
	animation_resume_phase = phase
	phase = "animating"
	var timing = preload("res://scripts/blade_volley_timing.gd")
	animation.hits.append({"id":target,"before":before,"after":characters[target].hp,"amount":mini(before,amount),"died":died,"revived":died and characters[target].hp>0,"pain":pain,"blocked":blocked})
	animation.timeline_ms = timing.arrival(index)
	animation.slice_ms = timing.STEP_MS if index+1<animation.destinations.size() else timing.TAIL_MS
	animation.stage = "hit_%d" % (index+1)
	revision += 1

func _visual_counts(id: int) -> Dictionary:
	var c: Dictionary = characters[id]
	return {"hp":c.hp,"hand":c.hand.size(),"deaths":c.deathrattles.size()}

func _gem_valid(j: Dictionary) -> bool:
	var holder: Dictionary = characters[j.target]
	if not holder.hand.has(j.card) or not catalog.has(j.card) or catalog[j.card].key not in GEMS: return false
	# Amethyst explicitly triggers while dead; other hand passives require life.
	return holder.hp == 0 if catalog[j.card].key == "amethyst" else holder.hp > 0

func _advance_healing_gem() -> void:
	var c: Dictionary = characters[animation.action.actor]
	match animation.stage:
		"travel":
			# Apply HP when the gem reaches the pawn. Keep its physical card in
			# hand until the return flight has finished, including for Amethyst.
			phase = animation_resume_phase
			var before: int = c.hp
			for j in animation_jobs: _run_job(j)
			animation_jobs = []
			animation.hp_gain = c.hp-before
			animation.heal_label = "复活 · +1 生命" if animation.style == "amethyst" else "+%d 生命" % (c.hp-before)
			if animation.style == "ruby" and c.hp == before:
				animation.heal_label = "已阵亡" if before == 0 else "无法回复" if _has_effect("blessing",c.id) else "生命已满"
			animation.caption = catalog[animation.gem_card].name+" · "+animation.heal_label
			animation_resume_phase = phase
			phase = "animating"
			animation.stage = "impact"
		"impact":
			animation.stage = "return"
			animation.caption = catalog[animation.gem_card].name+" · 返回手牌"
		"return":
			if animation.style == "amethyst":
				_discard_hand_card(c,animation.gem_card)
				animation.consumed = not c.hand.has(animation.gem_card)
			if animation.consumed:
				animation.stage = "discard"
				animation.caption = "紫宝石 · 返回后弃置"
			else:
				animation = {}
				phase = animation_resume_phase
		_: # Final discard flight.
			animation = {}
			phase = animation_resume_phase
	revision += 1
	if animation.is_empty(): _pump()

func _present_gem_job(j: Dictionary) -> bool:
	if not _gem_valid(j): return false
	var c: Dictionary = characters[j.target]
	var key: String = catalog[j.card].key
	var sorted_hand: Array = c.hand.duplicate()
	sorted_hand.sort_custom(func(a,b):
		var ca: Dictionary = catalog.get(a,{"main":0,"secondary":0})
		var cb: Dictionary = catalog.get(b,{"main":0,"secondary":0})
		return ca.main > cb.main if ca.main != cb.main else ca.secondary > cb.secondary)
	# Use a canonical public card for the tooltip; the physical instance and
	# sorted owner slot are redacted from the opponent's snapshot below.
	var event := {"kind":"gem_trigger","stage":"travel","style":key,"action":_visual_action(key,c.id),"targets":[],
		"gem_card":j.card,"hand_index":c.hand.find(j.card),"owner_slot":sorted_hand.find(j.card),
		"travel_ms":1320,"impact_ms":2180,"gem_polished":true,"consumed":false,"caption":catalog[j.card].name+" · 手牌效果触发"}
	animation_jobs = [j]
	if key in ["ruby","amethyst"]:
		event.merge({"travel_ms":1520,"impact_ms":1000,"return_ms":980,"discard_ms":700},true)
		animation_jobs = [j.merged({"defer_discard":true})]
	_show_visual(event)
	return true

func _present_passing_gem(j:Dictionary)->bool:
	var key:String=_info(j.a).key
	var event:Dictionary=_visual_event(j.a,key,j.a.actor)
	event.merge({"kind":"gem_cast","gem_polished":true,"consumed":false,"travel_ms":1320 if key=="emerald" else 1520 if key=="amber" else 2360,"impact_ms":2180 if key=="emerald" else 1980 if key=="amber" else 1140},true)
	animation_jobs=[j];_show_visual(event)
	return true

func _advance_polished_gem()->void:
	var c:Dictionary=characters[animation.action.actor]
	if animation.stage=="travel":
		phase=animation_resume_phase
		var hp_before:int=c.hp
		var badge_before:int=badges[c.team]
		for j in animation_jobs:_run_job(j)
		animation_jobs=[]
		animation.hp_gain=c.hp-hp_before
		animation.badge_gain=badges[c.team]-badge_before
		# Sapphire's draw job used to wait for the entire return flight. Run
		# this one job at the magic packet's arrival; retain normal draw rules.
		if animation.style=="sapphire" and not jobs.is_empty() and jobs[0].op=="draw":
			var draw_job:Dictionary=jobs.pop_front()
			draw_job.a=animation.action.duplicate(true)
			_run_job(draw_job)
		animation_resume_phase=phase
		if animation.style in ["sapphire","emerald"] and not visual_queue.is_empty() and visual_queue[0].kind=="draw_cards":
			var receipt:Dictionary=visual_queue.pop_front()
			var overlay:Dictionary=animation.duplicate(true)
			overlay.stage="impact"
			receipt.gem_overlay=overlay
			receipt.gem_offset_ms=1320
			receipt.travel_ms=maxi(receipt.travel_ms,2460)
			_show_visual(receipt)
			return
		phase="animating";animation.stage="impact"
	elif animation.stage=="impact" and animation.has("return_ms"):
		animation.stage="return"
	elif animation.stage=="return" and animation.style=="amethyst":
		_discard_hand_card(c,animation.gem_card)
		animation.consumed=not c.hand.has(animation.gem_card)
		if animation.consumed:animation.stage="discard"
		else:animation={};phase=animation_resume_phase
	else:
		animation={};phase=animation_resume_phase
	revision+=1
	if animation.is_empty():_pump()

func _resolve_gem(j: Dictionary) -> void:
	if not _gem_valid(j): return
	var c: Dictionary = characters[j.target]
	var key: String = catalog[j.card].key
	_note("%s 手牌中的%s触发。" % [c.name,catalog[j.card].name])
	match key:
		"sapphire": _push([{"op":"draw","target":c.id,"count":1}])
		"ruby": _heal(c,1)
		"amethyst":
			_revive(c.id,1)
			if not j.get("defer_discard",false): _discard_hand_card(c,j.card)

func _visual_action(key: String, actor: int) -> Dictionary:
	for id in death_catalog:
		if death_catalog[id].key == key: return {"id":-20,"card":id,"actor":actor,"death":true,"status":"active"}
	for id in catalog:
		if catalog[id].key == key: return {"id":-20,"card":id,"actor":actor,"death":false,"status":"active"}
	return {}

func _visual_event(a: Dictionary, key: String, target: int, label: String = "") -> Dictionary:
	# Allowlist: never serialize private draw/pick options or the hidden target card.
	var public_action := {"id":a.get("id",-20),"card":a.card,"actor":a.actor,"death":a.get("death",false),"status":"active"}
	if a.has("damage"): public_action.damage = a.damage
	var e := {"kind":"card_effect","stage":"travel","action":public_action,"targets":[{"id":target,"label":label,"amount":0}],"flow":"in"}
	e.merge(CardEffectStyles.profile(key))
	e.source_key = _info(a).key
	return e

func _queue_visual(a: Dictionary, key: String, target: int, label: String, details: Dictionary = {}) -> void:
	# Pain lives on its owner; receiving draws/extra plays does not apply roses.
	if key == "pain" and target != int(a.get("actor",-1)): return
	if presentation_enabled and not a.is_empty():
		var event := _visual_event(a,key,target,label)
		event.merge(details,true)
		visual_queue.append(event)

func _show_visual(e: Dictionary) -> void:
	animation_serial += 1
	animation_resume_phase = phase
	e.id = animation_serial
	animation = e
	phase = "animating"
	revision += 1

func _card_start_event(a: Dictionary) -> Dictionary:
	return {"kind":"card_start","stage":"travel","action":a.duplicate(true),"targets":[],
		"travel_ms":200,"impact_ms":100,"caption":"开始结算"}

func _show_card_start(a: Dictionary) -> void:
	animation_jobs = []
	_show_visual(_card_start_event(a))

func _queue_card_reveal(ids: Array) -> void:
	if not presentation_enabled or not resolution_presentation_enabled: return
	# Public action IDs only. Virtual copies already appear face-up through their
	# source effect; suppressed, skipped and still-hidden cards must never flip.
	var physical: Array = ids.filter(func(id):
		var a := _action(id)
		return not a.is_empty() and a.revealed and not a.virtual)
	if physical.is_empty(): return
	visual_queue.append({"kind":"card_reveal","stage":"travel","action":{},"targets":[],
		"actions":physical,"travel_ms":680,"impact_ms":0,"caption":"卡牌翻开"})

func _hand_motion(actor: int, ids: Array) -> Dictionary:
	var hand: Array = characters[actor].hand
	var ordered: Array = hand.duplicate()
	ordered.sort_custom(func(left,right):
		var ca: Dictionary = catalog.get(left,{"main":0,"secondary":0})
		var cb: Dictionary = catalog.get(right,{"main":0,"secondary":0})
		return ca.main > cb.main if ca.main != cb.main else ca.secondary > cb.secondary)
	return {"actor":actor,"slots":ids.map(func(id):return hand.find(id)),"owner_slots":ids.map(func(id):return ordered.find(id)),"owner_cards":ids.duplicate()}

func _gold_discards(j: Dictionary) -> Array:
	var c: Dictionary = characters[j.a.actor]
	return c.hand.filter(func(id):return not j.before.has(id) and catalog.has(id) and (catalog[id].main+_bonus(c.id)) in [3,4,5,6] and _can_discard_hand_card(c,id))

func _present_card_job(j: Dictionary) -> bool:
	var a: Dictionary = j.get("a",{})
	if a.is_empty() or a.get("status","") in ["blocked","declined","removed"]: return false
	if j.op == "life_after" and not (a.get("killed",false) and characters[j.target].team != characters[a.actor].team and characters[a.actor].hp == 0): return false
	if j.op == "curse_after" and not a.get("killed",false): return false
	var key: String = _info(a).key
	if not CardEffectStyles.PROFILES.has(key): return false
	var target: int = a.actor if j.op == "life_after" else int(j.get("target",a.actor))
	if j.op in ["poisoning","obstruct"] or (key=="feign" and j.op=="feign"):return false
	var e := _visual_event(a,key,target)
	e.op = j.op
	if key in CardEffectStyles.NEW_CARDS:
		e.travel_ms = 1450
		e.impact_ms = 420
		if key=="bloodletting" and j.op=="lose_hp":e.travel_ms=1200;e.impact_ms=2600
		if j.op in ["gold_begin","defile"]: e.travel_ms = 1250;e.impact_ms = 160
		if j.op=="search":e.travel_ms=preload("res://scripts/search_compass_pose.gd").TRAVEL_MS;e.impact_ms=preload("res://scripts/search_compass_pose.gd").IMPACT_MS
		if j.op in ["gift_transfer","obstruct","poisoning"]: e.impact_ms = 100
		if j.op == "anticipation":
			e.impact_ms=950
			e.targets = characters.filter(func(c):return c.team != characters[a.actor].team).map(func(c):return {"id":c.id,"amount":0})
		if j.op == "rally":
			e.targets = characters.filter(func(c):return c.team == characters[a.actor].team and c.hp > 0).map(func(c):return {"id":c.id,"amount":0})
		if e.targets.is_empty(): return false
		var selected: Array = []
		var motion_actor: int = a.actor
		if j.op == "convert_hand": selected = _discardable_hand(characters[a.actor])
		elif j.op == "frenzy": selected = characters[a.actor].hand.filter(func(id):return _can_play_hand_card(characters[a.actor],id))
		elif j.op == "gold_filter": selected = _gold_discards(j)
		elif j.op == "defile_seal": selected = [j.value];motion_actor = j.target
		if j.op in ["convert_hand","frenzy","gold_filter","defile_seal"]:
			e.hand_motion = _hand_motion(motion_actor,selected)
			e.travel_ms = 1550+maxi(0,selected.size()-1)*110
			if selected.is_empty(): e.travel_ms = 750
			if key=="cards_to_heart":
				e.travel_ms=preload("res://scripts/heart_conversion_timing.gd").gather_ms(selected.size());e.impact_ms=120
		if j.op == "gift_transfer":
			e.placed_count=mini(j.values.size(),HAND_LIMIT-characters[target].hand.size())
			e.hand_motion=_hand_motion(a.actor,j.values);e.gift_target=target
			e.travel_ms=2950;e.impact_ms=2000
		if j.op in ["poisoning","obstruct"]: e.placed_count = mini(1 if j.op == "poisoning" else 2,HAND_LIMIT-characters[target].hand.size())
	if j.op == "activate" and key in ["greed","privilege"]:
		e.targets = []
		for c in characters:
			if c.team == characters[a.actor].team: e.targets.append({"id":c.id,"label":"下回合起额外摸1张、出1张" if key == "greed" else "优先级 +100","amount":0})
	# Only counts, published targets and outcome modes enter the animation.
	# Hidden draw/discard identities and private picker options stay on the host.
	e.card_count = j.values.size() if j.op=="gift_transfer" else int(j.get("count",1))
	if j.op == "draw":
		e.card_count = mini(e.card_count,deck.size()+discard.size())
		e.draw_mode = "blocked" if _draw_blocked(characters[target]) else "empty" if e.card_count == 0 else "divinity" if _effect_owner("divinity") >= 0 else "ready"
	if j.op == "draw_death": e.card_count = mini(1,death_deck.size())
	if j.op == "plunder": e.card_count = mini(1,characters[target].hand.size())
	if j.op == "discard_all": e.card_count = _discardable_hand(characters[target]).size()
	if j.op in ["strip","curse_after"]: e.card_count = characters[target].deathrattles.filter(func(id): return id != 120).size()
	if j.op in ["draw","draw_death","plunder","discard_all","strip","curse_after","curse_move"]:
		e.travel_ms = 1250 if e.card_count > 3 else 1000
	if key=="gambler" and j.op=="discard_all":e.travel_ms=2200
	if j.op == "life_after": e.drain_source = int(j.target)
	if j.op == "chosen":
		e.value = int(j.value)
		if j.has("values"): e.values = j.values.duplicate()
	if j.op == "reverse":
		e.reverse_from = reversed_order
		e.cloth_was_active = reverse_cloth_active
	if j.has("reward_source") and key in ["bounty","glory"]:
		# Only public victim identity and counts leave the server. Drawn card IDs
		# and any choices made by Divinity remain in their normal private channel.
		e.reward_source = int(j.reward_source)
		e.reward_count = int(j.count)
		e.reward_mode = "ready"
		e.travel_ms = 650
		e.impact_ms = 600
		if key == "bounty":
			e.reward_count = mini(int(j.count),deck.size()+discard.size())
			if _draw_blocked(characters[target]): e.reward_mode = "blocked"
			elif e.reward_count == 0: e.reward_mode = "empty"
			elif _effect_owner("divinity") >= 0: e.reward_mode = "divinity"
	if j.op == "life_after": e.motif = "revive"
	if j.op in ["strip","curse_after"]: e.motif = "shatter"
	if j.op == "discard_all": e.flow = "out"
	if j.op == "plunder": e.flow = "steal"
	if j.op == "chosen" and key in ["mirror","suppress","late_suppress"]:
		var selected := _action(j.value)
		e.targets[0].id = selected.actor
		e.target_action = selected.id
	if key in ["defile","plunder"]:
		e.travel_ms=1150 if j.op in ["defile","plunder"] else 1350
		e.impact_ms=140
	if key=="feign" and j.op=="lose_hp":e.travel_ms=1100;e.impact_ms=520
	if key=="elegy" and j.op=="draw_death":
		e.travel_ms=2200;e.impact_ms=240;e.death_slot=_death_display(characters[a.actor]).size()
	animation_jobs = [j]
	_show_visual(e)
	return true

func _advance() -> void:
	_push([{"op":"advance"}])
	_pump()

func _advance_death() -> void:
	_advance()

func _announce_stage(stage: String, main: int = -1) -> bool:
	if turn_stage == stage and stage_main == main: return false
	var changed := turn_stage != stage
	turn_stage = stage
	stage_main = main
	if not presentation_enabled or not stage_presentation_enabled: return false
	visual_queue.append(_stage_event(stage,main,changed))
	return true

func _stage_event(stage: String, main: int, changed: bool) -> Dictionary:
	var title: String = {"start":"游戏开始","planning":"出牌阶段","resolution":"结算阶段","death":"亡语阶段"}[stage]
	return {"kind":"phase_change","stage":"travel","action":{},"targets":[],
		"turn_stage":stage,"main":main,"announce":changed,"travel_ms":1500 if changed else 1050,"impact_ms":100,
		"caption":title+(" · 主优先级 %d" % main if main >= 0 else "")}

func _advance_step() -> void:
	current_id = -1
	death_current_id = -1
	_refresh_priorities()
	if death_phase and not skip_death_phase:
		var pending_deaths := death_queue.filter(func(a): return a.status == "pending")
		pending_deaths.sort_custom(_higher)
		if not pending_deaths.is_empty():
			var a: Dictionary = pending_deaths[0]
			death_current_id = a.id
			_start_effect(a)
			return
	var pending := queue.filter(func(a): return a.status == "pending")
	for group in reverse_after.duplicate():
		if not pending.any(func(a): return a.main == group):
			reversed_order = not reversed_order
			reverse_after.erase(group)
			_note("普通牌主优先级顺序反转：%s；同主优先级仍按次优先级从高到低。" % ("由低到高" if reversed_order else "由高到低"))
	pending.sort_custom(_normal_before)
	if pending.is_empty():
		if not death_phase and turn_stage != "resolution" and _announce_stage("resolution"):
			_push([{"op":"advance"}])
			return
		if death_phase: _finish_deaths()
		else: _finish_round()
		return
	var a: Dictionary = pending[0]
	if characters[a.actor].team == early_end_team:
		a.status = "declined"
		_push([{"op":"advance"}])
		return
	if characters[a.actor].hp == 0 and not a.virtual:
		a.status = "cancelled"
		_push([{"op":"advance"}])
		return
	current_main = a.main
	if not death_phase and _announce_stage("resolution",current_main):
		_push([{"op":"advance"}])
		return
	if not a.revealed:
		_push([{"op":"advance"}])
		if skipped.has(a.main):
			for other in pending:
				if other.main == a.main and not other.revealed: other.status = "skipped"
			_note("跳过主优先级 %d。" % a.main)
		else: _reveal_group(a.main)
		return
	current_id = a.id
	_start_effect(a)

func _reveal_group(main: int) -> void:
	var flipped: Array = []
	for a in queue:
		if a.status == "pending" and not a.revealed and a.main == main:
			if reveal_locked_teams[characters[a.actor].team]:
				a.status = "suppressed"
				continue
			if characters[a.actor].hp == 0 and not a.virtual:
				a.status = "cancelled"
				continue
			a.revealed = true
			characters[a.actor].revealed = true
			flipped.append(a.id)
	_note("主优先级 %d：同批牌翻开，按次优先级从高到低结算。" % main)
	_queue_card_reveal(flipped)
	for id in flipped: _mirror_flip(id)
	_push(_flip_windows())

func _flip_windows() -> Array:
	var revealed := queue.filter(func(a): return a.status == "pending" and a.revealed and not a.get("flip_checked",false))
	revealed.sort_custom(_higher)
	var sequence: Array = []
	for a in revealed:
		a.flip_checked = true
		sequence.append(_job("responses",a,{"mode":"reveal","targets":[],"passed":[]}))
	return sequence

func _mirror_flip(id: int) -> void:
	for link in mirrors:
		if link.target == id:
			if reveal_locked_teams[characters[link.actor].team]:
				_note("预判封锁：魔镜不能再打出并翻开复制牌。")
				continue
			var original := _action(id)
			if _has_poison(characters[link.actor]) and catalog[original.card].type == "攻击":
				_note("毒药：魔镜不能打出攻击牌的复制牌。")
				continue
			_add_action(link.actor,original.card,true)
			characters[link.actor].revealed = true
			_note("魔镜触发：%s 打出并翻开 %s 的复制牌，次优先级 0。" % [characters[link.actor].name,catalog[original.card].name])
			_queue_visual(_visual_action("mirror",link.actor),"mirror",link.actor,"复制牌已翻开",{"copied_key":catalog[original.card].key})

func _start_effect(a: Dictionary, continuation: Dictionary = {}) -> void:
	a.status = "active"
	if a.get("origin","") == "ghost": _queue_visual(_visual_action("ghost",a.actor),"ghost",a.actor,"幽灵 · 代为打出"+_info(a).name)
	_note("%s 结算%s %s [%d]。" % [characters[a.actor].name,"亡语" if a.get("death",false) else "普通牌",_info(a).name,a.main])
	var sequence: Array = _effects_for(a)
	var targets := _automatic_targets(a)
	if not targets.is_empty(): sequence.push_front(_job("responses",a,{"mode":"target","targets":targets,"passed":[]}))
	sequence.push_front(_job("card_start",a))
	sequence.append(_job("complete",a))
	sequence.append({"op":"advance"} if continuation.is_empty() else continuation)
	_push(sequence)

func _automatic_targets(a: Dictionary) -> Array:
	if a.get("death",false): return []
	var key: String = _info(a).key
	if key in ["team_heal","rally"]: return characters.filter(func(c): return c.team == characters[a.actor].team and c.hp > 0).map(func(c): return c.id)
	if key == "area_strike": return characters.filter(func(c): return c.team != characters[a.actor].team and c.hp > 0).map(func(c): return c.id)
	if key == "defense": return []
	if key == "anticipation": return characters.filter(func(c): return c.team != characters[a.actor].team).map(func(c): return c.id)
	if key in ["collect","gambler","heal","overload","elegy","feign","badge","warcry","cards_to_heart","cards_to_blades","frenzy","bloodletting","gold_panning","search","poison","prepared"]: return [a.actor]
	return []

func _effects_for(a: Dictionary) -> Array:
	var actor: Dictionary = characters[a.actor]
	var key: String = _info(a).key
	if a.get("death",false):
		match key:
			"blood_rite":
				var seq: Array = []
				for c in characters:
					if c.team == actor.team: seq.append(_job("heal",a,{"target":c.id,"amount":c.max_hp+2,"max_bonus":2}))
				return seq
			"legacy":
				var seq: Array = []
				for c in characters:
					if c.team == actor.team and c.hp > 0:
						seq.append(_job("legacy_discard",a,{"target":c.id}))
						seq.append(_job("legacy_refill",a,{"target":c.id}))
				return seq
			"ghost","pain","eye","divinity","greed","privilege": return [_job("activate",a,{"target":a.actor})]
			"sacrifice_badges":
				if characters.any(func(c): return c.id != actor.id and c.team == actor.team and c.hp > 0):
					return [_job("badges",a,{"count":2})]
				_note("%s 的取义未生效：没有存活的队友。" % actor.name)
				return []
			_: return [_job("ask_death",a)]
	match key:
		"poison": return [_job("lose_hp",a,{"target":a.actor,"amount":1})]
		"reverse": return [_job("reverse",a)]
		"skip_death": return [_job("skip_death",a)]
		"badge": return [_job("badges",a,{"count":1})]
		"overload": return [_job("overload",a)]
		"elegy": return [_job("elegy_cost",a)]
		"feign": return [_job("lose_hp",a,{"target":a.actor,"amount":2}),_job("feign",a)]
		"collect": return [_job("draw",a,{"target":a.actor,"count":3})]
		"prepared": return [_job("prepared_depart",a),_job("draw",a,{"target":a.actor,"count":2}),_job("prepared_arrive",a),_job("discard_choice",a,{"target":a.actor,"count":2}),_job("prepared_finish",a)]
		"gambler": return [_job("discard_all",a,{"target":a.actor}),_job("fill_hand",a)]
		"bloodletting": return [_job("lose_hp",a,{"target":a.actor,"amount":1}),_job("draw",a,{"target":a.actor,"count":5})]
		"gold_panning": return [_job("gold_begin",a)]
		"search": return [_job("search",a)]
		"rally": return [_job("rally",a)]
		"warcry": return [_job("warcry",a)]
		"anticipation": return [_job("anticipation",a)]
		"gift": return [_job("gift_begin",a)]
		"cards_to_heart","cards_to_blades": return [_job("convert_hand",a)]
		"frenzy": return [_job("lose_hp",a,{"target":a.actor,"amount":2}),_job("frenzy",a)]
		"prophecy": return [_job("ask",a,{"kind":"number","options":[1,2,3,4,5,6,7,8,9,10],"description":"预言结算结束时的生命值（1～10）"})]
		"ignore": return [_job("ask",a,{"kind":"number","options":[0,1,2,3,4,5,6],"description":"忽视：选择第一个要跳过的主优先级（共2个，0～6）"})]
		"mirror","suppress","late_suppress":
			var options: Array = []
			for other in queue:
				if other.revealed or other.get("suppression_attempt",false): continue
				if key == "mirror" and characters[other.actor].team == actor.team: continue
				# Reversal or bonus plays can leave an amulet facedown. Preserve
				# its suppression immunity without disclosing it before its reveal.
				var hidden_amulet: bool = key in ["suppress","late_suppress"] and _info(other).key in AMULETS
				if other.status in ["pending","held"] and (_outranks(a,other) or hidden_amulet): options.append(other.id)
			var description := "选择一张敌方打出的、尚未翻开的普通牌" if key == "mirror" else "选择一张尚未翻开的普通牌"
			return [_job("ask",a,{"kind":"card","options":options,"description":description})]
		"defense": return [_job("ask_normal",a)]
		"heal": return [_job("heal",a,{"target":a.actor,"amount":2})]
		"team_heal":
			var seq: Array = []
			for c in characters:
				if c.team == actor.team: seq.append(_job("heal",a,{"target":c.id,"amount":1}))
			return seq
		"area_strike":
			var seq: Array = []
			for c in characters:
				if c.team != actor.team and c.hp > 0: seq.append(_job("damage",a,{"target":c.id,"amount":1}))
			return seq
		_: return [_job("ask_normal",a)]

func _run_job(j: Dictionary) -> void:
	var a: Dictionary = j.get("a",{})
	if not a.is_empty() and a.get("status","") in ["blocked","declined","removed"] and j.op != "complete": return
	match j.op:
		"card_start": pass
		"flush_discards":
			for d in j.batch:
				if catalog.has(d.card):discard.append(d.card)
				else:death_discard.append(d.card)
				staged_discards=staged_discards.filter(func(v):return v.card!=d.card)
		"release_blade_discards":
			# Paid discard costs survive skipping/cancelling the parent card. This
			# independent job runs after the volley (or immediately after a skip).
			for d in j.batch: d.erase("blade_pending")
			discard_triggers.append_array(j.triggers)
			discard_batch_pending.append_array(j.batch)
		"skip_death_echo":pass
		"finish_skipped_deaths":_finish_deaths()
		"elegy_pack":
			for id in j.values:_discard_hand_card(characters[a.actor],id)
			_push([_job("draw_death",a)])
		"discard_passive":
			if characters[j.target].hp <= 0: return
			var card: Dictionary = catalog[j.card]
			var source := {"id":-20,"card":j.card,"actor":j.target,"death":false,"status":"active"}
			for d in staged_discards:
				if d.card==j.card:source.discard_pose=d.duplicate(true);d.spent=true
			_note("%s 弃置%s，触发弃牌效果。" % [characters[j.target].name,card.name])
			if card.discard_effect == "heal": _push([_job("heal",source,{"target":j.target,"amount":2})])
			elif card.discard_effect == "draw": _push([_job("draw",source,{"target":j.target,"count":int(card.get("discard_count",2))})])
		"hand_limit":
			var c: Dictionary = characters[j.target]
			var excess: int = c.hand.size()-HAND_LIMIT
			if excess > 0:
				var eligible := _discardable_hand(c)
				if eligible.is_empty():
					_note("%s 的手牌均不可弃置，保留超出上限的手牌。" % c.name)
					return
				excess = mini(excess,eligible.size())
				var resume := phase
				_prompt({},"hand_limit",eligible,"%s：手牌上限 %d，请弃置 %d 张手牌" % [c.name,HAND_LIMIT,excess],c.team,false)
				request.target = c.id
				request.count = excess
				request.resume_phase = resume
		"prepared_depart":
			if presentation_enabled:prepared_backpack.stage="chest"
		"prepared_arrive":
			if presentation_enabled:prepared_backpack.stage="hand"
		"prepared_pack":
			prepared_backpack.clear()
			for id in j.values:_discard_hand_card(characters[a.actor],id)
			_note("%s：%s 弃置 %d 张手牌。" % [_info(a).name,characters[a.actor].name,j.values.size()])
		"prepared_finish":prepared_backpack.clear()
		"discard_choice":
			var c: Dictionary = characters[j.target]
			var eligible := _discardable_hand(c)
			var count := mini(int(j.count),eligible.size())
			if count == 0:
				_note("%s：没有可弃置的手牌。" % _info(a).name)
			else:
				# Do not allow skipping a required discard after receiving the draw.
				_prompt(a,"discard",eligible,"%s：选择并弃置 %d 张手牌（不可弃置的牌保留）。" % [_info(a).name,count],c.team,false)
				request.count = count
				request.target = c.id
		"elegy_cost":
			var c: Dictionary = characters[a.actor]
			var eligible := _discardable_hand(c)
			if eligible.size() < 2:
				_note("%s 的悲歌因可弃置手牌不足两张，未弃牌且未获得亡语。" % c.name)
			else:
				_prompt(a,"elegy",eligible,"悲歌：选择并弃置两张手牌，再摸一张亡语牌（不可弃置的牌保留）",c.team,true)
				request.count = 2
				request.target = a.actor
		"chosen":
			match _info(a).key:
				"prophecy":
					characters[a.actor].prediction = j.value
					_note("%s 预言结算结束时生命为 %d。" % [characters[a.actor].name,j.value])
				"ignore":
					for value in j.values:
						if not skipped.has(value): skipped.append(value)
					_note("本回合跳过主优先级 %d、%d。" % [j.values[0],j.values[1]])
				"mirror": mirrors.append({"actor":a.actor,"target":j.value})
				"suppress","late_suppress":
					var selected := _action(j.value)
					selected.suppression_attempt = true
					selected.suppression_key = _info(a).key
					if _info(selected).key not in AMULETS: selected.status = "suppressed"
					_note("%s 已对指定暗牌施放压制。" % _info(a).name)
		"responses": _responses(j)
		"cancel_card":
			var source: Dictionary = j.source
			if source.status in ["pending","active","held"]:
				source.status = "blocked"
				source.burned_by_amulet = _info(a).key
				var frame := _frame(source)
				jobs = jobs.filter(func(job): return job.get("frame","") != frame or job.op == "complete")
				_note("%s 翻开%s，取消%s的全部效果。" % [characters[a.actor].name,_info(a).name,_info(source).name])
		"normal_target": _normal_target(a,j.target)
		"reverse":
			reverse_cloth_active = true
			if death_phase:
				reversed_order = not reversed_order
				_note("扭转乾坤：亡语阶段立刻反转普通牌主优先级顺序。")
			else:
				reverse_after.append(a.get("release_group",a.main))
				_note("扭转乾坤：当前主优先级结算结束后反转顺序。")
		"skip_death":
			skip_death_phase = true
			skip_death_actor=a.actor
			for event in death_queue:
				if event.status == "pending" and not event.has("forced_batch"): event.status = "returned"
			_note("戏命：跳过本回合正常亡语阶段，未结算亡语保留，不自动延至下回合。")
		"overload": characters[a.actor].overload_round = round_number + 1
		"fill_hand":
			var count: int = maxi(0,HAND_LIMIT-characters[a.actor].hand.size())
			if count > 0: _push([_job("draw",a,{"target":a.actor,"count":count})])
		"legacy_discard":
			var c: Dictionary = characters[j.target]
			if c.hp <= 0: return
			var eligible := _discardable_hand(c)
			if not eligible.is_empty():
				_prompt(a,"discard",eligible,"遗产：%s 可弃置任意张手牌，之后摸牌至手牌上限" % c.name,c.team,false)
				request.target = c.id
				request.count = eligible.size()
				request.min_count = 0
		"legacy_refill":
			# Discard passives resolve first; calculate free slots afterwards.
			var c: Dictionary = characters[j.target]
			if c.hp <= 0: return
			var count: int = maxi(0,HAND_LIMIT-c.hand.size())
			if count > 0: _push([_job("draw",a,{"target":c.id,"count":count})])
		"gold_begin":
			# Keep the gained IDs in a private job. Only these cards are filtered.
			_push([_job("draw",a,{"target":a.actor,"count":5}),_job("gold_filter",a,{"before":characters[a.actor].hand.duplicate()})])
		"gold_filter":
			var c: Dictionary = characters[a.actor]
			var removed := 0
			for id in _gold_discards(j):
				_discard_hand_card(c,id)
				removed += 1
			_note("淘金：新摸到的牌中有 %d 张主优先级为 3～6 的牌被弃置。" % removed)
		"search":
			# Selecting from the current pile is a gain, not a draw or reshuffle.
			if deck.is_empty(): _note("搜寻：抽牌堆为空，未获得卡牌。")
			else:
				_prompt(a,"search",deck.duplicate(),"搜寻：从抽牌堆中选择一张牌加入手牌",characters[a.actor].team,true)
				request.count = 1
				request.target = a.actor
		"rally":
			for c in characters:
				if c.team != characters[a.actor].team or c.hp <= 0: continue
				if c.get("rally_round",-1) != round_number+1: c.rally_count = 0
				c.rally_round = round_number+1
				c.rally_count += 1
			_note("摇旗：存活的友方棋子下回合各增加一次出牌机会。")
		"gem_transfer": _transfer_gem(a,j.target)
		"gem_trigger": _resolve_gem(j)
		"death_queue_begin":
			if not skip_death_phase:
				for c in characters:
					if c.hp == 0 and c.death_round == round_number: _enqueue_deaths(c)
			_advance_death()
		"defile":
			var hand: Array = characters[j.target].hand
			if hand.is_empty(): _note("玷污：目标没有手牌。")
			else:
				_prompt(a,"defile",hand.duplicate(),"玷污：查看目标全部手牌，选择一张使其不能打出或弃置",characters[a.actor].team,true)
				request.count = 1
				request.target = j.target
		"defile_seal":
			if characters[j.target].hand.has(j.value):
				defiled_cards[j.value] = true
				_note("玷污：%s 的一张手牌已被封锁，不能打出或弃置。" % characters[j.target].name)
		"poisoning":
			if _put_in_hand(j.target,_generate_card(POISON),a):
				_note("下毒：%s 的手牌中加入一张毒药。" % characters[j.target].name)
		"obstruct":
			var placed := 0
			for _i in range(2):
				if _put_in_hand(j.target,_generate_card(BOULDER),a): placed += 1
			_note("阻碍：%s 的手牌中加入 %d 张巨石。" % [characters[j.target].name,placed])
		"warcry":
			var c: Dictionary = characters[a.actor]
			if c.get("warcry_round",-1) != round_number+1: c.warcry_bonus = 0
			c.warcry_round = round_number+1
			c.warcry_bonus += 3
			_note("%s 下回合攻击牌伤害增加 %d。" % [c.name,c.warcry_bonus])
		"anticipation": _anticipation(a)
		"gift_begin":
			if characters[a.actor].hand.is_empty():
				_note("馈赠：没有可转交的手牌。")
			else:
				_ask(a,"character",characters.filter(func(c): return c.id != a.actor).map(func(c): return c.id),"馈赠（1/2）：先点击金色边框的接收棋子，再选至多两张牌。")
		"gift_transfer":
			var source: Dictionary = characters[a.actor]
			if j.values.is_empty() or j.values.size() > 2 or not j.values.all(func(id): return source.hand.has(id)):
				_note("馈赠：所选手牌已变化，未转移。")
			else:
				var placed := 0
				var motion := _hand_motion(a.actor,j.values)
				for id in j.values:
					var index: int = j.values.find(id)
					var origin := {"kind":"hand","actor":a.actor,"slot":motion.slots[index],"owner_slot":motion.owner_slots[index]}
					source.hand.erase(id)
					if _put_in_hand(j.target,id,a,origin): placed += 1
					if id == 104:
						source.curse_exposed = false
						characters[j.target].curse_exposed = false
				_note("馈赠：%s 按选择顺序向%s放入 %d 张手牌，%d 张因手牌已满而弃置。" % [source.name,characters[j.target].name,placed,j.values.size()-placed])
		"convert_hand":
			var c: Dictionary = characters[a.actor]
			var count := _discardable_hand(c).size()
			var trigger_start := discard_triggers.size()
			var batch_start := discard_batch_pending.size()
			if _info(a).key == "cards_to_blades":
				var ordered: Array = c.hand.duplicate()
				ordered.sort_custom(func(left,right):
					var ca: Dictionary = catalog.get(left,{"main":0,"secondary":0})
					var cb: Dictionary = catalog.get(right,{"main":0,"secondary":0})
					return ca.main > cb.main if ca.main != cb.main else ca.secondary > cb.secondary)
				var eligible: Array = ordered.filter(func(id):return _can_discard_hand_card(c,id))
				a.blade_source = {"count":c.hand.size(),"owner_hand":ordered,"slots":eligible.map(func(id):return c.hand.find(id)),"owner_slots":eligible.map(func(id):return ordered.find(id))}
				a.blade_targets = []
			_discard_hand(c)
			a.convert_count = count
			if _info(a).key == "cards_to_heart":
				if count > 0: _push([_job("heal",a,{"target":a.actor,"amount":count})])
			else:
				a.blade_hits = 0
				# Keep the original hand visible through the blade preparation and
				# morph. Supplies/food react only after all blades have landed, and
				# their newly drawn cards never enter this fixed conversion batch.
				var triggers := discard_triggers.slice(trigger_start)
				var batch := discard_batch_pending.slice(batch_start)
				discard_triggers.resize(trigger_start)
				discard_batch_pending.resize(batch_start)
				for d in batch: d.blade_pending = true
				_push([_job("blade_next",a),{"op":"release_blade_discards","batch":batch,"triggers":triggers}])
			if count == 0: _note("%s：没有可弃置的手牌，不产生回复或伤害。" % _info(a).name)
		"blade_next":
			if a.blade_targets.is_empty() and a.convert_count > 0:
				_ask(a,"character",characters.map(func(c): return c.id),"化牌为刃：选择一个棋子，全部 %d 把刀依次对其造成1点伤害。" % a.convert_count)
			elif a.convert_count > 0:
				_push([_job("responses",a,{"mode":"target","targets":[a.target],"passed":[]}),_job("normal_target",a,{"target":a.target})])
		"blade_volley":
			if presentation_enabled: _show_blade_volley(a)
			else:
				for target_id in a.blade_targets:
					_damage(a,target_id,1)
					a.blade_hits += 1
		"frenzy":
			var c: Dictionary = characters[a.actor]
			var cards: Array = c.hand.filter(func(id): return _can_play_hand_card(c,id))
			_play_revealed_hand(c.id,cards,"疯狂")
			if cards.is_empty(): _note("疯狂：没有可打出的普通手牌。")
		"silence": characters[j.target].silenced_round = round_number + 1
		"draw_death":
			if death_deck.is_empty(): _note("亡语牌库已空，悲歌未摸到牌。")
			else:
				characters[a.actor].deathrattles.append(death_deck.pop_back())
				_note("%s 摸到一张亡语牌（仅己方可见）。" % characters[a.actor].name)
		"feign":
			var batch := next_forced_batch
			next_forced_batch += 1
			# Immortal is an immediate card, not a queued persistent activation.
			if characters[a.actor].hp == 0: _try_immortal(a.actor)
			_enqueue_deaths(characters[a.actor],batch)
			_push([{"op":"forced_next","batch":batch,"resume_normal":current_id,"resume_death":death_current_id}])
		"forced_next": _forced_next(j)
		"peek":
			_prompt(a,"inspect",[],"窥探：查看 %s 的当前手牌和亡语牌；查看后继续结算" % characters[j.target].name,characters[a.actor].team,false)
			request.cards = characters[j.target].hand.duplicate()
			request.deaths = characters[j.target].deathrattles.duplicate()
			request.count = 0
			request.target = j.target
		"plunder":
			var hand: Array = characters[j.target].hand
			if hand.is_empty(): _note("目标没有手牌，掠夺未获得卡牌。")
			else:
				_prompt(a,"plunder",hand.duplicate(),"掠夺：查看目标全部手牌，选择一张加入自己的手牌。",characters[a.actor].team,true)
				request.count = 1
				request.target = j.target
		"glory":
			if a.get("killed",false) and characters[j.target].team != characters[a.actor].team:
				_push([_job("badges",a,{"count":1,"reward_source":j.target})])
		"advance": _advance_step()
		"planning": phase = "planning"; revision += 1
		"round_draw":
			if characters[j.target].hp > 0:
				_push([{"op":"draw","target":j.target,"count":1+_greed_bonus(characters[j.target])}])
		"complete":
			if a.get("death",false): _complete_death(a)
			else: _complete(a)
		"ask": _ask(a,j.kind,j.options,j.description)
		"ask_normal":
			var options: Array = []
			var key: String = _info(a).key
			for c in characters:
				var allowed: bool = key != "godslayer" or c.revealed
				if key in ["peek","silence"]: allowed = true
				if key == "raise_dead": allowed = c.hp == 0
				if key == "heal_other": allowed = c.hp > 0 and c.id != a.actor
				if key in PASSING_GEMS: allowed = c.hp > 0 and c.team != characters[a.actor].team
				if allowed: options.append(c.id)
			_ask(a,"character",options,_target_description(a))
		"ask_death": _ask_death(a)
		"damage": _damage(a,j.target,j.amount)
		"lose_hp": _damage(a,j.target,j.amount,true)
		"heal":
			var c: Dictionary = characters[j.target]
			c.max_hp += int(j.get("max_bonus",0))
			if j.get("max_bonus",0) > 0: _note("%s 的生命上限增加 2，当前上限 %d。" % [c.name,c.max_hp])
			_heal(c,j.amount)
		"draw": _draw_job(j)
		"discard_all": _discard_hand(characters[j.target])
		"discard_one":
			var eligible := _discardable_hand(characters[j.target])
			if not eligible.is_empty():
				_prompt(a,"hand",eligible,"贪婪：%s 选择并弃置一张手牌（不可弃置的牌保留）" % characters[j.target].name,characters[j.target].team,false)
				request.count = 1
				request.target = j.target
			elif not characters[j.target].hand.is_empty():
				_note("%s 没有可弃置的手牌，全部保留。" % characters[j.target].name)
		"shield":
			var target_id: int = j.get("target",a.actor)
			characters[target_id].shield += 1
			characters[target_id].shield_sources.append(a.actor)
			_note("%s 为%s施加本回合一次单体攻击防御，由出牌方决定使用。" % [characters[a.actor].name,characters[target_id].name])
		"shield_block": pass # Presentation only; cancellation was already recorded.
		"judgment_miss": pass # Makes an unsuccessful judgment visible without damage.
		"bounty":
			if a.get("killed",false) and characters[j.target].team != characters[a.actor].team:
				_push([_job("draw",a,{"target":a.actor,"count":2,"reward_source":j.target})])
		"dance_hit":
			# All targets are fixed before the first hit. Keep each impact as a
			# normal damage job so immediate revivals and reactions retain order.
			a.hits = j.hit
			a.target = j.target
			_push([_job("damage",a,{"target":j.target,"amount":1})])
		"revive": _revive(j.target,j.get("hp",5))
		"life_after":
			if a.get("killed",false) and characters[j.target].team != characters[a.actor].team and characters[a.actor].hp == 0:
				_revive(a.actor,5)
		"activate": _activate(a,j.target)
		"strip": _strip_deaths(j.target)
		"curse_after":
			if a.get("killed",false): _strip_deaths(j.target)
		"curse_move":
			_move_death_to_hand(a,j.target)
		"heart":
			var c: Dictionary = characters[j.target]
			if c.extra_round != round_number + 1: c.extra_count = 0
			c.extra_round = round_number + 1
			c.extra_count += 2
			_transfer_death(a,j.target)
			_note("%s 获得心脏，下回合可额外打出两张普通牌。" % c.name)
		"badges":
			var t: int = characters[a.actor].team
			badges[t] += j.count
			_note("%s 的队伍获得 %d 枚徽章（%d/%d）。" % [characters[a.actor].name,j.count,badges[t],BADGE_GOAL])
			if badges[t] >= BADGE_GOAL:
				if a.get("death",false): _complete_death(a)
				else: _complete(a)
				_end(t,"徽章")
		"pain_offer":
			if _has_effect("pain",j.victim) and characters[j.victim].hp == 0:
				var pain := {"id":-1,"actor":j.victim,"card":111,"death":true,"status":"active"}
				_note("苦肉自动发动：%s 摸一张牌，然后可额外打出至多两张手牌。" % characters[j.attacker].name)
				_push([_job("draw",pain,{"target":j.attacker,"count":1}),_job("bonus",pain,{"target":j.attacker})])
				_queue_visual(pain,"pain",j.attacker,"苦肉触发 · 摸牌并追加出牌")
		"bonus":
			var c: Dictionary = characters[j.target]
			var options: Array = c.hand.filter(func(id): return _can_play_hand_card(c,id)) if c.hp > 0 and play_limit(c) > 0 and not reveal_locked_teams[c.team] else []
			if not options.is_empty():
				_prompt(a,"bonus",options,"%s：选择至多两张普通牌，立即打出并翻开" % c.name,c.team,true)
				request.target = c.id
				request.count = mini(2,options.size())
				request.skip_prompt = true

func _prompt(a: Dictionary, kind: String, options: Array, description: String, team: int, can_skip: bool) -> void:
	input_action = a
	phase = "death_targeting" if kind == "character" and a.get("death",false) else ("targeting" if kind == "character" else ("choosing" if kind in ["number","card"] else "selecting"))
	request = {"type":kind,"team":team,"options":options,"description":description,"can_skip":can_skip}

func _responses(j: Dictionary) -> void:
	var a: Dictionary = j.a
	if a.get("death",false) or a.status not in ["pending","active"] or j.mode != "target": return
	for target_id in j.targets:
		var holder: Dictionary = characters[target_id]
		if holder.hp <= 0 or holder.team == characters[a.actor].team: continue
		for id in holder.hand:
			if not catalog.has(id) or j.passed.has(id): continue
			var key: String = catalog[id].key
			if key != "holy_amulet" and not (key == "attack_amulet" and _info(a).type == "攻击") and not (key == "magic_amulet" and _info(a).type == "技能"): continue
			_prompt(a,"amulet",[id],"%s 成为敌方牌的目标，可使用手牌中的%s取消整张牌的效果，然后弃置护符；也可保留。" % [holder.name,catalog[id].name],holder.team,false)
			phase = "responding"
			# Identity and holder are private until the reaction is accepted.
			pending_attack = {"response":j,"holder":holder.id}
			return

func respond(team: int, guard_id: int) -> String:
	if phase != "responding" or team != request.get("team",-1): return "当前无需你响应护符。"
	if guard_id != 0 and not request.options.has(guard_id): return "不能使用这张护符。"
	var j: Dictionary = pending_attack.response
	var holder: Dictionary = characters[pending_attack.holder]
	var offered: int = request.options[0]
	if guard_id != 0 and holder.hp <= 0: return "阵亡棋子不能触发护符。"
	if guard_id != 0 and not holder.hand.has(guard_id): return "护符已不在手牌中。"
	request = {}
	pending_attack = {}
	revision += 1
	j.passed.append(offered)
	if guard_id == 0:
		_push([j])
	else:
		# Defile blocks discarding, but does not disable in-hand passives.
		var retained := not _can_discard_hand_card(holder,guard_id)
		var guard := _add_action(holder.id,guard_id,retained,"amulet_response")
		guard.status = "active"
		guard.revealed = true
		guard.reaction = true
		guard.hand_response = true
		_note("%s 使用手牌中的 %s。%s" % [holder.name,_info(guard).name,"此护符不可弃置，保留在手牌中。" if retained else ""])
		_push([_job("cancel_card",guard,{"source":j.a,"affected_targets":j.targets.duplicate()}),_job("complete",guard),j])
	_pump()
	return ""

func _forced_next(j: Dictionary) -> void:
	_refresh_priorities()
	var pending := death_queue.filter(func(a): return a.status == "pending" and a.get("forced_batch",-1) == j.batch)
	pending.sort_custom(_higher)
	if pending.is_empty():
		current_id = j.resume_normal
		death_current_id = j.resume_death
		return
	var a: Dictionary = pending[0]
	death_current_id = a.id
	_start_effect(a,j)

func _ask(a: Dictionary, kind: String, options: Array, description: String) -> bool:
	if options.is_empty():
		_note("%s 没有合法目标，不产生效果。" % _info(a).name)
		return false
	_prompt(a,kind,options,description,characters[a.actor].team,true)
	return true

func _ask_death(a: Dictionary) -> bool:
	var key: String = _info(a).key
	var options: Array = []
	for c in characters:
		var allowed := true
		match key:
			"resurrection": allowed = c.hp == 0
			"mediocrity","heart": allowed = c.hp > 0
			"privilege": allowed = c.id != a.actor
		if allowed: options.append(c.id)
	var description := _target_description(a)
	match key:
		"last_dance":
			var selected: Array = a.get("dance_targets",[])
			var names: Array = selected.map(func(id):return ("我方" if characters[id].team == characters[a.actor].team else "敌方")+str(id%3+1))
			description = "终舞：选择第 %d / 5 个目标。可以重复选择，选齐后按顺序各造成1点伤害。%s" % [selected.size()+1,"\n已选："+"、".join(names) if not names.is_empty() else ""]
		"resurrection": description = "选择一个死亡棋子（可以是自己），以 5 点生命复活"
		"mediocrity": description = "选择存活棋子：弃置其所有亡语，不死除外"
		"heart": description = "选择存活棋子：摸三张牌、下回合额外出两张牌，并获得心脏"
		"privilege": description = "选择自己以外的一个棋子，使其所有牌的优先级增加100。"
	var asked := _ask(a,"character",options,description)
	if asked and key == "last_dance":
		request.selected_targets = a.get("dance_targets",[]).duplicate()
		request.can_reselect = not request.selected_targets.is_empty()
	return asked

func _target_description(a: Dictionary) -> String:
	var card := _info(a)
	var text: String = card.text.replace("玩家","棋子")
	if "\n" in text: return text
	match card.key:
		"precise_strike": return "选择第一个棋子，然后选择另一个棋子，各造成1点伤害。"
		"godslayer": return "选择一个本回合已经翻开牌的棋子，对其造成3点伤害。"
		"judgment": return "选择一个棋子：如果其生命值小于等于2，则对其造成99点伤害。"
		"peek": return "选择一个棋子，查看其所有手牌和亡语牌。"
		"silence": return "选择一个棋子，使其下回合不能打出普通牌。"
		"heal_other": return "选择一个除自己外的存活棋子，使其回复3点生命。"
	text = text.replace("对一个棋子造成","选择一个棋子，对其造成").replace("对1名棋子造成","选择一个棋子，对其造成")
	if text.begins_with("指定"): text = "选择"+text.trim_prefix("指定")
	return text

func target(team: int, target_id: int) -> String:
	if phase not in ["targeting","death_targeting"] or request.get("type") != "character": return "当前不需要选择棋子。"
	if team != request.team: return "请等待对方操作。"
	if not request.options.has(target_id): return "该棋子不是合法目标。"
	var a: Dictionary = input_action
	if not a.get("death",false) and _info(a).key == "cards_to_blades":
		a.target = target_id
		a.blade_targets.clear()
		for _i in range(a.convert_count): a.blade_targets.append(target_id)
		request = {}
		revision += 1
		_push([_job("blade_next",a)])
		_pump()
		return ""
	if a.get("death",false) and _info(a).key == "last_dance":
		var selected: Array = a.get("dance_targets",[])
		selected.append(target_id)
		a.dance_targets = selected
		request = {}
		revision += 1
		if selected.size() < 5:
			_ask_death(a)
		else:
			var seq: Array = []
			for i in range(selected.size()): seq.append(_job("dance_hit",a,{"target":selected[i],"hit":i+1}))
			_push(seq)
			_pump()
		return ""
	if not a.get("death",false) and _info(a).key == "gift":
		request = {}
		revision += 1
		_prompt(a,"gift",characters[a.actor].hand.duplicate(),"馈赠（2/2）：选择至多两张手牌交给%s · %s（诅咒可以转交）。" % ["我方" if characters[target_id].team == team else "敌方",characters[target_id].name],team,true)
		request.count = mini(2,characters[a.actor].hand.size())
		request.recipient = target_id
		return ""
	if not a.get("death",false) and _info(a).key == "precise_strike":
		var selected: Array = a.get("selected_targets",[])
		selected.append(target_id)
		a.selected_targets = selected
		request = {}
		revision += 1
		if selected.size() == 1:
			var options: Array = characters.filter(func(c):return c.id != target_id).map(func(c):return c.id)
			var c: Dictionary = characters[target_id]
			_ask(a,"character",options,"已选%s · %s；选择另一个棋子，各造成1点伤害。" % ["我方" if c.team == team else "敌方",c.name])
			request.selected_targets = selected.duplicate()
			request.can_reselect = true
		else:
			var seq: Array = [_job("responses",a,{"mode":"target","targets":selected.duplicate(),"passed":[]})]
			for id in selected: seq.append(_job("damage",a,{"target":id,"amount":1}))
			_push(seq)
			_pump()
		return ""
	a.target = target_id
	request = {}
	revision += 1
	if a.get("death",false): _push(_target_jobs(a,target_id))
	else:
		_push([_job("responses",a,{"mode":"target","targets":[target_id],"passed":[]}),_job("normal_target",a,{"target":target_id})])
	_pump()
	return ""

func reselect_targets(team: int) -> String:
	if not animation.is_empty() or phase not in ["targeting","death_targeting"] or request.get("type","") != "character": return "当前不能重新选择目标。"
	if team != request.get("team",-1) or not request.get("can_reselect",false): return "当前不能由你重新选择目标。"
	var a: Dictionary = input_action
	if a.get("status","") != "active": return "结算已更新。"
	var key: String = _info(a).key
	if not ((key == "precise_strike" and not a.get("death",false)) or (key == "last_dance" and a.get("death",false))): return "这张牌无需重新选择目标。"
	request = {}
	revision += 1
	if key == "precise_strike":
		a.erase("selected_targets")
		_ask(a,"character",characters.map(func(c): return c.id),_target_description(a))
	else:
		a.dance_targets.clear()
		_ask_death(a)
	return ""

func _normal_target(a: Dictionary, target_id: int) -> void:
	if not a.get("death",false) and _info(a).type == "攻击":
		if _has_effect("blessing",target_id):
			a.status = "blocked"
			_note("%s 受到保佑，攻击牌不对其生效。" % characters[target_id].name)
			_push([_job("shield_block",a,{"target":target_id})])
			return
		if characters[target_id].shield > 0:
			_offer_defense(a,target_id,[])
			return
	_push(_target_jobs(a,target_id))

func _offer_defense(a: Dictionary, target_id: int, passed: Array) -> void:
	var c: Dictionary = characters[target_id]
	# Legacy scenarios may set a shield counter directly; production uses sources.
	var sources: Array = c.shield_sources.duplicate()
	if sources.is_empty() and c.shield > 0: sources.append(target_id)
	for owner in sources:
		if passed.has(owner) or characters[owner].hp <= 0: continue
		phase = "reacting"
		pending_attack = {"a":a,"target":target_id,"owner":owner,"passed":passed}
		request = {"type":"defense","team":characters[owner].team,"options":[0,1],"target":target_id,
			"description":"可消耗施加给%s的防御，取消整张攻击牌；也可以保留。" % c.name,"can_skip":false}
		input_action = a
		return
	_push(_target_jobs(a,target_id))

func _target_jobs(a: Dictionary, target_id: int) -> Array:
	var key: String = _info(a).key
	if not a.get("death",false):
		match key:
			"cards_to_blades": return [_job("blade_volley",a)]
			"sapphire","ruby","amethyst","holy_amulet","attack_amulet","magic_amulet": return [_job("gem_transfer",a,{"target":target_id})]
			"topaz": return [_job("badges",a,{"count":1}),_job("gem_transfer",a,{"target":target_id})]
			"emerald": return [_job("draw",a,{"target":a.actor,"count":4}),_job("gem_transfer",a,{"target":target_id})]
			"amber": return [_job("heal",a,{"target":a.actor,"amount":3}),_job("gem_transfer",a,{"target":target_id})]
			"defile": return [_job("defile",a,{"target":target_id})]
			"poisoning": return [_job("poisoning",a,{"target":target_id})]
			"obstruct": return [_job("obstruct",a,{"target":target_id})]
			"defense": return [_job("shield",a,{"target":target_id})]
			"peek": return [_job("peek",a,{"target":target_id})]
			"plunder": return [_job("plunder",a,{"target":target_id})]
			"silence": return [_job("silence",a,{"target":target_id})]
			"raise_dead": return [_job("revive",a,{"target":target_id,"hp":1})]
			"heal_other": return [_job("heal",a,{"target":target_id,"amount":3})]
		var amount := 1
		match key:
			"judgment":
				if characters[target_id].hp > 2:
					_note("目标生命大于 2，审判不造成伤害。")
					return [_job("judgment_miss",a,{"target":target_id})]
				amount = 99
			"godslayer","triple_strike","holy_strike": amount = 3
			"double_strike","magic_strike","quick_strike","hasty_spell": amount = 2
			"final_strike": amount = int(_info(a).damage)
		var seq := [_job("damage",a,{"target":target_id,"amount":amount})]
		if key == "bounty": seq.append(_job("bounty",a,{"target":target_id}))
		if key == "glory": seq.append(_job("glory",a,{"target":target_id}))
		return seq
	match key:
		"death_sentence": return [_job("damage",a,{"target":target_id,"amount":99})]
		"life_steal": return [_job("damage",a,{"target":target_id,"amount":3}),_job("life_after",a,{"target":target_id})]
		"resurrection": return [_job("revive",a,{"target":target_id})]
		"vanish": return [_job("discard_all",a,{"target":target_id})]
		"mediocrity": return [_job("strip",a,{"target":target_id})]
		"prison","blessing","privilege": return [_job("activate",a,{"target":target_id})]
		"heart": return [_job("draw",a,{"target":target_id,"count":3}),_job("heart",a,{"target":target_id})]
		"curse": return [_job("curse_move",a,{"target":target_id})]
	return []

func choose(team: int, value: int) -> String:
	if phase != "choosing" or team != request.get("team",-1): return "当前无需你做出选择。"
	if not request.options.has(value): return "无效的选择。"
	var a: Dictionary = input_action
	var values: Array = []
	if _info(a).key == "ignore":
		if not a.has("ignore_first"):
			a.ignore_first = value
			var options: Array = [0,1,2,3,4,5,6]
			options.erase(value)
			_ask(a,"number",options,"忽视：已选 %d，再选择一个不同的主优先级（0～6）" % value)
			request.selected_numbers = [value]
			revision += 1
			return ""
		values = [int(a.ignore_first),value]
	_push([_job("chosen",a,{"value":value,"values":values})])
	request = {}
	revision += 1
	_pump()
	return ""

func defend(team: int, cancel: bool) -> String:
	if phase != "reacting" or team != request.get("team",-1): return "当前无需你响应防御。"
	var a: Dictionary = pending_attack.a
	var target_id: int = pending_attack.target
	var owner: int = pending_attack.owner
	var passed: Array = pending_attack.passed.duplicate()
	if cancel and characters[owner].hp <= 0: return "阵亡棋子不能触发防御。"
	request = {}; pending_attack = {}
	if cancel:
		characters[target_id].shield -= 1
		characters[target_id].shield_sources.erase(owner)
		a.status = "blocked"
		_note("%s 使用施加给%s的防御，取消%s的全部效果。" % [characters[owner].name,characters[target_id].name,_info(a).name])
		_push([_job("shield_block",a,{"target":target_id,"guard_style":"defense"})])
	else:
		passed.append(owner)
		_offer_defense(a,target_id,passed)
	revision += 1
	_pump()
	return ""

func early_end_available(team: int) -> bool:
	if team not in [0,1] or early_end_team >= 0 or turn_stage != "resolution" or death_phase or phase in ["planning","review","ended"]: return false
	if characters.any(func(c): return c.team != team and c.hp > 0): return false
	if not characters.any(func(c): return c.team == team and c.hp > 0): return false
	return queue.any(func(a): return characters[a.actor].team == team and a.status in ["pending","active"])

func can_end_round_early(team: int) -> bool:
	if not early_end_available(team) or not animation.is_empty(): return false
	if request.is_empty(): return true
	# Never dismiss an opponent's reaction, a nested deathrattle, or a mandatory
	# choice created by an effect that has already resolved (e.g. divinity).
	return request.get("team",-1) == team and request.get("can_skip",false) and not input_action.get("death",false) and input_action.get("status","") == "active" and characters[input_action.actor].team == team

func end_round_early(team: int) -> String:
	if not can_end_round_early(team): return "当前不能提前结束回合；需敌方全员阵亡，且轮到你操作普通牌。"
	early_end_team = team
	var frames: Array = []
	for a in queue:
		if characters[a.actor].team == team and a.status in ["pending","active"]:
			a.status = "declined"
			frames.append(_frame(a))
	# Keep completion/round cleanup and effects already triggered by a paid cost.
	# Opposing Mirror/Ghost actions and all deathrattles retain their normal rules.
	jobs = jobs.filter(func(j): return not frames.has(j.get("frame","")) or j.op == "complete")
	request = {}
	input_action = {}
	pending_attack = {}
	_note("%s提前结束回合：跳过己方剩余普通牌，已生效部分保留，回合末效果及双方亡语照常结算。" % ["一方","二方"][team])
	revision += 1
	_pump()
	return ""

func skip_effect(team: int) -> String:
	if not animation.is_empty(): return "请等待当前特效结束。"
	if not request.get("can_skip",false) or team != request.get("team",-1): return "当前不能由你跳过效果。"
	var a: Dictionary = input_action
	if request.get("skip_prompt",false):
		_note("玩家放弃本次%s的可选操作。" % _info(a).name)
	else:
		if a.status != "active" or characters[a.actor].team != team: return "结算已更新。"
		a.status = "declined"
		var frame := _frame(a)
		jobs = jobs.filter(func(j): return j.get("frame","") != frame or j.op == "complete")
		_note("%s 主动跳过%s的剩余效果，已生效部分保留。" % [characters[a.actor].name,_info(a).name])
	request = {}
	revision += 1
	_pump()
	return ""

func _draw_job(j: Dictionary) -> void:
	if int(j.count) <= 0: return
	var c: Dictionary = characters[j.target]
	j.draw_was_blocked = not j.get("continued",false) and _draw_blocked(c)
	if j.draw_was_blocked:
		_note("%s 因禁锢，本次摸牌被取消。" % c.name)
		for e in effects:
			if e.card == 112 and e.target == c.id:
				_queue_visual(_visual_action("prison",e.owner),"prison",c.id,"禁锢 · 本次摸牌取消")
		return
	var owner := _effect_owner("divinity")
	if owner < 0:
		_draw(c,j.count,j.get("a",{}))
		return
	var capacity := maxi(0,HAND_LIMIT-c.hand.size())
	if capacity == 0:
		_note("%s：我的手牌满了！无需神化选牌。" % c.name)
		# A rejected visual marker supplies only the speech cue; the pile is untouched.
		_queue_draw_visual(c.id,[0],c.hand.duplicate(),deck.size(),j.get("a",{}),[deck.size()],[true])
		divinity_choice_chain = true
		return
	_refill()
	if deck.is_empty(): _note("牌库不足，无法继续摸牌。"); return
	var drawable := mini(int(j.count),capacity)
	var count := mini(drawable,deck.size())
	var a := {"id":-2,"actor":owner,"card":102,"death":true,"status":"active"}
	_prompt(a,"deck",deck.duplicate(),"神化：为 %s 从普通牌库挑选 %d 张牌" % [c.name,count],characters[owner].team,false)
	request.accept_count = count
	request.count = count
	request.target = c.id
	request.remaining = drawable - count
	request.frame = j.get("frame","")
	if not j.get("a",{}).is_empty() and _info(j.a).key=="prepared":request.draw_source=j.a
	_note("神化代替摸牌：由 %s 为 %s 选牌。" % [characters[owner].name,c.name])
	if not divinity_choice_chain:
		_queue_visual(a,"divinity",owner,"",{"kind":"divinity_pulse","travel_ms":1500,"impact_ms":0,"effect_state":"choosing","card_count":count})

func pick(team: int, values: Array) -> String:
	if phase != "selecting" or team != request.get("team",-1): return "当前无需你进行此选择。"
	var unique := {}
	for id in values:
		if typeof(id) != TYPE_INT or unique.has(id): return "无效或重复的卡牌。"
		unique[id] = true
	var kind: String = request.type
	for id in values:
		if not request.options.has(id): return "不能选择这张牌。"
		if kind == "gift" and not characters[input_action.actor].hand.has(id): return "这张牌已不在你的手牌中。"
		if kind in ["defile","plunder"] and not characters[request.target].hand.has(id): return "这张牌已不在目标手牌中。"
		if kind == "bonus" and not _can_play_hand_card(characters[request.target],id): return "这张牌不能打出。"
		if kind == "search" and not deck.has(id): return "这张牌已不在抽牌堆中。"
		if kind in ["hand_limit","hand","elegy","discard"] and not _can_discard_hand_card(characters[request.target],id): return "这张牌不能被弃置。"
	if kind == "bonus":
		if values.size() > request.count: return "至多选择两张牌。"
	elif kind == "gift":
		if values.is_empty() or values.size() > request.count: return "请选择一至两张手牌，或跳过效果。"
	elif kind == "discard" and request.has("min_count"):
		if values.size() < request.min_count or values.size() > request.count: return "请选择提示范围内的牌。"
	elif values.size() != request.count: return "请选择提示数量的牌。"
	var q := request.duplicate(true)
	var a: Dictionary = input_action
	request = {}
	revision += 1
	match kind:
		"search":
			_queue_visual(a,"search",q.target,"",{"kind":"card_effect","op":"search_depart","travel_ms":preload("res://scripts/search_compass_pose.gd").DEPART_MS,"impact_ms":0})
			deck.erase(values[0])
			if _put_in_hand(q.target,values[0],a):
				_note("搜寻：%s 从抽牌堆获得一张牌。" % characters[q.target].name)
		"plunder":
			var motion := _hand_motion(q.target,values)
			var origin := {"kind":"hand","actor":q.target,"slot":motion.slots[0],"owner_slot":motion.owner_slots[0]}
			characters[q.target].hand.erase(values[0])
			var placed := _put_in_hand(a.actor,values[0],a,origin)
			if values[0] == 104:
				characters[q.target].curse_exposed = false
				characters[a.actor].curse_exposed = false
			if placed: _note("%s 从 %s 的手牌中选取了一张牌。" % [characters[a.actor].name,characters[q.target].name])
		"defile":
			_push([_job("defile_seal",a,{"target":q.target,"value":values[0]})])
		"gift":
			# Keep selected identities in private jobs, never in the public action.
			_push([_job("responses",a,{"mode":"target","targets":[a.actor,q.recipient],"passed":[]}),
				_job("gift_transfer",a,{"target":q.recipient,"values":values.duplicate()})])
		"elegy":
			_push([_job("elegy_pack",a,{"values":values.duplicate()})])
		"deck":
			var before_hand: Array = characters[q.target].hand.duplicate()
			var pile_before := deck.size()
			for id in values:
				deck.erase(id)
			_receive_drawn_cards(characters[q.target],values,before_hand,pile_before,q.get("draw_source",a))
			divinity_choice_chain = true
			if q.remaining > 0:
				var next={"op":"draw","target":q.target,"count":q.remaining,"continued":true,"frame":q.frame}
				if q.has("draw_source"):next.a=q.draw_source
				_push([next])
		"hand_limit":
			for id in values: _discard_hand_card(characters[q.target],id)
			phase = q.resume_phase
			_note("%s 的%s因手牌上限弃置 %d 张，剩余 %d 张。" % ["一队" if characters[q.target].team == 0 else "二队",characters[q.target].name,values.size(),characters[q.target].hand.size()])
		"discard":
			if _info(a).key=="prepared":
				_push([_job("prepared_pack",a,{"values":values.duplicate()})])
			else:
				for id in values: _discard_hand_card(characters[q.target],id)
				_note("%s：%s 弃置 %d 张手牌。" % [_info(a).name,characters[q.target].name,values.size()])
		"hand":
			_discard_hand_card(characters[q.target],values[0])
			_queue_visual(a,"greed",q.target,"弃置 1 张手牌",{"card_count":1})
			if presentation_enabled:
				visual_queue[-1].motif = "dissolve"
				visual_queue[-1].flow = "out"
		"bonus":
			_play_revealed_hand(q.target,values,"苦肉")
			if not values.is_empty(): _queue_visual(a,"pain",q.target,"苦肉 · 追加 %d 张牌" % values.size())
	_pump()
	return ""

func _anticipation(a: Dictionary) -> void:
	_refresh_priorities()
	var enemy: int = 1-characters[a.actor].team
	var hidden := queue.filter(func(other): return characters[other.actor].team == enemy and not other.revealed and not other.discarded)
	if hidden.is_empty():
		_note("预判：敌方没有未翻开的普通牌，不触发封锁。")
		return
	var total := 0
	for other in hidden: total += int(other.main)
	if total > hidden.size()*2:
		_note("预判：条件未满足，敌方仍可正常翻牌。")
		return
	reveal_locked_teams[enemy] = true
	for other in queue:
		if characters[other.actor].team == enemy and not other.revealed and other.status in ["pending","held"]:
			other.status = "suppressed"
	# Publish only the result: a failed prediction must not reveal hidden ranks.
	_note("预判成功：敌方本回合不能再翻开普通牌，已翻开的牌仍正常结算。")

func _play_revealed_hand(actor: int, values: Array, reason: String) -> void:
	var c: Dictionary = characters[actor]
	var flipped: Array = []
	var eligible: Array = values.filter(func(id): return _can_play_hand_card(c,id))
	for id in eligible:
		c.hand.erase(id)
		var extra := _add_action(actor,id)
		extra.release_group = current_main
		if reveal_locked_teams[c.team]:
			extra.status = "suppressed"
			_note("%s 因%s打出一张普通牌，但预判阻止了翻开。" % [c.name,reason])
		else:
			# Forced plays resolve normally, including amulet hand transfers.
			extra.status = "pending"
			extra.revealed = true
			c.revealed = true
			flipped.append(extra.id)
			_note("%s 因%s打出并翻开 %s，等待当前整张牌完成。" % [c.name,reason,catalog[id].name])
	_queue_card_reveal(flipped)
	_push(_flip_windows())

func _damage(a: Dictionary, target_id: int, amount: int, hp_loss: bool = false) -> bool:
	if not hp_loss: amount = _attack_damage(a,amount)
	var c: Dictionary = characters[target_id]
	a.killed = false
	if not hp_loss and not a.get("death",false) and _info(a).type == "攻击" and _has_effect("blessing",target_id):
		_note("%s 受到保佑，本次攻击不对其生效。" % c.name)
		return false
	if amount <= 0:
		_note("%s → %s：伤害为0，生命值不变。" % [_info(a).name,c.name])
		return false
	if c.hp == 0:
		if not hp_loss and not a.get("environment",false) and a.actor != target_id and characters[a.actor].team == c.team and _has_effect("pain",target_id):
			_note("%s 对死亡的队友 %s 造成伤害，触发苦肉。" % [characters[a.actor].name,c.name])
			_push([{"op":"pain_offer","victim":target_id,"attacker":a.actor}])
		else: _note("%s → %s：目标已死亡，生命值不变。" % [_info(a).name,c.name])
		return false
	c.hp = maxi(0,c.hp - amount)
	if hp_loss: _note("%s → %s，失去 %d 点生命（%d/%d）。" % [_info(a).name,c.name,amount,c.hp,c.max_hp])
	else: _note("%s → %s，造成 %d 点伤害（%d/%d）。" % [_info(a).name,c.name,amount,c.hp,c.max_hp])
	if c.hp > 0: return false
	c.death_round = round_number
	death_events += 1
	a.killed = true
	_note("%s 死亡。" % c.name)
	_queue_visual(a,"death",target_id,"阵亡 · 已翻开待结算牌取消")
	for pending in queue:
		if pending.actor == target_id and pending.status in ["pending","held"] and pending.revealed and not pending.virtual:
			pending.status = "cancelled"
	_try_immortal(target_id)
	if death_phase and c.hp == 0: _enqueue_deaths(c)
	return true

func _try_immortal(target_id: int) -> void:
	var c: Dictionary = characters[target_id]
	if c.hp == 0 and c.deathrattles.has(120):
		if not death_revealed.has(120): death_revealed.append(120)
		_note("%s 的不死立刻触发。" % c.name)
		# The immediate rule still resolves now; its card cue is replayed publicly.
		if presentation_enabled and resolution_presentation_enabled:
			visual_queue.append(_card_start_event(_visual_action("immortal",target_id)))
		if characters.any(func(other): return other.id != target_id and other.team == c.team and other.hp > 0):
			_revive(target_id,1)
			_queue_visual(_visual_action("immortal",target_id),"immortal",target_id,"不死 · 立刻复活为 1 生命",{"revived":true})
		else:
			_queue_visual(_visual_action("immortal",target_id),"immortal",target_id,"没有存活队友 · 无法复活",{"revived":false})
			if presentation_enabled: visual_queue[-1].motif = "soul"

func _heal(c: Dictionary, amount: int) -> void:
	if c.hp == 0: return
	if _has_effect("blessing",c.id):
		_note("%s 受到保佑，不能回复生命。" % c.name)
		return
	var before: int = c.hp
	c.hp = mini(c.max_hp,c.hp + amount)
	_note("%s 回复 %d 点生命（%d/%d）。" % [c.name,c.hp-before,c.hp,c.max_hp])

func _revive(target_id: int, hp: int = MAX_HP) -> void:
	var c: Dictionary = characters[target_id]
	c.hp = hp
	_note("%s 立刻复活，生命值为 %d。" % [c.name,hp])
	for a in death_queue:
		if a.actor == target_id and a.status == "pending":
			a.status = "returned"
			_note("%s 收回尚未结算的 %s。" % [c.name,death_catalog[a.card].name])

func _generate_card(definition: Dictionary) -> int:
	while catalog.has(next_generated_card_id) or death_catalog.has(next_generated_card_id): next_generated_card_id += 1
	var id := next_generated_card_id
	next_generated_card_id += 1
	var card := definition.duplicate(true)
	card.merge({"id":id,"generated":true},true)
	catalog[id] = card
	return id

func _transfer_gem(a: Dictionary, target: int) -> void:
	var id: int = _generate_card(_info(a)) if a.virtual else a.card
	a.transferred = true
	if not _put_in_hand(target,id):
		_queue_hand_transfer(a,target,id,false)
		return
	_queue_hand_transfer(a,target,id)
	_note("%s 被放入%s的手牌。" % [_info(a).name,characters[target].name])

func _queue_hand_transfer(a: Dictionary, target: int, id: int, accepted: bool = true) -> void:
	a.hand_transferred = true
	if not presentation_enabled: return
	var c: Dictionary = characters[target]
	var sorted_hand: Array = c.hand.duplicate()
	sorted_hand.sort_custom(func(left,right):
		var ca: Dictionary = catalog.get(left,{"main":0,"secondary":0})
		var cb: Dictionary = catalog.get(right,{"main":0,"secondary":0})
		return ca.main > cb.main if ca.main != cb.main else ca.secondary > cb.secondary)
	# Source is public; the generated instance and sorted hand slot stay private.
	var event := _visual_event(a,_info(a).key,target)
	event.merge({"kind":"hand_transfer","incoming_card":id,"recipient":target,"accepted":accepted,
		"before_count":c.hand.size()-(1 if accepted else 0),"hand_index":c.hand.find(id),"owner_slot":sorted_hand.find(id),
		"travel_ms":1100 if accepted else 1900,"impact_ms":180},true)
	visual_queue.append(event)

func _can_play_hand_card(c: Dictionary, id: int) -> bool:
	if not c.hand.has(id) or not catalog.has(id) or not catalog[id].get("playable",true) or defiled_cards.has(id): return false
	return catalog[id].type != "攻击" or not _has_poison(c)

func _has_poison(c: Dictionary) -> bool:
	return c.hand.any(func(id): return catalog.has(id) and catalog[id].key == "poison")

func _draw_blocked(c: Dictionary) -> bool:
	return _has_effect("prison",c.id) and c.hand.any(func(id): return _can_play_hand_card(c,id))

func _can_discard_hand_card(c: Dictionary, id: int) -> bool:
	return c.hand.has(id) and id != 104 and not defiled_cards.has(id) and (not catalog.has(id) or catalog[id].get("discardable",true))

func _discardable_hand(c: Dictionary) -> Array:
	return c.hand.filter(func(id): return _can_discard_hand_card(c,id))

func _discard_hand_card(c: Dictionary, id: int) -> void:
	if not _can_discard_hand_card(c,id): return
	var motion=_hand_motion(c.id,[id])
	var d={"actor":c.id,"card":id,"key":catalog.get(id,death_catalog.get(id,{})).get("key",""),"slot":motion.slots[0],"owner_slot":motion.owner_slots[0],"spent":false}
	c.hand.erase(id)
	staged_discards.append(d);discard_batch_pending.append(d)
	if c.hp > 0 and catalog.has(id) and catalog[id].has("discard_effect"):
		discard_triggers.append({"op":"discard_passive","target":c.id,"card":id})

func _discard_hand(c: Dictionary) -> void:
	var count: int = c.hand.size()
	for id in c.hand.duplicate(): _discard_hand_card(c,id)
	_note("%s 弃置 %d 张手牌。%s" % [c.name,count-c.hand.size(),"不可弃置的牌保留在手牌中。" if not c.hand.is_empty() else ""])

func _lose_death(owner: int, id: int, to_discard: bool = true) -> void:
	if id == 120: return
	if not characters[owner].deathrattles.has(id): return
	characters[owner].deathrattles.erase(id)
	if presentation_enabled:
		for e in effects:
			if e.card == id:
				var event := _visual_event(_visual_action(death_catalog[id].key,owner),death_catalog[id].key,e.target,death_catalog[id].name+" · 持续效果解除")
				event.motif = "shatter"
				event.effect_state = "removed"
				visual_queue.append(event)
	effects = effects.filter(func(e): return e.card != id)
	for a in death_queue:
		if a.card == id and a.status == "pending": a.status = "removed"
	if to_discard: death_discard.append(id)
	_refresh_priorities()

func _strip_deaths(target: int) -> void:
	var c: Dictionary = characters[target]
	for id in c.deathrattles.duplicate(): _lose_death(target,id)
	_note("%s 的亡语被弃置，相关持续效果立即停止；不死不可弃置。" % c.name)

func _transfer_death(a: Dictionary, target: int) -> void:
	_lose_death(a.actor,a.card,false)
	characters[target].deathrattles.append(a.card)
	a.transferred = true

func _move_death_to_hand(a: Dictionary, target: int) -> void:
	_lose_death(a.actor,a.card,false)
	a.transferred = true
	if not _put_in_hand(target,a.card):
		_queue_hand_transfer(a,target,a.card,false)
		return
	characters[target].curse_exposed = true
	_queue_hand_transfer(a,target,a.card)
	_note("凋萎进入 %s 的手牌，不能打出或以任何形式弃置，每回合出牌开始时造成 3 点伤害。" % characters[target].name)

func _discard_action(a: Dictionary) -> void:
	if a.get("hand_response",false):
		if not a.discarded and _can_discard_hand_card(characters[a.actor],a.card):
			_discard_hand_card(characters[a.actor],a.card)
			a.discarded = true
		return
	if not a.virtual and not a.discarded and not a.get("transferred",false):
		discard.append(a.card)
		a.discarded = true

func _complete(a: Dictionary) -> void:
	if a.status == "active": a.status = "done"
	_discard_action(a)
	request = {}

func _complete_death(a: Dictionary) -> void:
	if a.status == "active": a.status = "done"
	if not a.get("transferred",false) and (death_catalog[a.card].type != "持续性" or a.status == "declined"):
		if death_catalog[a.card].type == "一次性" and a.status == "done" and characters[a.actor].deathrattles.has(a.card):
			_remember_triggered_death(a.actor,a.card)
		_lose_death(a.actor,a.card)
		_note("%s 结算完毕，弃置。" % death_catalog[a.card].name)
	request = {}

func _death_display(c: Dictionary) -> Array:
	# Display-only history is separate from owned cards and the discard pile.
	var slots: Array = c.deathrattles.map(func(id):return {"card":id,"triggered":false})
	var history: Array = triggered_deaths.get(c.id,[]).duplicate(true)
	history.sort_custom(func(a,b):return a.slot<b.slot)
	for past in history:
		slots.insert(mini(past.slot,slots.size()),{"card":past.card,"triggered":true})
	return slots

func _remember_triggered_death(owner: int, card: int) -> void:
	if not triggered_deaths.has(owner): triggered_deaths[owner]=[]
	if triggered_deaths[owner].any(func(past):return past.card==card): return
	var slots: Array = _death_display(characters[owner])
	for i in range(slots.size()):
		if slots[i].card==card:
			triggered_deaths[owner].append({"card":card,"slot":i})
			return

func _finish_round() -> void:
	# Deathrattles may create new ordinary plays; those are not part of the skip.
	early_end_team = -1
	request = {}
	current_id = -1
	for a in queue: _discard_action(a)
	for c in characters:
		c.shield = 0
		c.shield_sources = []
		if c.prediction > 0 and c.hp == c.prediction:
			badges[c.team] += 1
			_note("%s 预言达成，队伍获得 1 枚徽章。" % c.name)
			_queue_visual(_visual_action("prophecy",c.id),"badge",c.id,"预言达成 · +1 枚徽章")
			if badges[c.team] >= BADGE_GOAL: _end(c.team,"徽章"); return
	for a in queue:
		if a.status == "held": a.status = "cancelled" if characters[a.actor].hp == 0 else "expired"
	var gem_jobs: Array = []
	if not skip_death_phase:
		# In-hand amethysts resolve before creating this phase's death queue.
		for c in characters:
			if c.hp > 0: continue
			for id in c.hand.duplicate():
				if catalog.has(id) and catalog[id].key == "amethyst":
					gem_jobs.append({"op":"gem_trigger","target":c.id,"card":id})
					break
	# Purple gems act before death cards are queued: do not reveal a pawn's
	# death cards early when the gem is about to revive it.
	var has_deaths := not skip_death_phase and characters.any(func(c):
		return c.hp == 0 and c.death_round == round_number and c.deathrattles.any(func(id): return _can_enqueue_death(id)))
	if not skip_death_phase and death_queue.any(func(a): return a.status == "pending"): has_deaths = true
	if skip_death_phase:
		phase="deathrattle";death_phase=true
		_announce_stage("death")
		_push([{"op":"skip_death_echo"},{"op":"finish_skipped_deaths"}]);_pump();return
	if gem_jobs.is_empty() and not has_deaths:
		_finish_deaths()
		return
	phase = "deathrattle"
	death_phase = true
	_announce_stage("death")
	_note("—— 亡语阶段：每张牌完成后，重新选择优先级最高的亡语 ——")
	_push(gem_jobs+[{"op":"death_queue_begin"}])
	_pump()

func _can_enqueue_death(id: int) -> bool:
	# Immortal triggers immediately; bound persistent cards are already active.
	return id != 120 and not effects.any(func(e): return e.card == id) and not death_queue.any(func(a): return a.card == id and a.status in ["pending","active"])

func _enqueue_deaths(c: Dictionary, forced_batch: int = -1) -> void:
	for id in c.deathrattles:
		var existing := death_queue.filter(func(a): return a.card == id and a.status in ["pending","active"])
		if not existing.is_empty():
			if forced_batch >= 0 and existing[0].status == "pending": existing[0].forced_batch = forced_batch
			continue
		if not _can_enqueue_death(id): continue
		death_queue.append({"id":next_death_id,"actor":c.id,"card":id,"main":death_catalog[id].priority + _bonus(c.id),
			"secondary":0,"status":"pending","death":true,"hits":0,"target":-1})
		if forced_batch >= 0: death_queue.back().forced_batch = forced_batch
		next_death_id += 1
		if not death_revealed.has(id): death_revealed.append(id)
		_note("%s 的%s [%d] 进入亡语队列。" % [c.name,death_catalog[id].name,death_catalog[id].priority + _bonus(c.id)])

func _finish_deaths() -> void:
	for a in queue: _discard_action(a)
	death_current_id = -1
	current_id = -1
	request = {}
	death_phase = false
	var alive := [0,0]
	for c in characters:
		if c.hp > 0: alive[c.team] += 1
	if alive[0] == 0 or alive[1] == 0:
		_end(-1 if alive[0] == 0 and alive[1] == 0 else (0 if alive[0] > 0 else 1),"全灭")
	else:
		phase = "review"
		confirmed = [false,false]
		_queue_reverse_restore()
		_note("亡语及追加普通牌已处理完毕，即将自动进入下一回合。" if turn_stage == "death" else "本回合结算完毕，即将自动进入下一回合。")
		revision += 1

func _end(team: int, reason: String) -> void:
	winner = team
	win_reason = reason
	phase = "ended"
	confirmed = [false,false]
	jobs = []
	request = {}
	_queue_reverse_restore()
	_note("双方全灭，平局。" if team == -1 else "%s通过%s获胜。" % [["一方","二方"][team],reason])
	revision += 1

func _queue_reverse_restore() -> void:
	if not reverse_cloth_active or reverse_restore_queued: return
	reverse_restore_queued = true
	if presentation_enabled:
		visual_queue.append(preload("res://scripts/reverse_timing.gd").restore_event())
	else:
		reverse_cloth_active = false

func advance_round() -> void:
	if phase == "review": _begin_round()

func confirm(team: int) -> String:
	if team not in [0,1] or phase not in ["review","ended"]: return "当前无需确认。"
	if confirmed[team]: return "已经确认，请等待对方。"
	confirmed[team] = true
	revision += 1
	if confirmed[0] and confirmed[1]:
		if phase == "ended": start(0,match_id + 1)
		else: _begin_round()
	return ""

func _ongoing_effects(c: Dictionary, viewer: int, can_see: bool) -> Array:
	# Derived from actual rules state, not animation history: reconnects and UI
	# rebuilds cannot lose a status, or retain a consumed/expired one.
	var result: Array = []
	if reveal_locked_teams[c.team]: result.append({"key":"anticipation","count":1,"waiting":false,"dormant":false})
	for key in c.statuses:
		result.append({"key":key,"count":1,"waiting":false,"dormant":key in ["ghost","pain"] and c.hp > 0})
	if c.shield > 0: result.append({"key":"defense","count":c.shield,"waiting":false,"dormant":false})
	if c.prediction > 0 and not death_phase:
		result.append({"key":"prophecy","count":c.prediction,"waiting":false,"dormant":false})
	for entry in [["overload","overload_round"],["silence","silenced_round"],["heart","extra_round"],["warcry","warcry_round"],["rally","rally_round"]]:
		var until: int = c.get(entry[1],-1)
		if until >= round_number and (entry[0] != "heart" or c.extra_count > 0):
			result.append({"key":entry[0],"count":c.extra_count if entry[0] == "heart" else c.get("warcry_bonus",3) if entry[0] == "warcry" else c.get("rally_count",1) if entry[0] == "rally" else 1,"waiting":until > round_number,"dormant":false})
	for link in mirrors:
		var target_action := _action(link.target)
		if link.actor == c.id and not target_action.is_empty() and not target_action.revealed and target_action.status in ["pending","held"]:
			result.append({"key":"mirror","count":1,"waiting":true,"dormant":false})
			break
	if c.deathrattles.has(120) and death_revealed.has(120):
		var ready: bool = characters.any(func(other): return other.id != c.id and other.team == c.team and other.hp > 0)
		result.append({"key":"immortal","count":1,"waiting":false,"dormant":not ready})
	# A publicly applied curse is visible; a secretly stolen one stays private
	# until its next public tick, so this overlay cannot disclose the stolen card.
	if c.hand.has(104) and (c.team == viewer or can_see or c.get("curse_exposed",false)):
		result.append({"key":"curse","count":1,"waiting":false,"dormant":false})
	return result

func _redact_blade_source(a: Dictionary, viewer: int, can_see: bool) -> void:
	if a.has("blade_source") and characters[a.actor].team != viewer and not can_see:
		a.blade_source.erase("owner_hand")
		a.blade_source.erase("owner_slots")

func _pending_hand_arrivals() -> Dictionary:
	# Rules already own these cards, but their arrival has not started yet.
	# Keep the preceding impact snapshot from briefly showing the final hand.
	var pending: Dictionary = {}
	if not presentation_enabled: return pending
	for event in visual_queue:
		if event.kind == "draw_cards":
			for entry in event.draws:
				if not pending.has(entry.target): pending[entry.target] = []
				for id in entry.ids:
					if id != 0: pending[entry.target].append(id)
		elif event.kind == "hand_transfer" and event.get("accepted",true):
			if not pending.has(event.recipient): pending[event.recipient] = []
			pending[event.recipient].append(event.incoming_card)
	return pending

func snapshot(team: int) -> Dictionary:
	_refresh_priorities()
	var eye_owner := _effect_owner("eye")
	var can_see: bool = eye_owner >= 0 and characters[eye_owner].team == team
	var visible: Array = []
	var pending_arrivals := _pending_hand_arrivals()
	for character in characters:
		var c: Dictionary = character.duplicate(true)
		if pending_arrivals.has(c.id):
			c.hand = c.hand.filter(func(id): return not pending_arrivals[c.id].has(id))
		c.defiled_slots=[]
		var marked=character.hand.filter(func(id):return defiled_cards.has(id))
		if not marked.is_empty():
			var motion=_hand_motion(c.id,marked)
			c.defiled_slots=motion.owner_slots if c.team==team or can_see else motion.slots
		c.hand_count = c.hand.size()
		c.death_count = c.deathrattles.size()
		c.death_slots = _death_display(character)
		for slot in c.death_slots:
			if not slot.triggered and c.team != team and not can_see and not death_revealed.has(slot.card): slot.card=0
		c.play_limit = play_limit(c)
		c.priority_bonus = _bonus(c.id)
		c.known_deathrattles = c.deathrattles.filter(func(id): return death_revealed.has(id))
		c.active_deathrattles = effects.filter(func(e): return e.owner == c.id).map(func(e): return e.card)
		c.statuses = []
		for key in ["prison","blessing","privilege","ghost","pain","eye","divinity","greed"]:
			if _has_effect(key,c.id): c.statuses.append(key)
		c.ongoing_effects = _ongoing_effects(c,team,can_see)
		if c.team != team and not can_see:
			c.hand = []
			c.deathrattles = c.known_deathrattles.duplicate()
		visible.append(c)
	var public_queue: Array = []
	var ordered: Array = queue.duplicate()
	ordered.sort_custom(func(a,b):
		if a.revealed != b.revealed: return a.revealed
		return _higher(a,b) if a.revealed else a.id < b.id)
	var cursor := -1
	for a in ordered:
		var shown: Dictionary = a.duplicate(true)
		_redact_blade_source(shown,team,can_see)
		if a.id == current_id: cursor = public_queue.size()
		shown.inspected = can_see and not a.revealed
		if not a.revealed and not can_see:
			shown.main = -1
			shown.secondary = -1
			shown.base_main = -1
			shown.base_secondary = -1
			if shown.status == "held": shown.status = "pending"
			if characters[a.actor].team != team:
				shown.card = 0
				shown.erase("damage")
				shown.erase("guard_target")
				# Mask the result, including at round end, until this card actually
				# reveals. Its owner still sees the real held/expired status.
				if a.get("suppression_attempt",false): shown.status = "suppressed"
		public_queue.append(shown)
	var public_animation := animation.duplicate(true)
	if public_animation.has("hand_motion"):
		var motion: Dictionary = public_animation.hand_motion
		if characters[motion.actor].team != team and not can_see:
			motion.erase("owner_slots");motion.erase("owner_cards")
	if public_animation.get("hand_response",false) and characters[public_animation.action.actor].team != team and not can_see:
		public_animation.erase("owner_slot")
	if public_animation.get("kind","") == "blade_volley" and characters[public_animation.action.actor].team != team and not can_see:
		public_animation.source_hand.erase("owner_hand")
		public_animation.source_hand.erase("owner_slots")
	if public_animation.has("action"): _redact_blade_source(public_animation.action,team,can_see)
	if public_animation.get("kind","") == "hand_transfer" and characters[public_animation.recipient].team != team and not can_see:
		public_animation.erase("incoming_card")
		public_animation.erase("owner_slot")
	if public_animation.get("kind","") == "gem_trigger" and characters[public_animation.action.actor].team != team and not can_see:
		public_animation.erase("gem_card")
		public_animation.erase("owner_slot")
	if public_animation.has("gem_overlay"):
		var gem:Dictionary=public_animation.gem_overlay
		if characters[gem.action.actor].team!=team and not can_see:
			gem.erase("gem_card");gem.erase("owner_slot")
	if public_animation.get("kind","") == "draw_cards":
		for entry in public_animation.draws:
			if entry.has("origin") and characters[entry.origin.actor].team != team and not can_see: entry.origin.erase("owner_slot")
			if characters[entry.target].team != team and not can_see:
				entry.erase("ids")
				entry.erase("before_hand")
	var public_deaths := death_queue.duplicate(true)
	public_deaths.sort_custom(_higher)
	var active: Dictionary = animation.action if not animation.is_empty() else (input_action if not request.is_empty() else {})
	active = active.duplicate(true)
	_redact_blade_source(active,team,can_see)
	var info: Dictionary = _info(active).duplicate(true) if not active.is_empty() else {}
	var public_request := request.duplicate(true)
	public_request.erase("draw_source")
	if not request.is_empty() and request.type in ["deck","hand","bonus","elegy","hand_limit","gift","search","defile","plunder","discard"] and request.team != team and not can_see:
		public_request.options = []
	if not request.is_empty() and request.type == "amulet" and request.team != team:
		public_request.options = []
		public_request.description = "等待对方决定是否使用手牌中的护符。"
	if request.get("team",team) != team and not can_see:
		for field in ["cards","deaths"]:
			if public_request.has(field): public_request[field] = []
	var shown_catalog := catalog.duplicate(true)
	var curse: Dictionary = death_catalog[104].duplicate(true)
	curse.merge({"main":0,"secondary":0,"short":"不可打出或弃置","type":"诅咒","playable":false,"discardable":false},true)
	shown_catalog[104] = curse
	# Per-card restrictions follow transfers, but do not disclose private picks.
	var visible_hand_ids: Array = []
	for c in visible: visible_hand_ids.append_array(c.hand)
	if request.get("team",-1) == team or can_see:
		if request.get("type","") in ["deck","hand","bonus","elegy","hand_limit","gift","search","defile","plunder"]: visible_hand_ids.append_array(request.get("options",[]))
		visible_hand_ids.append_array(request.get("cards",[]))
	var visible_card_ids: Array = visible_hand_ids.duplicate()
	for a in public_queue:
		if a.card != 0 and not a.virtual: visible_card_ids.append(a.card)
	if can_see: visible_card_ids.append_array(catalog.keys())
	for id in visible_card_ids:
		if shown_catalog.has(id) and shown_catalog[id].key == "final_strike":
			shown_catalog[id] = preload("res://scripts/card_state.gd").final_strike_info(catalog[id],int(final_strike_damage.get(id,0)))
	for id in defiled_cards:
		if visible_hand_ids.has(id) and shown_catalog.has(id):
			shown_catalog[id].merge({"playable":false,"discardable":false,"defiled":true},true)
			shown_catalog[id].text += "\n已被玷污：这张实体牌不能被打出或弃置；转交后限制仍保留。"
	for c in visible:
		if _has_poison(characters[c.id]):
			for id in c.hand:
				if shown_catalog.has(id) and shown_catalog[id].type == "攻击":
					shown_catalog[id].playable = false
					shown_catalog[id].text += "\n持有毒药：此棋子暂时不能打出攻击牌。"
	return {"prepared_backpack":prepared_backpack.duplicate(true),"staged_discards":staged_discards.filter(func(d):return not d.get("blade_pending",false)).duplicate(true),"match":match_id,"death_events":death_events,"revision":revision,"round":round_number,"phase":phase,"animation":public_animation,
		"early_end_available":early_end_available(team),"can_end_round_early":can_end_round_early(team),
		"turn_stage":turn_stage,"stage_main":stage_main,
		"winner":winner,"win_reason":win_reason,"characters":visible,"queue":public_queue,"cursor":cursor,
		"deck_count":deck.size(),"discard_count":discard.size(),"catalog":shown_catalog,
		"death_catalog":death_catalog.duplicate(true),"death_queue":public_deaths,"death_current_id":death_current_id,
		"death_discard":death_discard.duplicate(),"death_deck_count":death_deck.size(),
		"active_action":active.duplicate(true),"active_card":info,"input":public_request,
		"badges":badges.duplicate(),"badge_goal":BADGE_GOAL,"ready":[plans[0] != null,plans[1] != null],
		"hand_limit":HAND_LIMIT,"normal_type_count":normal_type_count,"reveal_locked_teams":reveal_locked_teams.duplicate(),
		"confirmed":confirmed.duplicate(),"my_plan":plans[team].duplicate(true) if plans[team] != null else [],
		"log":log_lines.duplicate(),"omniscient":can_see,"deck_view":deck.duplicate() if can_see else [],
		"discard_view":discard.duplicate() if can_see else [],
		"death_deck_view":death_deck.duplicate() if can_see else [],
		"seen_plans":plans.duplicate(true) if can_see else [],"reversed_order":reversed_order,"reverse_cloth_active":reverse_cloth_active,"skip_death_phase":skip_death_phase}

func _note(message: String) -> void:
	log_lines.append(message)
	if log_lines.size() > 240: log_lines.pop_front()
