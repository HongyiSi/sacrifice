extends RefCounted
## Crisp, code-native card emblems; illustrated characters/background live in assets/art.
static var cache: Dictionary = {}

static func motif(key: String) -> String:
	if key == "spare_food": return "heart"
	if key == "spare_supplies": return "cards"
	var added := {"bloodletting":"drop","gold_panning":"sieve","search":"magnifier","sapphire":"gem","ruby":"gem","amethyst":"gem","topaz":"gem","emerald":"gem","amber":"gem","rally":"flag","defile":"sealed","obstruct":"rocks","boulder":"rocks","poisoning":"drop","poison":"skull","final_strike":"sword"}
	if added.has(key): return added[key]
	var special:Dictionary={"anticipation":"eye","gift":"cards","cards_to_heart":"heart","cards_to_blades":"sword","late_suppress":"chain","frenzy":"dice","warcry":"horn","gambler":"dice","overload":"lightning","skip_death":"hourglass","death_sentence":"scythe","last_dance":"dance","ghost":"ghost","immortal":"phoenix","pain":"thorns","divinity":"sun","vanish":"shatter","mediocrity":"shatter","judgment":"scales"}
	if special.has(key):return special[key]
	if key in ["strike","quick_strike","holy_strike","double_strike","triple_strike","godslayer","bounty","glory","area_strike","precise_strike"]: return "sword"
	if key in ["defense","attack_amulet","holy_amulet","magic_amulet","blessing"]: return "shield"
	if key in ["heal","heal_other","team_heal","blood_rite","heart","life_steal"]: return "heart"
	if key in ["peek","eye","prophecy"]: return "eye"
	if key in ["badge","sacrifice_badges","privilege"]: return "crown"
	if key in ["reverse","overload","ghost","immortal","resurrection","raise_dead"]: return "swirl"
	if key in ["silence","prison","suppress","mediocrity","ignore"]: return "chain"
	if key in ["collect","gambler","elegy","greed","legacy","plunder"]: return "cards"
	if key == "mirror": return "mirror"
	if key in ["curse","feign","death_sentence","skip_death","last_dance","vanish","death"]: return "skull"
	if key == "back": return "rune"
	return "flame"

static func icon(key: String, ink: String = "365b80") -> Texture2D:
	if preload("res://scripts/cinema/atlas.gd").supports(key):return preload("res://scripts/cinema/atlas.gd").card_texture(key)
	if key=="gambler":return preload("res://scripts/gambler_die_art.gd").texture(ink)
	var name := motif(key)
	var cache_key := name + ink
	if cache.has(cache_key): return cache[cache_key]
	var shapes := {
		"drop":'<path d="M32 4C24 18 12 29 12 40a20 20 0 0 0 40 0C52 29 40 18 32 4Z" fill="COLOR"/><path d="M20 37c-3 8 1 14 8 15" fill="none" stroke="#f3dfb6" stroke-width="3"/>',
		"gem":'<path d="m17 8 30 0 12 18-27 33L5 26Z" fill="none" stroke="COLOR" stroke-width="4"/><path d="M5 26h54M17 8l-1 18 16 33 16-33-1-18M16 26 32 8l16 18" fill="none" stroke="COLOR" stroke-width="2"/>',
		"flag":'<path d="M14 7v51M14 10h36l-9 12 9 12H14M7 59h18" fill="none" stroke="COLOR" stroke-width="5"/>',
		"magnifier":'<circle cx="27" cy="26" r="18" fill="none" stroke="COLOR" stroke-width="5"/><path d="m40 39 17 18M20 26h14M27 19v14" stroke="COLOR" stroke-width="5"/>',
		"sieve":'<path d="M6 31h52l-9 24H15ZM12 39h40M16 47h33M23 32v22M34 32v22M45 32v22" fill="none" stroke="COLOR" stroke-width="3"/><path d="m27 4 9 8-7 12-11-5ZM45 10l9 5-5 9-9-4Z" fill="COLOR"/>',
		"sealed":'<path d="M12 7h38v50H12Z" fill="none" stroke="COLOR" stroke-width="3"/><circle cx="32" cy="32" r="17" fill="COLOR"/><path d="m21 21 22 22M43 21 21 43" stroke="#f3dfb6" stroke-width="4"/>',
		"rocks":'<path d="M4 49 14 27l18-3 12 13-2 20H9ZM36 6l17 4 8 17-17 6-14-13Z" fill="COLOR"/><path d="m14 29 10 10 16-2M24 39l-4 14M39 11l8 9 10 3" fill="none" stroke="#f3dfb6" stroke-width="2"/>',
		"horn":'<path d="M9 34 39 15 50 10l6 27-15-2-29 10Z" fill="COLOR"/><path d="m17 43 5 13 10-3-4-16M47 7l10-4M55 22l8-2M54 40l8 5" fill="none" stroke="COLOR" stroke-width="4"/>',
		"dice":'<rect x="11" y="11" width="42" height="42" rx="7" fill="none" stroke="COLOR" stroke-width="4"/><g fill="COLOR"><circle cx="21" cy="21" r="4"/><circle cx="43" cy="21" r="4"/><circle cx="32" cy="32" r="4"/><circle cx="21" cy="43" r="4"/><circle cx="43" cy="43" r="4"/></g>',
		"lightning":'<path d="M38 3 13 35h17l-6 26 28-36H36Z" fill="COLOR"/>',
		"hourglass":'<path d="M13 8h38M13 56h38M17 8c0 20 14 18 15 24-1 6-15 6-15 24M47 8c0 20-14 18-15 24 1 6 15 6 15 24" fill="none" stroke="COLOR" stroke-width="4"/><path d="m24 48 8-9 8 9Z" fill="COLOR"/>',
		"scythe":'<path d="m18 8 29 50M17 10C42 0 62 15 55 34 51 15 37 15 22 20" fill="none" stroke="COLOR" stroke-width="5"/>',
		"dance":'<path d="M32 5 38 23 58 20 43 34 51 54 32 44 13 54 21 34 6 20 26 23Z" fill="none" stroke="COLOR" stroke-width="3"/><g fill="COLOR"><circle cx="32" cy="9" r="5"/><circle cx="54" cy="23" r="5"/><circle cx="46" cy="50" r="5"/><circle cx="18" cy="50" r="5"/><circle cx="10" cy="23" r="5"/></g>',
		"ghost":'<path d="M12 34C12 0 52 0 52 34v22l-10-7-10 7-10-7-10 7Z" fill="COLOR"/><ellipse cx="24" cy="27" rx="4" ry="6" fill="#3d3347"/><ellipse cx="40" cy="27" rx="4" ry="6" fill="#3d3347"/>',
		"phoenix":'<path d="M32 57 8 33 3 9l21 18 8-16 8 16L61 9 56 33Z" fill="COLOR"/><path d="M32 23v27m0-10-14-16m14 16 14-16" fill="none" stroke="#775333" stroke-width="2"/>',
		"thorns":'<path d="M12 32c0-28 40-28 40 0S12 60 12 32Z" fill="none" stroke="COLOR" stroke-width="4"/><path d="m20 10 5 13-15-1m38-7-13 6 14 8M43 54l-7-13 17 1M12 48l13-6-13-8" fill="COLOR"/>',
		"sun":'<circle cx="32" cy="32" r="13" fill="COLOR"/><path d="M32 3v10m0 38v10M3 32h10m38 0h10M11 11l7 7m28 28 7 7M11 53l7-7m28-28 7-7" fill="none" stroke="COLOR" stroke-width="4"/>',
		"shatter":'<path d="M12 9h35l-9 17 14 13-17 17H12l8-18-8-12 13-4Z" fill="none" stroke="COLOR" stroke-width="3"/><path d="m28 9 5 14-9 12 8 10-5 11M50 7l7 8-8 6M51 44l9 5-6 10" fill="none" stroke="COLOR" stroke-width="3"/>',
		"scales":'<path d="M32 7v48M11 17h42M22 57h20M15 17 6 38h18ZM49 17 40 38h18Z" fill="none" stroke="COLOR" stroke-width="3"/>',
		"sword":'<path d="M17 51 48 13 53 7 56 15 26 53Z" fill="COLOR"/><path d="m17 44 15 13M15 57l9-11" stroke="COLOR" stroke-width="5"/><path d="m29 39 21-25" stroke="#f0d9ae" stroke-width="2"/>',
		"shield":'<path d="m32 7 22 8-3 24c-2 10-13 17-19 21-6-4-17-11-19-21l-3-24Z" fill="COLOR"/><path d="m32 13 16 6-3 19c-2 7-8 13-13 16-5-3-11-9-13-16l-3-19Z" fill="none" stroke="#ebd2a4" stroke-width="2"/><path d="M32 17v30" stroke="#ebd2a4" stroke-width="2"/>',
		"heart":'<path d="M32 55C-7 29 9 4 27 18l5 5 5-5C55 4 71 29 32 55Z" fill="COLOR"/><path d="M22 34h20M32 24v20" stroke="#f3dfb6" stroke-width="5"/>',
		"eye":'<path d="M4 32c16-24 40-24 56 0C44 56 20 56 4 32Z" fill="none" stroke="COLOR" stroke-width="4"/><circle cx="32" cy="32" r="11" fill="COLOR"/><circle cx="35" cy="29" r="3" fill="#f3dfb6"/>',
		"crown":'<path d="m8 20 12 12L32 9l12 23 12-12-6 29H14Z" fill="COLOR"/><path d="M14 55h36" stroke="COLOR" stroke-width="5"/><circle cx="32" cy="8" r="4" fill="COLOR"/>',
		"swirl":'<path d="M48 14C27-3 6 14 9 35c3 22 38 32 47 7 6-17-18-32-28-15-6 11 9 20 16 9" fill="none" stroke="COLOR" stroke-width="6" stroke-linecap="round"/><path d="m48 5 2 15-15-1" fill="none" stroke="COLOR" stroke-width="4"/>',
		"chain":'<g fill="none" stroke="COLOR" stroke-width="6"><rect x="10" y="8" width="21" height="34" rx="10" transform="rotate(35 20 25)"/><rect x="33" y="22" width="21" height="34" rx="10" transform="rotate(35 44 39)"/></g><path d="M9 56 55 8" stroke="#ae673f" stroke-width="3"/>',
		"cards":'<path d="m11 11 27-4 7 43-27 4Z" fill="none" stroke="COLOR" stroke-width="3"/><path d="M25 16h28v42H25Z" fill="COLOR"/><path d="m39 26 3 8 8 3-8 3-3 8-3-8-8-3 8-3Z" fill="#f3dfb6"/>',
		"mirror":'<ellipse cx="32" cy="25" rx="17" ry="21" fill="none" stroke="COLOR" stroke-width="4"/><path d="M32 46v13M23 59h18M22 29l17-19M25 38l18-23" stroke="COLOR" stroke-width="3"/>',
		"skull":'<path d="M12 29C9 1 55 1 52 29l-5 11-4 2v14H21V42l-5-2Z" fill="COLOR"/><ellipse cx="23" cy="28" rx="7" ry="8" fill="#342d39"/><ellipse cx="41" cy="28" rx="7" ry="8" fill="#342d39"/><path d="m32 36-4 7h8ZM27 47v10M36 47v10" fill="#342d39" stroke="#342d39" stroke-width="2"/>',
		"rune":'<path d="m32 4 5 18 17-8-11 16 17 8-20 1-2 20-8-17-16 11 8-17-18-5 20-6Z" fill="COLOR"/><circle cx="32" cy="32" r="10" fill="none" stroke="#d4b881" stroke-width="1.5"/>',
		"flame":'<path d="M36 4c5 16-11 20-5 30 9-3 14-9 13-18 24 28 11 44-12 44C4 60 2 36 20 22c-3 10-1 15 5 16C15 22 37 20 36 4Z" fill="COLOR"/><path d="M33 38c14 11 9 19-2 18-9-3-7-11 2-18Z" fill="#f3dfb6"/>'
	}
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 64 64">' + shapes[name].replace("COLOR","#" + ink) + '</svg>'
	var img := Image.new()
	img.load_svg_from_string(svg)
	var texture := ImageTexture.create_from_image(img)
	cache[cache_key] = texture
	return texture
