extends Node
## Data-driven quest state machine. Definitions are immutable JSON; state belongs to GameState/save.
signal quest_started(quest_id: String)
signal quest_stage_changed(quest_id: String, stage_id: String)
signal quest_finished(quest_id: String, failed: bool)

var definitions: Dictionary = {}
var state: Dictionary = {}

func _ready() -> void:
	for path: String in ["res://data/json/quests_main.json", "res://data/json/quests_old_faction.json", "res://data/json/quests_new_faction.json", "res://data/json/quests_side.json"]:
		for quest: Dictionary in DataLoader.load_array(path): definitions[str(quest["id"])] = quest

func start(quest_id: String) -> bool:
	if not definitions.has(quest_id) or state.has(quest_id): return false
	state[quest_id] = {"stage": "start", "status": "active"}; quest_started.emit(quest_id); return true

func advance(quest_id: String, stage_id: String) -> bool:
	if not state.has(quest_id) or str(state[quest_id].get("status")) != "active": return false
	var definition: Dictionary = definitions.get(quest_id, {})
	var found := false
	for stage: Dictionary in definition.get("stages", []):
		if str(stage.get("id")) == stage_id: found = true
	if not found: return false
	state[quest_id]["stage"] = stage_id
	quest_stage_changed.emit(quest_id, stage_id)
	if stage_id == "complete":
		state[quest_id]["status"] = "completed"; _grant_reward(definition); quest_finished.emit(quest_id, false)
	return true

func fail(quest_id: String) -> bool:
	if not state.has(quest_id): return false
	state[quest_id]["status"] = "failed"; quest_finished.emit(quest_id, true); return true

func _grant_reward(definition: Dictionary) -> void:
	var reward: Dictionary = definition.get("rewards", {})
	GameState.gain_xp(int(reward.get("xp", 0)))
	for item_id: String in reward.get("items", []): GameState.add_item(item_id)
