extends Node
## Harvest is deliberately gated by a taught rank; no automatic bestiary loot.
signal harvested(monster_id: String, item_id: String)

var harvested_corpses: Dictionary = {}

func harvest(monster_id: String, skill_rank: int) -> String:
	if harvested_corpses.has(monster_id): return ""
	if skill_rank < 1: return ""
	var trophy := ""
	match monster_id:
		"wilk_z_mielizny": trophy = "skora_wilka"
		"ropucha_mulowa": trophy = "gruczol_ropuchy"
		"upior_bezdechu": trophy = "oko_upiora"
		"golem_tamy": trophy = "odlamek_golema"
		"krab_wydmowy": trophy = "skorupa_kraba"
	if trophy.is_empty(): return ""
	harvested_corpses[monster_id] = true
	GameState.add_item(trophy)
	harvested.emit(monster_id, trophy)
	return trophy
