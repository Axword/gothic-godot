extends Node
signal trained(skill: String, new_rank: int)
var ranks: Dictionary = {}
var trainers: Dictionary = {}

func _ready() -> void:
	for entry: Dictionary in DataLoader.load_array("res://data/json/trainers.json"): trainers[str(entry["id"])] = entry

func train(trainer_id: String) -> bool:
	var entry: Dictionary = trainers.get(trainer_id, {})
	if entry.is_empty(): return false
	var skill := str(entry.get("skill", "")); var rank := int(ranks.get(skill, 0))
	if rank >= int(entry.get("rank_limit", 0)) or GameState.learning_points < int(entry.get("learning_cost", 1)): return false
	if not GameState.remove_item("zlote_znaki", int(entry.get("currency_cost", 0))): return false
	GameState.learning_points -= int(entry.get("learning_cost", 1)); ranks[skill] = rank + 1; trained.emit(skill, rank + 1); return true
