extends Node
## Runtime-only state. Canonical content remains in data/json.
signal changed
signal quest_changed(quest_id: String, stage: String)

const SAVE_VERSION: int = 1
var player_position: Vector2 = Vector2(13000, 7000)
var hp: int = 60
var max_hp: int = 60
var mana: int = 20
var max_mana: int = 20
var level: int = 1
var xp: int = 0
var learning_points: int = 1
var strength: int = 5
var dexterity: int = 5
var world_minutes: float = 7.0 * 60.0
var inventory: Dictionary = {"miecz_iskrowy": 1, "wytrych": 2}
var active_quest: String = "quest_iskra"
var quest_stage: String = "start"
var flags: Dictionary = {}
var opened_chests: Array[String] = []
var defeated: Array[String] = []

func reset() -> void:
	player_position = Vector2(13000, 7000)
	hp = 60
	mana = 20
	level = 1
	xp = 0
	learning_points = 1
	world_minutes = 7.0 * 60.0
	inventory = {"miecz_iskrowy": 1, "wytrych": 2}
	active_quest = "quest_iskra"
	quest_stage = "start"
	flags = {}
	opened_chests = []
	defeated = []
	changed.emit()

func advance_quest(stage: String) -> void:
	quest_stage = stage
	quest_changed.emit(active_quest, stage)
	changed.emit()

func add_item(item_id: String, amount: int = 1) -> void:
	inventory[item_id] = int(inventory.get(item_id, 0)) + amount
	changed.emit()

func remove_item(item_id: String, amount: int = 1) -> bool:
	var current: int = int(inventory.get(item_id, 0))
	if current < amount:
		return false
	if current == amount:
		inventory.erase(item_id)
	else:
		inventory[item_id] = current - amount
	changed.emit()
	return true

func gain_xp(amount: int) -> void:
	xp += amount
	while xp >= level * 100:
		xp -= level * 100
		level += 1
		max_hp = 45 + level * 15
		hp = max_hp
		learning_points += 1
	changed.emit()

func time_text() -> String:
	var total: int = int(world_minutes) % (24 * 60)
	return "%02d:%02d" % [total / 60, total % 60]
