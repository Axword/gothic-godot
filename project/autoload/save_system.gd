extends Node
signal saved(ok: bool, message: String)

func save_slot(slot: int = 1) -> bool:
	var state := {
		"version": GameState.SAVE_VERSION, "player_position": {"x": GameState.player_position.x, "y": GameState.player_position.y},
		"hp": GameState.hp, "mana": GameState.mana, "level": GameState.level, "xp": GameState.xp,
		"learning_points": GameState.learning_points, "world_minutes": GameState.world_minutes,
		"inventory": GameState.inventory, "equipped": GameState.equipped, "learned_spells": GameState.learned_spells, "quest": {"id": GameState.active_quest, "stage": GameState.quest_stage},
		"flags": GameState.flags, "opened_chests": GameState.opened_chests, "defeated": GameState.defeated
	}
	var file := FileAccess.open("user://save_%d.json" % slot, FileAccess.WRITE)
	if file == null:
		saved.emit(false, "Nie można zapisać gry.")
		return false
	file.store_string(JSON.stringify(state, "  "))
	saved.emit(true, "Zapisano w slocie %d." % slot)
	return true

func load_slot(slot: int = 1) -> bool:
	var file := FileAccess.open("user://save_%d.json" % slot, FileAccess.READ)
	if file == null:
		saved.emit(false, "Brak zapisu w slocie %d." % slot)
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		saved.emit(false, "Zapis jest uszkodzony.")
		return false
	var data: Dictionary = json.data
	if int(data.get("version", 0)) > GameState.SAVE_VERSION:
		saved.emit(false, "Zapis pochodzi z nowszej wersji.")
		return false
	var pos: Dictionary = data.get("player_position", {})
	GameState.player_position = Vector2(float(pos.get("x", 13000)), float(pos.get("y", 7000)))
	GameState.hp = int(data.get("hp", 60)); GameState.mana = int(data.get("mana", 20))
	GameState.level = int(data.get("level", 1)); GameState.xp = int(data.get("xp", 0))
	GameState.learning_points = int(data.get("learning_points", 1)); GameState.world_minutes = float(data.get("world_minutes", 420))
	GameState.inventory = data.get("inventory", {}).duplicate(); GameState.equipped = data.get("equipped", {"weapon": "miecz_iskrowy", "armor": "plaszcz_miernika"}).duplicate(); GameState.learned_spells.assign(data.get("learned_spells", ["iskra"])); var quest: Dictionary = data.get("quest", {})
	GameState.active_quest = str(quest.get("id", "quest_iskra")); GameState.quest_stage = str(quest.get("stage", "start"))
	GameState.flags = data.get("flags", {}).duplicate(); GameState.opened_chests.assign(data.get("opened_chests", [])); GameState.defeated.assign(data.get("defeated", []))
	GameState.changed.emit(); saved.emit(true, "Wczytano slot %d." % slot)
	return true
