extends SceneTree
## Run: godot --headless --path project --script res://tests/validate_data.gd
func _init() -> void:
	var array_paths: Array[String] = ["npcs.json", "npc_schedules.json", "items_weapons_swords.json", "items_weapons_bows.json", "items_armors.json", "items_plants.json", "items_potions.json", "items_trophies.json", "items_misc.json", "monsters.json", "monster_spawns.json", "quests_main.json", "quests_old_faction.json", "quests_new_faction.json", "quests_side.json", "trainers.json", "world_locations.json", "world_chests.json", "shops.json", "loot_tables.json", "spells.json"]
	var data: Dictionary = {}; var failed := false
	for file_name: String in array_paths:
		var path := "res://data/json/" + file_name
		var file := FileAccess.open(path, FileAccess.READ); var json := JSON.new()
		if file == null or json.parse(file.get_as_text()) != OK or not json.data is Array:
			push_error("Niepoprawny JSON array: " + path); failed = true; continue
		data[file_name] = json.data
		var ids := {}
		for row: Dictionary in json.data:
			var id := str(row.get("id", ""))
			if id.is_empty() or ids.has(id): push_error("Niepoprawne ID: %s: %s" % [path, id]); failed = true
			ids[id] = true
	var npc_ids := _ids(data.get("npcs.json", [])); var monster_ids := _ids(data.get("monsters.json", []))
	for row: Dictionary in data.get("npc_schedules.json", []):
		if not npc_ids.has(str(row.get("npc_id", ""))): push_error("Rutyna wskazuje nieistniejącego NPC: " + str(row)); failed = true
	for row: Dictionary in data.get("trainers.json", []):
		if not npc_ids.has(str(row.get("npc_id", ""))): push_error("Trener wskazuje nieistniejącego NPC: " + str(row)); failed = true
	for row: Dictionary in data.get("monster_spawns.json", []):
		if not monster_ids.has(str(row.get("monster_id", ""))): push_error("Spawn wskazuje nieistniejącego potwora: " + str(row)); failed = true
	var item_ids := {}
	for file_name: String in ["items_weapons_swords.json", "items_weapons_bows.json", "items_armors.json", "items_plants.json", "items_potions.json", "items_trophies.json", "items_misc.json"]:
		for item: Dictionary in data.get(file_name, []): item_ids[str(item.get("id", ""))] = true
	for chest: Dictionary in data.get("world_chests.json", []):
		if not item_ids.has(str(chest.get("reward", ""))): push_error("Skrzynia ma brakującą nagrodę: " + str(chest)); failed = true
	for shop: Dictionary in data.get("shops.json", []):
		if not npc_ids.has(str(shop.get("npc_id", ""))): push_error("Sklep ma brakującego NPC: " + str(shop)); failed = true
		for entry: Dictionary in shop.get("stock", []):
			if not item_ids.has(str(entry.get("item_id", ""))): push_error("Sklep ma brakujący przedmiot: " + str(entry)); failed = true
	print("DATA VALIDATION " + ("FAILED" if failed else "PASSED")); quit(1 if failed else 0)

func _ids(rows: Array) -> Dictionary:
	var result := {}
	for row: Dictionary in rows: result[str(row.get("id", ""))] = true
	return result
