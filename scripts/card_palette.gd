extends RefCounted
## One ink and glow pair per card; both the printed emblem and detached emblem
## share this ink. Rarity borders and unknown backs are deliberately separate.
const COLORS={
"spare_food":["a37842","e9c285"],"spare_supplies":["578071","a7d6c5"],
"poisoning":["69843d","bfda86"],"poison":["687843","bbd29a"],
"bloodletting":["a84845","e9a098"],"gold_panning":["a17d32","edd58a"],"search":["477b93","a5d1e3"],
"sapphire":["3277b0","82c6f2"],"ruby":["af4058","f392a3"],"amethyst":["8858a7","cba0ee"],
"topaz":["ad8326","f4d56c"],"emerald":["358057","8edda6"],"amber":["bd702d","f5b36a"],
"rally":["b08531","f4d785"],"defile":["6f527e","b494c8"],"obstruct":["787066","c6bbab"],"boulder":["787066","c6bbab"],"final_strike":["983e42","eb858d"],
"anticipation":["4b718f","96c8eb"],"gift":["a77a3e","edc583"],"cards_to_heart":["398765","8ee1b2"],
"cards_to_blades":["995461","ed9bad"],"late_suppress":["765780","c6a0d8"],"frenzy":["ac443f","f49680"],
"precise_strike":["347f77","84d5c8"],"warcry":["bb7538","f2ad64"],
"strike":["a65a3c","f2c78a"],"double_strike":["ba7037","f5b465"],"triple_strike":["b54e35","f17e51"],
"godslayer":["8962a1","c88ff0"],"bounty":["a16d37","e0b366"],"area_strike":["b06b31","e8a153"],"glory":["b18a36","f7cf78"],
"holy_strike":["b48a32","ffe39b"],"quick_strike":["438899","88e6ef"],"hasty_spell":["b35b91","f6a0d5"],"magic_strike":["8256b0","b593ff"],
"defense":["3c6186","81c9fa"],"heal":["3c9c66","65df8b"],"heal_other":["268971","81e4be"],"team_heal":["618a3b","b4e785"],
"collect":["4389a8","8ecceb"],"gambler":["a76d32","efba76"],"prophecy":["438998","91d8f2"],"judgment":["aa584b","e77f7e"],
"mirror":["497f99","b6deeb"],"suppress":["aa584c","e48a76"],"ignore":["7966a3","bcb1ec"],"reverse":["328d94","85d8dc"],
"holy_amulet":["aa8d42","f5d687"],"attack_amulet":["b83e31","ff604d"],"magic_amulet":["8761a5","c7a6f2"],
"peek":["2f829a","92d7e9"],"silence":["687990","a8b4d4"],"plunder":["aa7241","e2b57a"],"badge":["af862d","f3cc77"],
"overload":["4582af","9edfff"],"raise_dead":["348365","96e6bb"],"elegy":["83649f","beabec"],"feign":["82629f","b9a5eb"],"skip_death":["7860a0","bca8ee"],
"immortal":["ffe095","ffe095"],"mediocrity":["b9b0d5","b9b0d5"],"blood_rite":["f69c99","f69c99"],"death_sentence":["c099e5","c099e5"],
"last_dance":["f199c4","f199c4"],"ghost":["a6d8ed","a6d8ed"],"legacy":["e6c486","e6c486"],"greed":["eed080","eed080"],
"prison":["adb4d7","adb4d7"],"pain":["e5a0bd","e5a0bd"],"resurrection":["a3ead8","a3ead8"],"vanish":["b9a7d7","b9a7d7"],
"blessing":["f0d7a3","f0d7a3"],"heart":["f4a5ac","f4a5ac"],"sacrifice_badges":["f3cd81","f3cd81"],"life_steal":["e89bb2","e89bb2"],
"curse":["bc95e0","ae92da"],"eye":["a5daef","a5daef"],"divinity":["f8df9d","f8df9d"],"privilege":["f3d585","f3d585"],"death":["baa7d8","baa7d8"]}
static func ink(key:String)->String:return COLORS.get(key,["3c6186","a5cde0"])[0]
static func glow(key:String)->Color:return Color(COLORS.get(key,["3c6186","a5cde0"])[1])
