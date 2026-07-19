extends SceneTree
## Run: godot --headless --path project --script res://tests/validate_data.gd
func _init() -> void:
	var paths := ["res://data/json/npcs.json", "res://data/json/npc_schedules.json", "res://data/json/items_weapons_swords.json", "res://data/json/items_misc.json", "res://data/json/monsters.json", "res://data/json/quests_main.json", "res://data/json/spells.json"]
	var failed := false
	for path: String in paths:
		var file := FileAccess.open(path, FileAccess.READ)
		var json := JSON.new()
		if file == null or json.parse(file.get_as_text()) != OK or not json.data is Array:
			push_error("Niepoprawny JSON: " + path); failed = true; continue
		var ids := {}
		for row: Dictionary in json.data:
			var id := str(row.get("id", ""))
			if id.is_empty() or ids.has(id): push_error("Niepoprawne ID: " + path + ": " + id); failed = true
			ids[id] = true
	print("DATA VALIDATION " + ("FAILED" if failed else "PASSED"))
	quit(1 if failed else 0)
